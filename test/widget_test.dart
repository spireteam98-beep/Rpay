// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_exchange_app/main.dart';

void main() {
  testWidgets('Kashflip opens on onboarding', (WidgetTester tester) async {
    await tester.pumpWidget(const CryptoExchangeApp());

    expect(find.text('KASHFLIP'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('Signup flow reaches OTP screen', (WidgetTester tester) async {
    await tester.pumpWidget(const CryptoExchangeApp());

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Join Kashflip'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the 6-digit code'), findsOneWidget);
  });

  testWidgets('Verified onboarding reaches dashboard and send flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CryptoExchangeApp());

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }

    await tester.ensureVisible(find.text('Verify'));
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.textContaining('Skip for now'));
    await tester.tap(find.textContaining('Skip for now'));
    await tester.pumpAndSettle();

    expect(find.text('Your accounts are ready'), findsOneWidget);
    await tester.tap(find.text('Go to my dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Unified balance'), findsOneWidget);
    expect(find.text('Your money identities'), findsOneWidget);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Move money anywhere'), findsOneWidget);
    expect(find.text('Kashflip user'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, '@amina');
    await tester.ensureVisible(find.text('Review transfer'));
    await tester.tap(find.text('Review transfer'));
    await tester.pumpAndSettle();

    expect(find.text('Transfer queued'), findsOneWidget);
    expect(
      find.text('\$50.00 transfer queued through Kashflip user.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('\$24,468.32'), findsOneWidget);
    expect(find.text('@amina'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Fund domestic wallet'), findsOneWidget);
    await tester.ensureVisible(find.text('Add money'));
    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();

    expect(find.text('Money added'), findsOneWidget);
    expect(find.text('\$100.00 added through EVC Plus.'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('\$24,568.32'), findsOneWidget);

    await tester.tap(find.text('Ledger'));
    await tester.pumpAndSettle();

    expect(find.text('Double-entry ledger'), findsOneWidget);
    expect(find.text('EVC Plus cash-in'), findsOneWidget);
    expect(find.text('KFL-001006'), findsOneWidget);
  });
}
