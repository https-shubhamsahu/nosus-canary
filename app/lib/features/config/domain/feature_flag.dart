/// Represents a dynamic feature flag fetched from the database.
class FeatureFlag {
  final String key;
  final String description;
  final bool isActive;
  final int rolloutPercentage;
  final List<String> targetedUserIds;
  final Map<String, dynamic> metadata;

  FeatureFlag({
    required this.key,
    required this.description,
    required this.isActive,
    required this.rolloutPercentage,
    required this.targetedUserIds,
    required this.metadata,
  });

  factory FeatureFlag.fromJson(Map<String, dynamic> json) {
    return FeatureFlag(
      key: json['flag_key'] as String,
      description: json['description'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      rolloutPercentage: json['rollout_percentage'] as int? ?? 100,
      targetedUserIds: List<String>.from(
        (json['targeted_user_ids'] as List?)?.map((e) => e.toString()) ?? [],
      ),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  /// Determines if the feature flag is enabled for a specific [userId].
  bool isEnabledFor(String userId) {
    if (!isActive) return false;
    
    // Explicit targeting overrides percentage rollout
    if (targetedUserIds.contains(userId)) return true;
    
    if (rolloutPercentage == 100) return true;
    if (rolloutPercentage == 0) return false;

    // Deterministic hash rollout to keep assignments consistent for a given user
    final hash = userId.codeUnits.fold<int>(0, (prev, element) => prev + element);
    return (hash % 100) < rolloutPercentage;
  }
}
