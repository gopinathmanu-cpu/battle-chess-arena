import 'package:battle_chess_arena/src/domain/online_player_profile.dart';
import 'package:battle_chess_arena/src/domain/online_time_control.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/credits/credit_balance_chip.dart';
import 'package:battle_chess_arena/src/features/credits/gold_credit_coin.dart';
import 'package:battle_chess_arena/src/features/online/online_lobby_screen.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/online_fixtures.dart';

Map<String, Object> _creditPolicyJson() => {
  'version': 1,
  'starterCredits': 300,
  'dailyLoginCredits': 3,
  'dailyAllowanceCap': 300,
  'completionRewardCredits': 1,
  'dailyCompletionRewardCap': 5,
  'costs': {
    'liveHumanRound': 2,
    'dailyHumanRound': 3,
    'computerRound': 4,
    'onlineMoveSuggestion': 1,
  },
};

void main() {
  testWidgets('credit cost badge has compact price and accessible meaning', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: CreditCostBadge(cost: 2))),
      ),
    );

    expect(find.byType(GoldCreditCoin), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.bySemanticsLabel('Costs 2 credits'), findsOneWidget);
  });

  testWidgets('lobby marks each action that can create a credit charge', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final channel = FakeChannel();
    final client = OnlineMatchClient(
      channelFactory: (_) => channel,
      profile: const OnlinePlayerProfile(
        name: 'Credit Player',
        avatarId: 'avatar-01',
      ),
    );
    await client.connect(Uri.parse('ws://localhost:8080'));
    channel.receive({
      'type': 'connected',
      'protocolVersion': 4,
      'capabilities': [
        'credits',
        'shared_invites',
        'invite_clocks',
        'daily_games',
      ],
    });
    await tester.pump();
    final registration = channel.sent.single;
    channel.receive({
      'type': 'player_registered',
      'commandId': registration['commandId'],
      'name': 'Credit Player',
      'avatarId': 'avatar-01',
      'level': 'intermediate',
      'playerToken': 'credit-player-token',
      'credits': 300,
      'bonusCredits': 300,
      'purchasedCredits': 0,
      'creditPolicy': _creditPolicyJson(),
    });
    await tester.pump();
    channel.receive({
      'type': 'invites',
      'invites': [
        {
          'inviteId': 'daily-invite',
          'sender': {'name': 'Daily Friend', 'avatarId': 'avatar-02'},
          'recipient': {'name': 'Credit Player', 'avatarId': 'avatar-01'},
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'status': 'pending',
          'awaitingResponseFromName': 'Credit Player',
          'timed': true,
          'baseMs': 86400000,
          'clockMode': 'daily',
        },
      ],
    });
    await tester.pump();

    await tester.pumpWidget(
      MaterialApp(
        home: OnlineLobbyScreen(client: client, pack: piecePacks.first),
      ),
    );
    await tester.pump();

    final quickCost = find.byKey(const ValueKey('quick-match-credit-cost'));
    expect(quickCost, findsOneWidget);
    expect(
      find.descendant(of: quickCost, matching: find.text('2')),
      findsOneWidget,
    );

    final whatsApp = find.byKey(const ValueKey('invite-via-whatsapp'));
    await tester.ensureVisible(whatsApp);
    await tester.tap(whatsApp);
    await tester.pump(const Duration(milliseconds: 500));
    final inviteCost = find.byKey(const ValueKey('invite-format-credit-cost'));
    expect(
      find.descendant(of: inviteCost, matching: find.text('3')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(DropdownButtonFormField<OnlineTimeControl>),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Rapid · 15 + 10 sec').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.descendant(of: inviteCost, matching: find.text('2')),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 500));

    final invitation = find.byKey(const ValueKey('invite-daily-invite'));
    await tester.scrollUntilVisible(
      invitation,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final respond = find.descendant(
      of: invitation,
      matching: find.byTooltip('Respond to invitation'),
    );
    await tester.tap(respond);
    await tester.pump(const Duration(milliseconds: 500));
    final acceptCost = find.byKey(
      const ValueKey('accept-invite-credit-cost-daily-invite'),
    );
    expect(
      find.descendant(of: acceptCost, matching: find.text('3')),
      findsOneWidget,
    );
    await tester.tapAt(Offset.zero);
    await tester.pump(const Duration(milliseconds: 500));

    final computerCard = find.byKey(const ValueKey('computer-opponents-card'));
    await tester.scrollUntilVisible(
      computerCard,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Computer Opponents'));
    await tester.pump(const Duration(milliseconds: 500));
    final chooseComputer = find.byKey(
      const ValueKey('choose-computer-opponent'),
    );
    await tester.ensureVisible(chooseComputer);
    tester.widget<FilledButton>(chooseComputer).onPressed!();
    await tester.pump(const Duration(milliseconds: 500));
    final computerCost = find.byKey(
      const ValueKey('computer-opponent-cost-amina-diallo'),
    );
    expect(computerCost, findsOneWidget);
    expect(
      find.descendant(of: computerCost, matching: find.text('4')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    client.dispose();
    await tester.pump();
  });
}
