import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../config/app_mode.dart';
import '../domain/canary_link.dart';
import 'eth_bridge.dart';
import 'eth_bridge_stub.dart' if (dart.library.js_interop) 'eth_bridge_web.dart';

export 'eth_bridge.dart' show WalletError;

const int kMonadTestnetChainId = 10143;
const String kMonadTestnetChainHex = '0x279f';
const String kMonadRpcUrl = 'https://testnet-rpc.monad.xyz';
const String kMonadExplorer = 'https://testnet.monadscan.com';

/// The deployed NoSusCanary contract on Monad testnet.
String get canaryContractAddress => kCanaryContract;

String monadAddressUrl(String address) => '$kMonadExplorer/address/$address';

class WalletState {
  const WalletState({
    this.address,
    this.chainId,
    this.balanceWei,
    this.busy = false,
  });

  final String? address;
  final int? chainId;
  final BigInt? balanceWei;
  final bool busy;

  bool get connected => address != null;
  bool get onMonad => chainId == kMonadTestnetChainId;

  String get shortAddress {
    final a = address;
    if (a == null || a.length < 10) return a ?? '';
    return '${a.substring(0, 6)}…${a.substring(a.length - 4)}';
  }

  /// Balance in MON with 3 decimals, e.g. "12.345".
  String get balanceMon {
    final wei = balanceWei;
    if (wei == null) return '…';
    final milli = wei ~/ BigInt.from(10).pow(15);
    final whole = milli ~/ BigInt.from(1000);
    final frac = (milli % BigInt.from(1000)).toString().padLeft(3, '0');
    return '$whole.$frac';
  }

  WalletState copyWith({
    String? address,
    int? chainId,
    BigInt? balanceWei,
    bool? busy,
  }) => WalletState(
    address: address ?? this.address,
    chainId: chainId ?? this.chainId,
    balanceWei: balanceWei ?? this.balanceWei,
    busy: busy ?? this.busy,
  );
}

/// The browser wallet connected to Monad testnet. One instance for the app.
class MonadWallet extends ValueNotifier<WalletState> {
  MonadWallet._(this._bridge) : super(const WalletState()) {
    if (_bridge.available) {
      _listen();
      _restore();
    }
  }

  static final MonadWallet instance = MonadWallet._(createEthBridge());

  final EthBridge _bridge;

  bool get available => _bridge.available;

  /// Connects (asks the wallet for an account), then switches to or adds
  /// Monad testnet and reads the balance. Throws [WalletError] on failure.
  Future<void> connect() async {
    value = value.copyWith(busy: true);
    try {
      final accounts = await _bridge.request('eth_requestAccounts');
      final address = _firstAccount(accounts);
      if (address == null) {
        throw const WalletError(-1, 'The wallet returned no account.');
      }
      value = WalletState(address: address, busy: true);
      await switchToMonad();
      await refresh();
    } finally {
      value = value.copyWith(busy: false);
    }
  }

  /// Switches the wallet to Monad testnet, adding the network first if the
  /// wallet does not know it yet.
  Future<void> switchToMonad() async {
    try {
      await _bridge.request('wallet_switchEthereumChain', [
        {'chainId': kMonadTestnetChainHex},
      ]);
    } on WalletError catch (e) {
      if (e.code == 4001) rethrow;
      await _bridge.request('wallet_addEthereumChain', [
        {
          'chainId': kMonadTestnetChainHex,
          'chainName': 'Monad Testnet',
          'nativeCurrency': {'name': 'Monad', 'symbol': 'MON', 'decimals': 18},
          'rpcUrls': [kMonadRpcUrl],
          'blockExplorerUrls': [kMonadExplorer],
        },
      ]);
    }
    await refresh();
  }

  /// Re-reads the chain id and the MON balance.
  Future<void> refresh() async {
    final address = value.address;
    if (address == null) return;
    final chain = _hexToInt(await _bridge.request('eth_chainId'));
    BigInt? balance;
    try {
      final raw = await _bridge.request('eth_getBalance', [address, 'latest']);
      balance = _hexToBigInt(raw);
    } catch (_) {
      balance = null;
    }
    value = WalletState(
      address: address,
      chainId: chain,
      balanceWei: balance,
      busy: value.busy,
    );
  }

