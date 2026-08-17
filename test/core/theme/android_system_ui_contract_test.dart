import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/core/theme/app_colors.dart';

void main() {
  test(
    'Android launch and window backgrounds match the Flutter background',
    () {
      final androidBackground = _androidHex(AppColors.background);
      final colors = File(
        'android/app/src/main/res/values/colors.xml',
      ).readAsStringSync();

      expect(
        colors,
        contains('<color name="app_background">$androidBackground</color>'),
      );

      for (final path in [
        'android/app/src/main/res/drawable/launch_background.xml',
        'android/app/src/main/res/drawable-v21/launch_background.xml',
      ]) {
        expect(
          File(path).readAsStringSync(),
          contains('android:drawable="@color/app_background"'),
          reason: path,
        );
      }

      final baseStyles = File(
        'android/app/src/main/res/values/styles.xml',
      ).readAsStringSync();
      expect(baseStyles, contains('android:windowBackground'));
      expect(baseStyles, contains('@color/app_background'));
      expect(baseStyles, contains('android:statusBarColor'));
      expect(baseStyles, contains('android:navigationBarColor'));
      expect(baseStyles, contains('android:windowLightStatusBar'));

      expect(
        File(
          'android/app/src/main/res/values-v26/styles.xml',
        ).readAsStringSync(),
        contains('android:windowLightNavigationBar'),
      );
      expect(
        File(
          'android/app/src/main/res/values-v28/styles.xml',
        ).readAsStringSync(),
        contains('android:navigationBarDividerColor'),
      );

      final api29Styles = File(
        'android/app/src/main/res/values-v29/styles.xml',
      ).readAsStringSync();
      expect(api29Styles, contains('android:enforceStatusBarContrast'));
      expect(api29Styles, contains('android:enforceNavigationBarContrast'));

      expect(
        File(
          'android/app/src/main/res/values-v31/styles.xml',
        ).readAsStringSync(),
        contains('android:windowSplashScreenBackground'),
      );
    },
  );

  test('light-only Android theme has no dark-mode override', () {
    expect(
      File('android/app/src/main/res/values-night/styles.xml').existsSync(),
      isFalse,
    );
  });
}

String _androidHex(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
