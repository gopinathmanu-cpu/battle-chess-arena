// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:battle_chess_arena/src/domain/online_credits.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/online/online_game_screen.dart';
import 'package:battle_chess_arena/src/features/online/online_lobby_screen.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_arena.dart';
import 'package:battle_chess_arena/src/features/play/match_opponent_panel.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_game_layout.dart';
import 'package:battle_chess_arena/src/services/game_history_storage.dart';
import 'package:battle_chess_arena/src/services/match_appearance_storage.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/online_fixtures.dart';

final _pack = piecePacks.firstWhere((p) => p.id == PiecePackId.futuristic);

class _LobbyFixture {
  _LobbyFixture(this.client, this.channels);
  final OnlineMatchClient client;
  final List<FakeChannel> channels;
  FakeChannel get channel => channels.last;
}

Future<_LobbyFixture> _lobby(
  WidgetTester tester, {
  Map<String, Object> saved = const {},
  bool classic = false,
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  SharedPreferences.setMockInitialValues(saved);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final channels = <FakeChannel>[];
  final client = OnlineMatchClient(
    channelFactory: (_) {
      final channel = FakeChannel();
      channels.add(channel);
      return channel;
    },
  );
  await client.connect(Uri.parse('ws://localhost:8080'));
  client.supportsCredits = true;
  client.creditAccount = OnlineCreditAccount.balanceOnly(20);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: OnlineLobbyScreen(
        client: client,
        pack: _pack,
        initialClassicPieces: classic,
      ),
    ),
  );
  await tester.pump();
  return _LobbyFixture(client, channels);
}

