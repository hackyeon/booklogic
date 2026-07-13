import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/app/app.dart';
import 'package:booklogic/core/constants/app_strings.dart';

void main() {
  testWidgets('shows home screen and opens game screen', (tester) async {
    await tester.pumpWidget(const BookLogicApp());

    expect(find.text(AppStrings.appTitle), findsOneWidget);
    expect(find.text(AppStrings.continueButton), findsOneWidget);

    await tester.tap(find.text(AppStrings.continueButton));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.levelOne), findsOneWidget);
    expect(find.text(AppStrings.gamePlaceholder), findsOneWidget);
  });

  testWidgets('opens settings screen from home', (tester) async {
    await tester.pumpWidget(const BookLogicApp());

    await tester.tap(find.text(AppStrings.settingsButton));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.sound), findsOneWidget);
    expect(find.text(AppStrings.music), findsOneWidget);
    expect(find.text(AppStrings.haptic), findsOneWidget);
  });
}
