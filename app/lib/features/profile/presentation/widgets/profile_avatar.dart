import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../providers/profile_provider.dart';

/// Single source of truth for rendering a user's avatar: an uploaded photo
/// when one exists, otherwise their chosen preset pixel-art character. Every
/// screen that shows the current user's avatar should use this so a new
/// upload appears everywhere at once.
class ProfileAvatar extends StatelessWidget {
  final ProfileData profile;
  final double size;

  const ProfileAvatar({super.key, required this.profile, required this.size});

  @override
  Widget build(BuildContext context) {
    final url = profile.avatarUrl;

    Widget preset() => Padding(
          padding: EdgeInsets.all(size * 0.1),
          child: Image.asset(
            AppConstants.avatarAssetForId(profile.avatarId),
            fit: BoxFit.contain,
          ),
        );

    if (url == null) return preset();

    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      // Decode at display size — a 256px avatar shown at 42px shouldn't
      // hold a full-size texture in memory.
      cacheWidth: (size * MediaQuery.of(context).devicePixelRatio).round(),
      // Photo unavailable (offline, deleted object): fall back to the
      // preset character rather than a broken-image glyph.
      errorBuilder: (_, _, _) => preset(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : preset(),
    );
  }
}
