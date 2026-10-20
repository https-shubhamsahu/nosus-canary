enum SolanaCluster {
  devnet('devnet', 'https://api.devnet.solana.com'),
  mainnetBeta('mainnet-beta', 'https://api.mainnet-beta.solana.com');

  const SolanaCluster(this.id, this.rpcUrl);

  /// The name Solana tools use: 'devnet' or 'mainnet-beta'.
  final String id;

  /// Default public RPC endpoint.
  final String rpcUrl;

  /// Null for an unknown id.
  static SolanaCluster? byId(String id) =>
      values.where((c) => c.id == id).firstOrNull;
}

/// Solana Explorer page for a transaction. Mainnet takes no cluster param.
String explorerTxUrl(
  String signature, {
  SolanaCluster cluster = SolanaCluster.devnet,
}) {
  final base = 'https://explorer.solana.com/tx/$signature';
  return cluster == SolanaCluster.mainnetBeta
      ? base
      : '$base?cluster=${cluster.id}';
}
