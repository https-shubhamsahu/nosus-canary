import 'monad_receipt.dart';

abstract interface class MonadRepository {
  bool get isConfigured;
  Future<MonadReceipt> receiptOf(String id);
}
