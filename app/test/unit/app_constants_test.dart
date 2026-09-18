import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/core/constants/app_constants.dart';

void main() {
  group('AppConstants', () {
    test('contains expected core identity constants', () {
      expect(AppConstants.appName, 'NO SUS');
      expect(AppConstants.appTagline, 'See who opened it');
    });

    test('avatarColorToAsset and role map correctly', () {
      expect(AppConstants.avatarColorToAsset['FF0072FF'], 'assets/images/avatar_builder.png');
      expect(AppConstants.avatarColorToAsset['FFADF474'], 'assets/images/avatar_archivist.png');
      expect(AppConstants.avatarAsset('UNKNOWN'), 'assets/images/avatar_builder.png');
      expect(AppConstants.avatarRole('UNKNOWN'), 'SYSTEMS ARCHITECT');
      expect(AppConstants.avatarRole('FF0072FF'), 'SYSTEMS ARCHITECT');
      expect(AppConstants.avatarRole('FFADF474'), 'INFORMATION TRUSTEE');
      expect(AppConstants.avatarIcon('FF0072FF'), isNotNull);
    });
  });
}
