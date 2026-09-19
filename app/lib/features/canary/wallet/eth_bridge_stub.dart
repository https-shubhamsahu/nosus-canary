import 'eth_bridge.dart';

EthBridge createEthBridge() => _StubEthBridge();

class _StubEthBridge implements EthBridge {
  @override
  bool get available => false;

  @override
  Future<Object?> request(String method, [List<Object?> params = const []]) =>
      Future.error(
        const WalletError(-1, 'Wallet connect works in the web app.'),
      );

  @override
  void on(String event, void Function(Object? data) callback) {}
}
