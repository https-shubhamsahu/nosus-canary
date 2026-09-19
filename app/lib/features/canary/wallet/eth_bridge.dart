/// Minimal EIP-1193 bridge to the browser wallet (MetaMask, Rabby, Phantom,
/// OKX...). The web build talks to `window.ethereum`; other platforms get a
/// stub that reports no wallet.
abstract class EthBridge {
  /// True when an injected wallet exists in this browser.
  bool get available;

  /// `ethereum.request({method, params})`, with the result converted to Dart.
  Future<Object?> request(String method, [List<Object?> params = const []]);

  /// `ethereum.on(event, cb)`.
  void on(String event, void Function(Object? data) callback);
}

/// A wallet error with its EIP-1193 code (4001 = the user rejected,
/// 4902 = the chain is not added to the wallet yet).
class WalletError implements Exception {
  const WalletError(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => message;
}