Future<void> _close(WidgetTester tester, _LobbyFixture fixture) async {
  await tester.pumpWidget(const SizedBox());
  fixture.client.dispose();
  await tester.pump(const Duration(milliseconds: 350));
  var archiveDone = false, historyDone = false, appearanceDone = false;
  Object? error;
  fixture.client.gameArchive.pending.then(
    (_) => archiveDone = true,
    onError: (Object e) {
      error = e;
      archiveDone = true;
    },
  );
  GameHistoryStorage().loadSnapshot().then(
    (_) => historyDone = true,
    onError: (Object e) {
      error = e;
      historyDone = true;
    },
  );
  MatchAppearanceStorage.load('room', 'w').then(
    (_) => appearanceDone = true,
    onError: (Object e) {
      error = e;
      appearanceDone = true;
    },
  );
  for (
    var i = 0;
    i < 100 && !(archiveDone && historyDone && appearanceDone);
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  expect(archiveDone && historyDone && appearanceDone, isTrue);
  expect(error, isNull);
  await tester.pump();
}

Future<void> _tapQuick(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('quick-match-button'));
  await tester.scrollUntilVisible(
    button,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 350));
  for (var i = 0; i < 15 && button.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -100));
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(button.hitTestable(), findsOneWidget);
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _computer(WidgetTester tester, {bool choose = true}) async {
  final card = find.byKey(const ValueKey('computer-opponents-card'));
  await tester.scrollUntilVisible(
    card,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  final button = find.byKey(const ValueKey('choose-computer-opponent'));
  if (button.evaluate().isEmpty) {
    await tester.tap(find.text('Computer Opponents'));
    await tester.pump(const Duration(milliseconds: 350));
  }
  await tester.scrollUntilVisible(
    button,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 350));
  for (var i = 0; i < 15 && button.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -100));
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(button.hitTestable(), findsOneWidget);
  await tester.tap(button);
  await tester.pump(const Duration(milliseconds: 350));
  if (!choose) return;
  await tester.tap(
    find.byKey(const ValueKey('computer-opponent-amina-diallo')),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  for (final classic in [true, false]) {
    testWidgets(
      'quick match keeps chosen family $classic without a startup prompt',
      (tester) async {
        final fixture = await _lobby(tester, classic: classic);
        try {
          await _tapQuick(tester);
          expect(find.byKey(const ValueKey('piece-type-choice')), findsNothing);
          final quick = fixture.channel.sent.single;
          expect(quick['type'], 'quick_match');
          expect(quick['baseMs'], greaterThan(0));
          expect(fixture.client.credits, 20);
          fixture.channel.receive({
            'type': 'match_found',
            'commandId': quick['commandId'],
            'gameId': 'room',
            'seat': 'w',
            'seatToken': 'test-secret',
            'state': stateJson(),
          });
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(OnlineGameScreen), findsOneWidget);
          expect(find.byKey(const ValueKey('piece-type-choice')), findsNothing);
          expect(
            tester
                .widget<ChessBoard>(find.byType(ChessBoard))
                .appearance!
                .standardPieces,
            classic,
          );
          expect(find.byType(NeonLiveArena), findsNothing);
          expect(find.byType(MatchOpponentPanel), findsOneWidget);
          expect(
            find.byKey(const ValueKey('online-opponent-profile')),
            findsOneWidget,
          );
          expect(fixture.client.credits, 20);
          expect(tester.takeException(), isNull);
        } finally {
          await _close(tester, fixture);
        }
      },
    );

    testWidgets(
      'accepted invitation keeps family $classic while server clocks update',
      (tester) async {
        final fixture = await _lobby(tester, classic: classic);
        try {
          fixture.channel.seat(
            state: stateJson(whiteMs: 45000, blackMs: 38000),
          );
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(OnlineGameScreen), findsOneWidget);
          expect(find.byKey(const ValueKey('piece-type-choice')), findsNothing);
          final fen = tester
              .widget<ChessBoard>(find.byType(ChessBoard))
              .position
              .fen;
          fixture.channel.receive({
            'type': 'game_state',
            'state': stateJson(sequence: 2, whiteMs: 40100, blackMs: 38000),
          });
          await tester.pump();
          await tester.pump();
          if (!classic) {
            final clocks = tester.widget<NeonLiveStatusBar>(
              find.byType(NeonLiveStatusBar),
            );
            expect(clocks.whiteTime.inMilliseconds, closeTo(40100, 1000));
            expect(clocks.blackTime.inMilliseconds, 38000);
          }
          expect(
            tester
                .widget<ChessBoard>(find.byType(ChessBoard))
                .appearance!
                .standardPieces,
            classic,
          );
          expect(
            tester.widget<ChessBoard>(find.byType(ChessBoard)).position.fen,
            fen,
          );
          expect(find.byType(NeonLiveArena), findsNothing);
          expect(find.byType(MatchOpponentPanel), findsOneWidget);
          expect(
            find.byKey(const ValueKey('online-opponent-profile')),
            findsOneWidget,
          );
          expect(
            fixture.channel.sent.where(
              (m) =>
                  m['type'] == 'quick_match' ||
                  m['type'] == 'start_computer_game' ||
                  m['type'] == 'move',
            ),
            isEmpty,
          );
          expect(tester.takeException(), isNull);
        } finally {
          await _close(tester, fixture);
        }
      },
    );
  }

  testWidgets(
    'cancelling computer selection is free; choosing launches directly',
    (tester) async {
      final fixture = await _lobby(tester, classic: true);
      try {
        await _computer(tester, choose: false);
        expect(find.text('Choose a computer opponent'), findsOneWidget);
        expect(fixture.channel.sent, isEmpty);
        await tester.tap(find.text('Cancel'));
        await tester.pump(const Duration(milliseconds: 350));
        expect(fixture.channel.sent, isEmpty);
        expect(fixture.client.credits, 20);
        await _computer(tester);
        expect(find.byKey(const ValueKey('piece-type-choice')), findsNothing);
        final command = fixture.channel.sent.single;
        expect(command['type'], 'start_computer_game');
        expect(command['opponentId'], 'amina-diallo');
        expect(fixture.client.credits, 20);
        fixture.channel.receive({
          'type': 'computer_match_found',
          'commandId': command['commandId'],
          'gameId': 'room',
          'seat': 'w',
          'seatToken': 'test-secret',
          'state': stateJson(blackComputer: true),
        });
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byKey(const ValueKey('piece-type-choice')), findsNothing);
        expect(
          tester
              .widget<ChessBoard>(find.byType(ChessBoard))
              .appearance!
              .standardPieces,
          isTrue,
        );
        expect(find.byType(NeonLiveArena), findsNothing);
        expect(
          find
              .byKey(const ValueKey('use-online-computer-lifeline'))
              .hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  testWidgets(
    'resuming saved active game keeps armies and piece style without a prompt',
    (tester) async {
      final fixture = await _lobby(
        tester,
        saved: {
          MatchAppearanceStorage.key('room', 'b'): [
            'japanese',
            'roman',
            'chola',
            'classic',
            'wood',
          ],
        },
      );
      try {
        fixture.channel.receive({
          'type': 'active_games',
          'games': [
            {
              'gameId': 'room',
              'seat': 'b',
              'seatToken': 'saved-secret',
              'state': stateJson(),
            },
          ],
        });
        await tester.pump();
        final resume = find.byKey(const ValueKey('active-room'));
        await tester.scrollUntilVisible(
          resume,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(resume);
        for (var i = 0; i < 10 && fixture.channels.length < 2; i++) {
          await tester.pump(const Duration(milliseconds: 10));
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        }
        expect(fixture.channels.length, 2);
        fixture.channel.receive({
          'type': 'seat_resumed',
          'gameId': 'room',
          'seat': 'b',
          'seatToken': 'saved-secret',
          'state': stateJson(),
        });
        await tester.pump();
        fixture.channel.receive({
          'type': 'game_state',
          'synced': true,
          'state': stateJson(sequence: 2),
        });
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(OnlineGameScreen), findsOneWidget);
        expect(find.byKey(const ValueKey('piece-type-choice')), findsNothing);
        final appearance = tester
            .widget<ChessBoard>(find.byType(ChessBoard))
            .appearance!;
        expect(appearance.white.id, PiecePackId.japanese);
        expect(appearance.black.id, PiecePackId.roman);
        expect(appearance.board.id, PiecePackId.chola);
        expect(appearance.standardPieces, isTrue);
        expect(appearance.classicStyle, ClassicPieceStyle.wood);
        expect(
          fixture.channel.sent.where(
            (m) =>
                m['type'] == 'quick_match' ||
                m['type'] == 'start_computer_game',
          ),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  for (final (size, scale) in [
    (const Size(320, 568), 1.5),
    (const Size(650, 360), 2.0),
  ]) {
    testWidgets(
      'quick-match launch has no popup at $size and text scale $scale',
      (tester) async {
        final fixture = await _lobby(tester, size: size, scale: scale);
        try {
          await _tapQuick(tester);
          expect(find.byKey(const ValueKey('piece-type-choice')), findsNothing);
          expect(fixture.channel.sent.single['type'], 'quick_match');
          expect(tester.takeException(), isNull);
        } finally {
          await _close(tester, fixture);
        }
      },
    );
  }
}
