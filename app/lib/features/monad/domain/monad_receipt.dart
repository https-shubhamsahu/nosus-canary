/// Public acknowledgement metadata. Never contains note content or keys.
class MonadReceipt {
  const MonadReceipt({
    required this.id,
    required this.sender,
    required this.recipient,
    required this.opener,
    required this.ciphertextDigest,
    required this.sealedAt,
    required this.openedAt,
    required this.expiresAt,
  });

  static const zeroAddress = '0x0000000000000000000000000000000000000000';
  final String id, sender, recipient, opener, ciphertextDigest;
  final int sealedAt, openedAt, expiresAt;
  bool get acknowledged => opener != zeroAddress;
  bool isExpired(DateTime now) =>
      expiresAt != 0 && now.millisecondsSinceEpoch ~/ 1000 >= expiresAt;
  String status(DateTime now) => acknowledged
      ? (isExpired(now) ? 'Acknowledged · access expired' : 'Acknowledged')
      : (isExpired(now)
            ? 'Expired without acknowledgement'
            : 'Awaiting acknowledgement');

  factory MonadReceipt.fromAbi(String id, String data) {
    if (!RegExp(r'^0x[0-9a-fA-F]{448}$').hasMatch(data)) {
      throw const FormatException('The contract returned an invalid receipt.');
    }
    final words = List.generate(
      7,
      (i) => data.substring(2 + i * 64, 2 + (i + 1) * 64),
    );
    for (final word in words.take(3)) {
      if (!word.startsWith('0' * 24)) {
        throw const FormatException('Invalid wallet address in receipt.');
      }
    }
    int timestamp(int index) {
      final value = BigInt.parse(words[index], radix: 16);
      if (value > BigInt.from(8640000000000)) {
        throw const FormatException('Invalid receipt timestamp.');
      }
      return value.toInt();
    }

    final sender = '0x${words[0].substring(24)}'.toLowerCase();
    if (sender == zeroAddress) {
      throw const FormatException('Receipt does not exist.');
    }
    return MonadReceipt(
      id: id.toLowerCase(),
      sender: sender,
      recipient: '0x${words[1].substring(24)}'.toLowerCase(),
      opener: '0x${words[2].substring(24)}'.toLowerCase(),
      ciphertextDigest: '0x${words[3]}'.toLowerCase(),
      sealedAt: timestamp(4),
      openedAt: timestamp(5),
      expiresAt: timestamp(6),
    );
  }
}

/// Never forward arbitrary URLs or Burn fragments to the RPC.
String? parseMonadDropId(String input) {
  final text = input.trim();
  if (RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(text)) return text.toLowerCase();
  final uri = Uri.tryParse(text);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'monad.nosus.foo' ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.path != '/') {
    return null;
  }
  return RegExp(
    r'^/monad/(0x[0-9a-fA-F]{64})$',
  ).firstMatch(uri.fragment)?.group(1)?.toLowerCase();
}
