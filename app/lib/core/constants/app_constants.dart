/// Central constants registry for NO SUS.
///
/// Use this file instead of scattering magic strings across the codebase.
/// Prevents duplicate literal values and makes global changes a single edit.
library;

import 'package:flutter/material.dart';

class AppConstants {
  const AppConstants._();

  // ─── App Identity ──────────────────────────────────────────────────────────
  static const String appName = 'NO SUS';
  static const String appTagline = 'See who opened it';
  static const String appVersion = '1.4.0';

  // ─── Avatar Colors → Asset Paths ──────────────────────────────────────────
  static const String defaultAvatarColorStart = 'FF0072FF';
  static const String defaultAvatarColorEnd = 'FF00F2FE';

  static const Map<String, String> avatarColorToAsset = {
    'FF0072FF': 'assets/images/avatar_builder.png',
    'FFCCCCCC': 'assets/images/avatar_researcher.png',
    'FFFF0072': 'assets/images/avatar_creator.png',
    'FFF5A623': 'assets/images/avatar_academic.png',
    'FF800080': 'assets/images/avatar_chaos.png',
    'FFADF474': 'assets/images/avatar_archivist.png',
  };

  /// Returns the avatar asset path for a given [colorStart] hex string.
  static String avatarAsset(String colorStart) =>
      avatarColorToAsset[colorStart] ?? avatarColorToAsset[defaultAvatarColorStart]!;

  // ─── Avatar Roles ─────────────────────────────────────────────────────────
  static const Map<String, String> avatarColorToRole = {
    'FF0072FF': 'SYSTEMS ARCHITECT',
    'FFCCCCCC': 'RESEARCH SCHOLAR',
    'FFFF0072': 'SECURITY SPECIALIST',
    'FFF5A623': 'COMPLIANCE AUDITOR',
    'FF800080': 'THREAT INTELLIGENCE',
    'FFADF474': 'INFORMATION TRUSTEE',
  };

  static const String defaultRole = 'SYSTEMS ARCHITECT';

  /// Returns the persona role label for a given [colorStart] hex string.
  static String avatarRole(String colorStart) =>
      avatarColorToRole[colorStart] ?? defaultRole;

  /// Returns the professional icon for a given [colorStart] hex string.
  static IconData avatarIcon(String colorStart) {
    switch (colorStart) {
      case 'FF0072FF':
        return Icons.dns_outlined;
      case 'FFCCCCCC':
        return Icons.science_outlined;
      case 'FFFF0072':
        return Icons.security_outlined;
      case 'FFF5A623':
        return Icons.gavel_outlined;
      case 'FF800080':
        return Icons.psychology_outlined;
      case 'FFADF474':
        return Icons.folder_shared_outlined;
      default:
        return Icons.person_outline;
    }
  }

  /// Returns the pixel avatar asset path for a given [avatarId].
  static String avatarAssetForId(String avatarId) {
    switch (avatarId) {
      case 'avatar_01':
        return 'assets/images/avatar_builder.png';
      case 'avatar_02':
        return 'assets/images/avatar_researcher.png';
      case 'avatar_03':
        return 'assets/images/avatar_creator.png';
      case 'avatar_04':
        return 'assets/images/avatar_academic.png';
      case 'avatar_05':
        return 'assets/images/avatar_chaos.png';
      case 'avatar_06':
        return 'assets/images/avatar_archivist.png';
      default:
        return 'assets/images/avatar_builder.png';
    }
  }

  // ─── Default Note Content ─────────────────────────────────────────────────
  static const String defaultNoteContent =
      "Welcome to NO SUS.\n\n"
      "Send a sensitive document and still see who opened it.\n\n"
      "1. Share a file or a one-time Burn drop from Home.\n"
      "2. Send the link. Tell them the 2-digit code.\n"
      "3. Watch activity when they open it.\n";

  // ─── SharedPreferences Keys ───────────────────────────────────────────────
  static const String kOnboardingKey = 'nosus_onboarding_done';
  static const String kGuestModeKey = 'nosus_guest_mode';
  static const String kUserTypeKey = 'nosus_user_type';

  // ─── Storage Buckets ──────────────────────────────────────────────────────
  static const String storageSecureFiles = 'secure-files';

  // ─── Audit Statuses ───────────────────────────────────────────────────────
  static const String auditSuccess = 'SUCCESS';
  static const String auditSecurity = 'SECURITY';
  static const String auditInfo = 'INFO';
}
