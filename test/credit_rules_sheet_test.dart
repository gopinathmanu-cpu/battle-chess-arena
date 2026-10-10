import 'package:battle_chess_arena/src/features/credits/credit_rules_sheet.dart';
import 'package:battle_chess_arena/src/services/arena_credit_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('credit guide shows costs, earnings, fairness and packs', (
    tester,
  ) async {
    final wallet = ArenaCreditController();
    addTearDown(wallet.dispose);
    await tester.pumpWidget(
      ArenaCreditScope(
        controller: wallet,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCreditRulesSheet(context),
              child: const Text('Credits guide'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Credits guide'));
    await tester.pumpAndSettle();
    expect(find.text('How Credits Work'), findsOneWidget);
    expect(find.text('Live online round'), findsNothing);
    expect(find.text('Immediate tournament or Conquest retry'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Move suggestion'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Move suggestion'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Low-balance safety grant'),
      350,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Low-balance safety grant'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Arena Grandmaster'),
      350,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Arena Grandmaster'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Credit packs are not sold in this beta'),
      350,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Credit packs are not sold in this beta'), findsOneWidget);
  });
}