  /// Forgets the account in this app (and asks the wallet to revoke access
  /// where it supports that).
  Future<void> disconnect() async {
    try {
      await _bridge.request('wallet_revokePermissions', [
        {'eth_accounts': <String, Object?>{}},
      ]);
    } catch (_) {
      // Not every wallet supports revoking; forgetting locally is enough.
    }
    value = const WalletState();
  }

  /// `eth_call` through the connected wallet.
  Future<String> ethCall(String to, String data) async {
    final result = await _bridge.request('eth_call', [
      {'to': to, 'data': data},
      'latest',
    ]);
    return result?.toString() ?? '0x';
  }

  Future<void> _restore() async {
    try {
      final accounts = await _bridge.request('eth_accounts');
      final address = _firstAccount(accounts);
      if (address == null) return;
      value = WalletState(address: address);
      await refresh();
    } catch (_) {
      // Not connected before; stay disconnected.
    }
  }

  void _listen() {
    _bridge.on('accountsChanged', (data) {
      final address = _firstAccount(data);
      if (address == null) {
        value = const WalletState();
      } else {
        value = WalletState(address: address, chainId: value.chainId);
        refresh();
      }
    });
    _bridge.on('chainChanged', (data) {
      if (value.connected) {
        value = WalletState(
          address: value.address,
          chainId: _hexToInt(data),
        );
        refresh();
      }
    });
  }

  static String? _firstAccount(Object? accounts) {
    if (accounts is List && accounts.isNotEmpty) {
      return accounts.first?.toString();
    }
    return null;
  }

  static int? _hexToInt(Object? hex) {
    final s = hex?.toString();
    if (s == null || !s.startsWith('0x')) return null;
    return int.tryParse(s.substring(2), radix: 16);
  }

  static BigInt? _hexToBigInt(Object? hex) {
    final s = hex?.toString();
    if (s == null || !s.startsWith('0x')) return null;
    return BigInt.tryParse(s.substring(2), radix: 16);
  }
}

/// What NoSusCanary.noteOf returns for one note.
class CanaryChainNote {
  const CanaryChainNote({
    required this.sealedAt,
    required this.expiresAt,
    required this.copyCount,
    required this.openedCount,
    required this.copiesHash,
    required this.readVia,
  });

  final DateTime? sealedAt;
  final DateTime? expiresAt;
  final int copyCount;
  final int openedCount;
  final String copiesHash;

  /// "your wallet" or "the public Monad RPC".
  final String readVia;

  bool get exists => sealedAt != null;
}

/// Reads a note's seal straight from the NoSusCanary contract. Uses the
/// connected wallet when it is on Monad testnet, else the public RPC.
Future<CanaryChainNote> readCanaryNoteOnChain(String noteId) async {
  final contract = canaryContractAddress;
  if (contract.isEmpty) {
    throw StateError('No contract address is configured.');
  }
  final id = canaryChainNoteId(noteId).substring(2);
  // noteOf(bytes32) selector.
  final data = '0x3a989573$id';

  final wallet = MonadWallet.instance;
  String hex;
  String via;
  if (wallet.value.connected && wallet.value.onMonad) {
    hex = await wallet.ethCall(contract, data);
    via = 'your wallet';
  } else {
    final response = await http.post(
      Uri.parse(kMonadRpcUrl),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'eth_call',
        'params': [
          {'to': contract, 'data': data},
          'latest',
        ],
      }),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['error'] != null) {
      throw StateError('Monad RPC error: ${body['error']}');
    }
    hex = body['result'] as String;
    via = 'the public Monad RPC';
  }

  final words = hex.startsWith('0x') ? hex.substring(2) : hex;
  String word(int i) =>
      words.length >= (i + 1) * 64 ? words.substring(i * 64, (i + 1) * 64) : '0';
  int num(int i) => int.parse(word(i), radix: 16);
  DateTime? time(int i) {
    final s = num(i);
    return s == 0 ? null : DateTime.fromMillisecondsSinceEpoch(s * 1000);
  }

  return CanaryChainNote(
    sealedAt: time(0),
    expiresAt: time(1),
    copyCount: num(2),
    openedCount: num(3),
    copiesHash: '0x${word(4)}',
    readVia: via,
  );
}
