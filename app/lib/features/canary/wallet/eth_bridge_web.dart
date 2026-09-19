import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'eth_bridge.dart';

EthBridge createEthBridge() => _WebEthBridge();

class _WebEthBridge implements EthBridge {
  JSObject? get _eth {
    final value = globalContext['ethereum'];
    if (value == null) return null;
    return value as JSObject;
  }

  @override
  bool get available => _eth != null;

  @override
  Future<Object?> request(
    String method, [
    List<Object?> params = const [],
  ]) async {
    final eth = _eth;
    if (eth == null) {
      throw const WalletError(-1, 'No wallet found in this browser.');
    }
    final args = JSObject();
    args['method'] = method.toJS;
    args['params'] = params.jsify();
    try {
      final result = await eth
          .callMethod<JSPromise<JSAny?>>('request'.toJS, args)
          .toDart;
      return result.dartify();
    } catch (e) {
      throw _walletError(e);
    }
  }

  @override
  void on(String event, void Function(Object? data) callback) {
    final eth = _eth;
    if (eth == null) return;
    void handler(JSAny? data) {
      callback(data.dartify());
    }

    eth.callMethod<JSAny?>('on'.toJS, event.toJS, handler.toJS);
  }

  WalletError _walletError(Object error) {
    try {
      final raw = (error as JSAny).dartify();
      if (raw is Map) {
        var code = raw['code'] is num ? (raw['code'] as num).toInt() : -1;
        // Some wallets wrap "unknown chain" (4902) inside data.originalError.
        final data = raw['data'];
        if (data is Map && data['originalError'] is Map) {
          final inner = (data['originalError'] as Map)['code'];
          if (inner is num) code = inner.toInt();
        }
        final message = raw['message']?.toString() ?? 'Wallet error';
        return WalletError(code, message);
      }
    } catch (_) {
      // Fall through to the generic error below.
    }
    return WalletError(-1, error.toString());
  }
}
