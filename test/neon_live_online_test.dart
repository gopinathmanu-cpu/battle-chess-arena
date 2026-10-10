// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:battle_chess_arena/src/domain/animated_army_theme.dart';
import 'package:battle_chess_arena/src/domain/custom_chess_set.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/online/online_game_screen.dart';
import 'package:battle_chess_arena/src/features/online/online_avatar_image.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/capture_battle_overlay.dart';
import 'package:battle_chess_arena/src/features/play/checkmate_dialog.dart';
import 'package:battle_chess_arena/src/features/play/checkmate_animation.dart';
import 'package:battle_chess_arena/src/features/play/neon_illustrated_stage.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_arena.dart';
import 'package:battle_chess_arena/src/features/play/match_opponent_panel.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_game_layout.dart';
import 'package:battle_chess_arena/src/services/custom_chess_sets.dart';
import 'package:battle_chess_arena/src/services/game_history_storage.dart';
import 'package:battle_chess_arena/src/services/match_appearance_storage.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/game_settings.dart';
import 'support/online_fixtures.dart';

final _neon = piecePacks.firstWhere((p) => p.id == PiecePackId.futuristic);
ChessBoard _board(WidgetTester tester) =>
    tester.widget<ChessBoard>(find.byType(ChessBoard));

class _OnlineFixture {
  _OnlineFixture(this.client, this.channels, this.sets);
  final OnlineMatchClient client;
  final List<FakeChannel> channels;
  FakeChannel get channel => channels.last;
  final CustomChessSets? sets;

  Future<void> accept(
    WidgetTester tester,
    GameSession game, {
    required int sequence,
    int round = 1,
  }) async {
    channel.receive({
      'type': 'game_state',
      'state': stateJson(game: game, sequence: sequence, round: round),
    });
    await tester.pump();
    await tester.pump();
  }
}

Future<_OnlineFixture> _open(
  WidgetTester tester, {
  String seat = 'w',
  GameSession? game,
  Size size = const Size(390, 844),
  double textScale = 1,
  PiecePack? pack,
  List<String>? appearance,
  bool classic = false,
  bool custom = false,
  bool blackComputer = false,
  bool animatedArena = true,
}) async {
  SharedPreferences.setMockInitialValues({
    if (appearance != null)
      MatchAppearanceStorage.key('room', seat): appearance,
  });
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
  channels.last.seat(
    seat: seat,
    state: stateJson(game: game, blackComputer: blackComputer),
  );
  await tester.pump();
  final sets = custom ? CustomChessSets(autoLoad: false) : null;
  if (sets != null) {
    expect(await sets.save(CustomChessSet.create(id: 'my-neon')), isTrue);
  }
  Widget app = MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: OnlineGameScreen(
      client: client,
      pack: pack ?? _neon,
      initialClassicPieces: classic,
      initialAnimatedArena: animatedArena,
    ),
  );
  if (sets != null) {
    app = CustomChessSetScope(controller: sets, child: app);
  }
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
  return _OnlineFixture(client, channels, sets);
}

Future<void> _close(WidgetTester tester, _OnlineFixture fixture) async {
  await tester.pumpWidget(const SizedBox());
  fixture.client.dispose();
  fixture.sets?.dispose();
  // The existing result presentation delay checks mounted before showing UI.
  await tester.pump(const Duration(milliseconds: 300));
  var historyDone = false, appearanceDone = false, archiveDone = false;
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
    i < 100 && (!historyDone || !appearanceDone || !archiveDone);
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 10));
    // A reconnected transport can create listeners in the real event loop.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  expect(historyDone && appearanceDone && archiveDone, isTrue);
  expect(error, isNull);
  await tester.pump();
}

Future<void> _select(WidgetTester tester, Square square) async {
  await tester.tap(find.byKey(ValueKey('square-${square.name}')));
  await tester.pump();
}

void _expectCaptureAligned(WidgetTester tester, Square target) {
  final square = tester.getRect(find.byKey(ValueKey('square-${target.name}')));
  final victim = tester.getRect(
    find.byKey(ValueKey('board-captured-${target.name}')),
  );
  expect(victim.center.dx, closeTo(square.center.dx, .1));
  expect(victim.center.dy, closeTo(square.center.dy, .1));
  expect(victim.width, closeTo(square.width, .1));
  expect(victim.height, closeTo(square.height, .1));
}

Finder get _opponentPanel =>
    find.byKey(const ValueKey('online-opponent-profile'));

void _expectOpponent(WidgetTester tester, _OnlineFixture fixture) {
  expect(_opponentPanel, findsOneWidget);
  expect(find.byType(MatchOpponentPanel), findsOneWidget);
  expect(find.byType(NeonLiveArena), findsNothing);
  final opponent = fixture.client.state!.opponentFor(
    fixture.client.seat ?? 'w',
  );
  expect(
    find.descendant(of: _opponentPanel, matching: find.text(opponent.name)),
    findsOneWidget,
  );
  final avatar = tester.widget<OnlineAvatarImage>(
    find.descendant(
      of: _opponentPanel,
      matching: find.byType(OnlineAvatarImage),
    ),
  );
  expect(avatar.avatarId, opponent.avatarId);
  final panel = tester.widget<MatchOpponentPanel>(_opponentPanel);
  expect(panel.name, opponent.name);
  expect(
    panel.details,
    contains(opponent.computer ? 'Computer' : 'Online player'),
  );
  expect(
    panel.details,
    contains(fixture.client.state!.timed ? 'Timed game' : 'No timer'),
  );
  expect(
    tester
        .widget<NeonLiveGameLayout>(find.byType(NeonLiveGameLayout))
        .compactPortraitArena,
    isTrue,
  );
}

void main() {
  testWidgets(
    'all four online worlds retain opponent identity through Classic swipe and accepted capture',
    (tester) async {
      for (final theme in AnimatedArmyTheme.values) {
        final pack = availablePiecePacks.singleWhere(
          (p) => p.id == theme.packId,
        );
        final game = GameSession.fromMoves(moves: ['e2e4', 'd7d5']);
        final fixture = await _open(tester, game: game, pack: pack);
        try {
          _expectOpponent(tester, fixture);
          expect(_board(tester).showCoordinates, isTrue);
          await _select(tester, Square.e4);
          expect(_board(tester).selected, Square.e4);
          expect(_board(tester).legalTargets, contains(Square.d5));
          await tester.drag(find.byType(ChessBoard), const Offset(-100, 0));
          await tester.pump();
          expect(_board(tester).appearance!.standardPieces, isTrue);
          expect(_board(tester).appearance!.white.id, theme.packId);
          expect(_board(tester).appearance!.black.id, theme.packId);
          expect(_board(tester).selected, Square.e4);
          expect(_board(tester).position.fen, game.position.fen);
          _expectOpponent(tester, fixture);
          await _select(tester, Square.d5);
          final request = fixture.channel.sent.lastWhere(
            (m) => m['type'] == 'move',
          );
          expect(request['move'], containsPair('from', 'e4'));
          expect(request['move'], containsPair('to', 'd5'));
          expect(_board(tester).position.fen, game.position.fen);
          expect(find.byType(CaptureBattleOverlay), findsNothing);
          game.playUci('e4d5');
          await fixture.accept(tester, game, sequence: 2);
          expect(
            fixture.client.session.committedMove!.attacker,
            Piece.whitePawn,
          );
          expect(
            fixture.client.session.committedMove!.defender,
            Piece.blackPawn,
          );
          expect(_board(tester).appearance!.standardPieces, isTrue);
          expect(_board(tester).position.fen, game.position.fen);
          expect(
            _board(tester).position.board.pieceAt(Square.d5),
            Piece.whitePawn,
          );
          expect(find.byType(CaptureBattleOverlay), findsOneWidget);
          expect(_board(tester).hiddenPieceSquare, isNull);
          expect(
            find.byKey(const ValueKey('live-capture-skip')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('board-moving-e4-d5')),
            findsOneWidget,
          );
          _expectCaptureAligned(tester, Square.d5);
          _expectOpponent(tester, fixture);
          expect(tester.takeException(), isNull);
        } finally {
          await _close(tester, fixture);
        }
      }
    },
  );

  testWidgets(
    'selection preserves legal victims and changing source replaces board targets',
    (tester) async {
      final game = GameSession.fromMoves(moves: ['e2e4', 'd7d5']);
      final fixture = await _open(tester, game: game);
      try {
        await _select(tester, Square.e4);
        expect(_board(tester).selected, Square.e4);
        expect(_board(tester).legalTargets, contains(Square.d5));
        expect(
          _board(tester).position.board.pieceAt(Square.d5),
          Piece.blackPawn,
        );
        _expectOpponent(tester, fixture);
        await _select(tester, Square.g1);
        expect(_board(tester).selected, Square.g1);
        expect(_board(tester).legalTargets, isNot(contains(Square.d5)));
        expect(fixture.client.state!.san, ['e4', 'd5']);
        expect(fixture.channel.sent.where((m) => m['type'] == 'move'), isEmpty);
        _expectOpponent(tester, fixture);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  testWidgets(
    'Black seat shows the actual White opponent and retains legal capture selection',
    (tester) async {
      final game = GameSession.fromMoves(moves: ['e2e4', 'd7d5', 'e4d5']);
      final fixture = await _open(tester, game: game, seat: 'b');
      try {
        expect(_board(tester).orientation, Side.black);
        _expectOpponent(tester, fixture);
        expect(
          find.descendant(
            of: _opponentPanel,
            matching: find.text('White Hero'),
          ),
          findsOneWidget,
        );
        await _select(tester, Square.d8);
        expect(_board(tester).selected, Square.d8);
        expect(_board(tester).legalTargets, contains(Square.d5));
        expect(
          _board(tester).position.board.pieceAt(Square.d5),
          Piece.whitePawn,
        );
        expect(fixture.channel.sent.where((m) => m['type'] == 'move'), isEmpty);
        _expectOpponent(tester, fixture);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  testWidgets(
    'accepted opponent move updates board threats and allows next own selection',
    (tester) async {
      final game = GameSession.fromMoves(
        moves: ['e2e4', 'e7e5', 'f1c4', 'b8c6', 'd1h5'],
      );
      final fixture = await _open(tester, game: game);
      try {
        await _select(tester, Square.h5);
        expect(_board(tester).selected, isNull);
        game.playUci('g8f6');
        await fixture.accept(tester, game, sequence: 2);
        final move = fixture.client.session.committedMove!;
        expect(move.attacker, Piece.blackKnight);
        expect(move.move.from, Square.g8);
        expect(move.move.to, Square.f6);
        expect(_board(tester).position.fen, game.position.fen);
        expect(_board(tester).lastMoveFrom, Square.g8);
        expect(_board(tester).lastMoveTo, Square.f6);
        expect(
          _board(tester).position.board.pieceAt(Square.h5),
          Piece.whiteQueen,
        );
        await _select(tester, Square.h5);
        expect(_board(tester).selected, Square.h5);
        expect(_board(tester).legalTargets, contains(Square.f7));
        _expectOpponent(tester, fixture);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  testWidgets(
    'accepted checking move preserves the checked king and authoritative check status',
    (tester) async {
      final game = GameSession.fromMoves(moves: ['e2e4', 'f7f6']);
      final fixture = await _open(tester, game: game, seat: 'b');
      try {
        game.playUci('d1h5');
        await fixture.accept(tester, game, sequence: 2);
        expect(
          fixture.client.session.committedMove!.attacker,
          Piece.whiteQueen,
        );
        expect(fixture.client.session.committedMove!.defender, isNull);
        expect(_board(tester).position.isCheck, isTrue);
        expect(
          _board(tester).position.board.pieceAt(Square.e8),
          Piece.blackKing,
        );
        expect(fixture.client.state!.statusLabel, contains('CHECK'));
        _expectOpponent(tester, fixture);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  testWidgets(
    'delayed acceptance keeps opponent panel without optimistic board movement or capture',
    (tester) async {
      final fixture = await _open(tester);
      try {
        await _select(tester, Square.e2);
        await _select(tester, Square.e4);
        final request = fixture.channel.sent.last;
        expect(request['type'], 'move');
        expect(request['move'], containsPair('from', 'e2'));
        expect(request['move'], containsPair('to', 'e4'));
        expect(fixture.client.state!.san, isEmpty);
        expect(_board(tester).position.fen, Chess.initial.fen);
        expect(_board(tester).selected, isNull);
        expect(find.byKey(const ValueKey('board-moving-e2-e4')), findsNothing);
        expect(find.byType(CaptureBattleOverlay), findsNothing);
        final panel = tester.getRect(_opponentPanel);
        await tester.pump(const Duration(milliseconds: 600));
        fixture.channel.receive({
          'type': 'command_result',
          'commandId': request['commandId'],
          'accepted': true,
        });
        await tester.pump();
        expect(_board(tester).position.fen, Chess.initial.fen);
        expect(find.byKey(const ValueKey('board-moving-e2-e4')), findsNothing);
        await _select(tester, Square.a2);
        expect(_board(tester).selected, isNull);
        expect(
          fixture.channel.sent.where((m) => m['type'] == 'move').length,
          1,
        );
        expect(tester.getRect(_opponentPanel), panel);
        final game = GameSession()..playUci('e2e4');
        await fixture.accept(tester, game, sequence: 2);
        expect(_board(tester).position.fen, game.position.fen);
        expect(
          _board(tester).position.board.pieceAt(Square.e4),
          Piece.whitePawn,
        );
        expect(
          find.byKey(const ValueKey('board-moving-e2-e4')),
          findsOneWidget,
        );
        expect(fixture.client.state!.san, ['e4']);
        _expectOpponent(tester, fixture);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  for (final rejected in [true, false]) {
    testWidgets(
      'pending request clears after ${rejected ? 'server rejection' : 'disconnect'} without a false move',
      (tester) async {
        final fixture = await _open(tester);
        try {
          await _select(tester, Square.e2);
          await _select(tester, Square.e4);
          if (rejected) {
            fixture.channel.receive({
              'type': 'command_result',
              'commandId': fixture.channel.sent.last['commandId'],
              'accepted': false,
              'message': 'Move rejected',
            });
          } else {
            fixture.client.disconnect();
          }
          await tester.pump();
          expect(_board(tester).position.fen, Chess.initial.fen);
          expect(_board(tester).selected, isNull);
          expect(
            find.byKey(const ValueKey('board-moving-e2-e4')),
            findsNothing,
          );
          expect(find.byType(CaptureBattleOverlay), findsNothing);
          _expectOpponent(tester, fixture);
          if (rejected) {
            await _select(tester, Square.a2);
            expect(_board(tester).selected, Square.a2);
          }
          expect(tester.takeException(), isNull);
        } finally {
          await _close(tester, fixture);
        }
      },
    );
  }

  testWidgets(
    'clock-only and stale revisions preserve the board while reconnect gaps and new rounds clear selection',
    (tester) async {
      final game = GameSession.fromMoves(
        moves: ['e2e4', 'e7e5', 'f1c4', 'b8c6', 'd1h5'],
      );
      final fixture = await _open(tester, game: game);
      try {
        game.playUci('g8f6');
        await fixture.accept(tester, game, sequence: 2);
        await tester.pump(const Duration(milliseconds: 900));
        await _select(tester, Square.h5);
        final targets = _board(tester).legalTargets;
        await fixture.accept(tester, game, sequence: 3);
        expect(_board(tester).selected, Square.h5);
        expect(_board(tester).legalTargets, targets);
        expect(find.byKey(const ValueKey('board-moving-g8-f6')), findsNothing);
        await fixture.accept(tester, GameSession(), sequence: 2);
        expect(_board(tester).position.fen, game.position.fen);
        expect(_board(tester).selected, Square.h5);
        game.playUci('h5e2');
        game.playUci('d7d6');
        await fixture.accept(tester, game, sequence: 4);
        expect(_board(tester).position.fen, game.position.fen);
        expect(_board(tester).selected, isNull);
        await _select(tester, Square.e2);
        expect(_board(tester).selected, Square.e2);
        await fixture.accept(tester, GameSession(), sequence: 5, round: 2);
        expect(_board(tester).selected, isNull);
        expect(_board(tester).position.fen, Chess.initial.fen);
        _expectOpponent(tester, fixture);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  testWidgets(
    'opponent capture uses the shared board victim and preserves skip flow',
    (tester) async {
      final game = GameSession.fromMoves(moves: ['e2e4', 'd7d5', 'e4d5']);
      final fixture = await _open(tester, game: game);
      try {
        game.playUci('d8d5');
        await fixture.accept(tester, game, sequence: 2);
        final resolution = fixture.client.session.committedMove!;
        expect(resolution.attacker, Piece.blackQueen);
        expect(resolution.defender, Piece.whitePawn);
        expect(resolution.move.to, Square.d5);
        expect(_board(tester).position.fen, game.position.fen);
        expect(_board(tester).hiddenPieceSquare, isNull);
        expect(find.byType(CaptureBattleOverlay), findsOneWidget);
        expect(
          find.byKey(const ValueKey('live-capture-skip')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('board-moving-d8-d5')),
          findsOneWidget,
        );
        _expectCaptureAligned(tester, Square.d5);
        expect(
          tester
              .widget<CaptureBattleOverlay>(find.byType(CaptureBattleOverlay))
              .battle
              .defender,
          Piece.whitePawn,
        );
        _expectOpponent(tester, fixture);
        await tester.tap(find.byKey(const ValueKey('live-capture-skip')));
        await tester.pump();
        expect(find.byType(CaptureBattleOverlay), findsNothing);
        expect(_board(tester).position.fen, game.position.fen);
        expect(
          _board(tester).position.board.pieceAt(Square.d5),
          Piece.blackQueen,
        );
        _expectOpponent(tester, fixture);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  testWidgets(
    'changing room replaces opponent identity and disconnect prevents stale input',
    (tester) async {
      final game = GameSession.fromMoves(moves: ['e2e4', 'd7d5']);
      final fixture = await _open(tester, game: game);
      try {
        await _select(tester, Square.e4);
        expect(_board(tester).selected, Square.e4);
        final next = GameSession()..playUci('e2e4');
        await tester.runAsync(fixture.client.startAnotherGame);
        fixture.client.joinGame('next-room');
        final commandId = fixture.channel.sent.last['commandId'];
        fixture.channel.receive({
          'type': 'seat_joined',
          'commandId': commandId,
          'gameId': 'next-room',
          'seat': 'b',
          'seatToken': 'test-seat-token',
          'state': stateJson(
            game: next,
            gameId: 'next-room',
            whiteName: 'New White Rival',
            whiteAvatar: 'avatar-12',
          ),
        });
        await tester.pump();
        await tester.pump();
        expect(_board(tester).selected, isNull);
        expect(_board(tester).orientation, Side.black);
        expect(find.byKey(const ValueKey('piece-type-choice')), findsNothing);
        _expectOpponent(tester, fixture);
        expect(find.text('Black Hero'), findsNothing);
        expect(
          find.descendant(
            of: _opponentPanel,
            matching: find.text('New White Rival'),
          ),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 300));
        await _select(tester, Square.d8);
        expect(_board(tester).selected, Square.d8);
        fixture.client.disconnect();
        await tester.pump();
        expect(_board(tester).selected, isNull);
        await _select(tester, Square.d8);
        expect(_board(tester).selected, isNull);
        _expectOpponent(tester, fixture);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  for (final reason in ['timeout', 'resignation']) {
    testWidgets(
      'server $reason with unchanged board clears selected capture targets',
      (tester) async {
        final game = GameSession.fromMoves(moves: ['e2e4', 'd7d5']);
        final fixture = await _open(tester, game: game);
        try {
          await _select(tester, Square.e4);
          expect(_board(tester).legalTargets, contains(Square.d5));
          final fen = _board(tester).position.fen;
          fixture.channel.receive({
            'type': 'game_state',
            'state': stateJson(
              game: game,
              sequence: 2,
              status: 'complete',
              result: {'reason': reason, 'winner': 'b'},
            ),
          });
          await tester.pump();
          await tester.pump();
          expect(fixture.client.state!.status, 'complete');
          expect(_board(tester).position.fen, fen);
          expect(_board(tester).selected, isNull);
          expect(_board(tester).legalTargets, isEmpty);
          _expectOpponent(tester, fixture);
          expect(tester.takeException(), isNull);
        } finally {
          await _close(tester, fixture);
        }
      },
    );
  }

  for (final theme in AnimatedArmyTheme.values) {
    testWidgets(
      'Classic ${theme.displayName} keeps themed mate animation and cinematic summary available',
      (tester) async {
        final game = GameSession.fromMoves(moves: ['f2f3', 'e7e5', 'g2g4']);
        final fixture = await _open(
          tester,
          game: game,
          pack: availablePiecePacks.singleWhere((p) => p.id == theme.packId),
        );
        try {
          _board(tester).onSetSwipe!(1);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(_board(tester).appearance!.standardPieces, isTrue);
          game.playUci('d8h4');
          for (final sequence in [2, 3]) {
            fixture.channel.receive({
              'type': 'game_state',
              'state': stateJson(
                game: game,
                sequence: sequence,
                status: 'complete',
                result: {'reason': 'checkmate', 'winner': 'b'},
              ),
            });
            await tester.pump();
            await tester.pump();
            if (sequence == 2) {
              expect(
                fixture.client.session.committedMove!.move.from,
                Square.d8,
              );
              expect(fixture.client.session.committedMove!.move.to, Square.h4);
            } else {
              expect(fixture.client.session.committedMove, isNull);
            }
            expect(_board(tester).lastMoveFrom, Square.d8);
            expect(_board(tester).lastMoveTo, Square.h4);
            expect(_board(tester).position.isCheckmate, isTrue);
            expect(
              _board(tester).position.board.pieceAt(Square.e1),
              Piece.whiteKing,
            );
            expect(_board(tester).selected, isNull);
            expect(_board(tester).legalTargets, isEmpty);
            _expectOpponent(tester, fixture);
          }
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump();
          expect(find.byType(CheckmateAnimation), findsOneWidget);
          expect(
            tester
                .widget<NeonFigureSprite>(
                  find.descendant(
                    of: find.byType(CheckmateAnimation),
                    matching: find.byType(NeonFigureSprite),
                  ),
                )
                .theme,
            theme,
          );
          // The only backdrop belongs to the mate route; the actual result
          // dialog and its separate backdrop must wait for completion.
          expect(find.byType(MatchResultBackdrop), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(CheckmateAnimation),
              matching: find.byType(MatchResultBackdrop),
            ),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('checkmate-heading')), findsNothing);
          await tester.pump(
            checkmateAnimationDuration + const Duration(milliseconds: 1),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 700));
          expect(find.byType(CheckmateAnimation), findsNothing);
          expect(
            find.byKey(const ValueKey('checkmate-heading')),
            findsOneWidget,
          );
          expect(find.byType(CinematicSummaryButton), findsWidgets);
          final backdrop = tester.widget<Image>(
            find.descendant(
              of: find.byType(MatchResultBackdrop),
              matching: find.byType(Image),
            ),
          );
          expect((backdrop.image as AssetImage).assetName, theme.worldAsset);
          expect(find.text('Watch cinematic summary'), findsWidgets);
          expect(tester.takeException(), isNull);
        } finally {
          await _close(tester, fixture);
        }
      },
    );
  }

  for (final (name, pack, appearance, classic, custom, coordinates) in [
    ('classic Neon board', _neon, null, true, false, true),
    ('classic Manga board', piecePacks.first, null, true, false, true),
    ('Manga board', piecePacks.first, null, false, false, true),
    (
      'mixed armies',
      _neon,
      ['futuristic', 'anime', 'futuristic', 'themed', 'magneticTeaching'],
      false,
      false,
      false,
    ),
    (
      'Neon armies on another board',
      _neon,
      ['futuristic', 'futuristic', 'anime', 'themed', 'magneticTeaching'],
      false,
      false,
      true,
    ),
    ('custom set', _neon, null, false, true, false),
  ]) {
    testWidgets(
      'opponent panel appears independently of board artwork: $name',
      (tester) async {
        final fixture = await _open(
          tester,
          pack: pack,
          appearance: appearance,
          classic: classic,
          custom: custom,
        );
        try {
          _expectOpponent(tester, fixture);
          expect(find.byType(ChessBoard), findsOneWidget);
          expect(_board(tester).appearance!.customSet != null, custom);
          expect(_board(tester).appearance!.standardPieces, classic);
          expect(_board(tester).showCoordinates, coordinates);
          expect(
            find.byKey(const ValueKey('board-coordinate-frame')),
            coordinates ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
        } finally {
          await _close(tester, fixture);
        }
      },
    );
  }

  testWidgets(
    'quick Classic toggle preserves selection, legal victims and opponent profile',
    (tester) async {
      final game = GameSession.fromMoves(moves: ['e2e4', 'd7d5']);
      final fixture = await _open(tester, game: game);
      try {
        await _select(tester, Square.e4);
        final targets = _board(tester).legalTargets;
        final toggle = find.byKey(
          const ValueKey('online-quick-piece-style-toggle'),
        );
        for (final classic in [true, false]) {
          await tester.tap(toggle);
          await tester.pump();
          expect(_board(tester).appearance!.standardPieces, classic);
          expect(_board(tester).selected, Square.e4);
          expect(_board(tester).legalTargets, targets);
          expect(_board(tester).position.fen, game.position.fen);
          _expectOpponent(tester, fixture);
        }
        expect(fixture.channel.sent.where((m) => m['type'] == 'move'), isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  for (final (seat, firstSwipe, initialClassic) in [
    ('w', const Offset(-100, 0), false),
    ('b', const Offset(100, 0), true),
  ]) {
    testWidgets(
      '$seat swipes both directions toggle Classic without changing armies or authoritative chess',
      (tester) async {
        final game = GameSession.fromMoves(
          moves: seat == 'w' ? ['e2e4', 'd7d5'] : ['e2e4', 'd7d5', 'e4d5'],
        );
        final fixture = await _open(
          tester,
          seat: seat,
          game: game,
          classic: initialClassic,
        );
        try {
          final source = seat == 'w' ? Square.e4 : Square.d8;
          await _select(tester, source);
          final targets = _board(tester).legalTargets;
          final style = _board(tester).appearance!.classicStyle;
          for (final (delta, classic) in [
            (firstSwipe, !initialClassic),
            (-firstSwipe, initialClassic),
          ]) {
            await tester.drag(find.byType(ChessBoard), delta);
            await tester.pump();
            final board = _board(tester);
            expect(board.appearance!.standardPieces, classic);
            expect(board.appearance!.classicStyle, style);
            expect(board.appearance!.white.id, PiecePackId.futuristic);
            expect(board.appearance!.black.id, PiecePackId.futuristic);
            expect(board.appearance!.board.id, PiecePackId.futuristic);
            expect(board.orientation, seat == 'w' ? Side.white : Side.black);
            expect(board.showCoordinates, isTrue);
            expect(board.position.fen, game.position.fen);
            expect(board.selected, source);
            expect(board.legalTargets, targets);
            _expectOpponent(tester, fixture);
          }
          expect(
            fixture.channel.sent.where((m) => m['type'] == 'move'),
            isEmpty,
          );
          expect(
            tester.getCenter(find.byKey(const ValueKey('board-file-top-A'))).dx,
            seat == 'w'
                ? lessThan(
                    tester
                        .getCenter(
                          find.byKey(const ValueKey('board-file-top-H')),
                        )
                        .dx,
                  )
                : greaterThan(
                    tester
                        .getCenter(
                          find.byKey(const ValueKey('board-file-top-H')),
                        )
                        .dx,
                  ),
          );
          await _select(tester, Square.d5);
          final request = fixture.channel.sent.lastWhere(
            (m) => m['type'] == 'move',
          );
          expect(request['move'], containsPair('from', source.name));
          expect(request['move'], containsPair('to', 'd5'));
          expect(fixture.client.busy, isTrue);
          expect(
            fixture.channel.sent.where((m) => m['type'] == 'move').length,
            1,
          );
          expect(_board(tester).position.fen, game.position.fen);
          expect(_board(tester).selected, isNull);
          expect(find.byType(CaptureBattleOverlay), findsNothing);
          _expectOpponent(tester, fixture);
          game.playUci('${source.name}d5');
          await fixture.accept(tester, game, sequence: 2);
          expect(_board(tester).position.fen, game.position.fen);
          expect(
            fixture.client.session.committedMove!.defender,
            seat == 'w' ? Piece.blackPawn : Piece.whitePawn,
          );
          _expectCaptureAligned(tester, Square.d5);
          final status = tester.widget<NeonLiveStatusBar>(
            find.byType(NeonLiveStatusBar),
          );
          expect(status.turn, game.position.turn);
          expect(status.timed, isTrue);
          expect(
            status.whiteTime.inMilliseconds,
            closeTo(fixture.client.session.clockMs('w'), 1000),
          );
          expect(
            status.blackTime.inMilliseconds,
            closeTo(fixture.client.session.clockMs('b'), 1000),
          );
          _expectOpponent(tester, fixture);
          expect(tester.takeException(), isNull);
        } finally {
          await _close(tester, fixture);
        }
      },
    );
  }

  testWidgets(
    'settings switch page families without changing accepted position, clocks or opponent',
    (tester) async {
      final game = GameSession.fromMoves(
        moves: ['e2e4', 'e7e5', 'f1c4', 'b8c6', 'd1h5'],
      );
      final fixture = await _open(tester, game: game);
      try {
        game.playUci('g8f6');
        await fixture.accept(tester, game, sequence: 2);
        final fen = _board(tester).position.fen;
        await openGameSettings(
          tester,
          target: find.byKey(const ValueKey('settings-classic-plastic')),
        );
        await tester.tap(
          find.byKey(const ValueKey('settings-classic-plastic')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(_board(tester).appearance!.standardPieces, isTrue);
        expect(_board(tester).appearance!.animatedArena, isFalse);
        expect(_board(tester).position.fen, fen);
        _expectOpponent(tester, fixture);
        await tester.ensureVisible(
          find.byKey(const ValueKey('settings-animated-futuristic')),
        );
        await tester.tap(
          find.byKey(const ValueKey('settings-animated-futuristic')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close settings'));
        await tester.pumpAndSettle();
        expect(
          _board(tester).appearance!.classicStyle,
          ClassicPieceStyle.plastic,
        );
        expect(_board(tester).appearance!.white.id, PiecePackId.futuristic);
        expect(_board(tester).appearance!.black.id, PiecePackId.futuristic);
        expect(_board(tester).appearance!.animatedArena, isTrue);
        expect(_board(tester).position.fen, game.position.fen);
        expect(_board(tester).lastMoveFrom, Square.g8);
        expect(_board(tester).lastMoveTo, Square.f6);
        expect(find.byKey(const ValueKey('board-moving-g8-f6')), findsNothing);
        fixture.channel.receive({
          'type': 'game_state',
          'state': stateJson(
            game: game,
            sequence: 3,
            whiteMs: 43210,
            blackMs: 27890,
          ),
        });
        await tester.pump();
        await tester.pump();
        final status = tester.widget<NeonLiveStatusBar>(
          find.byType(NeonLiveStatusBar),
        );
        expect(status.whiteTime.inMilliseconds, closeTo(43210, 1000));
        expect(status.blackTime.inMilliseconds, 27890);
        expect(status.turn, Side.white);
        _expectOpponent(tester, fixture);
        expect(fixture.channel.sent.where((m) => m['type'] == 'move'), isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  for (final packId in [PiecePackId.anime, PiecePackId.japanese]) {
    testWidgets('both swipe directions change only piece type for $packId', (
      tester,
    ) async {
      final fixture = await _open(
        tester,
        pack: piecePacks.singleWhere((p) => p.id == packId),
      );
      try {
        final fen = fixture.client.state!.fen;
        await _select(tester, Square.e2);
        final targets = _board(tester).legalTargets;
        final style = _board(tester).appearance!.classicStyle;
        for (final (delta, classic) in [
          (const Offset(-100, 0), true),
          (const Offset(100, 0), false),
        ]) {
          await tester.drag(find.byType(ChessBoard), delta);
          await tester.pump();
          expect(_board(tester).appearance!.white.id, packId);
          expect(_board(tester).appearance!.black.id, packId);
          expect(_board(tester).appearance!.board.id, packId);
          expect(_board(tester).appearance!.standardPieces, classic);
          expect(_board(tester).appearance!.classicStyle, style);
          expect(_board(tester).position.fen, fen);
          expect(_board(tester).selected, Square.e2);
          expect(_board(tester).legalTargets, targets);
          _expectOpponent(tester, fixture);
        }
        expect(fixture.channel.sent.where((m) => m['type'] == 'move'), isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, fixture);
      }
    });
  }

  testWidgets('restored hidden armies survive both presentation swipes', (
    tester,
  ) async {
    final fixture = await _open(
      tester,
      appearance: ['japanese', 'roman', 'chola', 'classic', 'magneticTeaching'],
    );
    try {
      final fen = _board(tester).position.fen;
      for (final (delta, classic) in [
        (const Offset(-100, 0), false),
        (const Offset(100, 0), true),
      ]) {
        await tester.drag(find.byType(ChessBoard), delta);
        await tester.pump();
        expect(_board(tester).appearance!.white.id, PiecePackId.japanese);
        expect(_board(tester).appearance!.black.id, PiecePackId.roman);
        expect(_board(tester).appearance!.board.id, PiecePackId.chola);
        expect(_board(tester).appearance!.standardPieces, classic);
        expect(_board(tester).position.fen, fen);
        _expectOpponent(tester, fixture);
      }
      expect(fixture.channel.sent.where((m) => m['type'] == 'move'), isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      await _close(tester, fixture);
    }
  });

  testWidgets(
    'human online threat scan is free and clears selected board targets',
    (tester) async {
      final game = GameSession.fromMoves(moves: ['e2e4', 'd7d5']);
      final fixture = await _open(tester, game: game);
      try {
        await _select(tester, Square.e4);
        final fen = fixture.client.state!.fen;
        final sent = fixture.channel.sent.length;
        await tester.tap(find.byKey(const ValueKey('analyse-threats')));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('online-human-threat-scan')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('use-online-computer-lifeline')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('online-suggestion-credit-cost')),
          findsNothing,
        );
        expect(_board(tester).selected, isNull);
        expect(_board(tester).position.fen, fen);
        expect(fixture.channel.sent.length, sent);
        expect(find.text('Stop scan'), findsOneWidget);
        _expectOpponent(tester, fixture);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  for (final (size, scale) in [
    (const Size(320, 568), 1.0),
    (const Size(650, 360), 2.0),
  ]) {
    testWidgets(
      'computer online quick suggestion stays visible and server-authorized at $size scale $scale',
      (tester) async {
        final fixture = await _open(
          tester,
          size: size,
          textScale: scale,
          blackComputer: true,
        );
        try {
          final button = find.byKey(
            const ValueKey('use-online-computer-lifeline'),
          );
          expect(button.hitTestable(), findsOneWidget);
          expect(
            find.byKey(const ValueKey('analyse-threats')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('online-suggestion-credit-cost')),
            findsOneWidget,
          );
          final fen = fixture.client.state!.fen;
          await tester.tap(button);
          await tester.pump();
          expect(
            fixture.channel.sent
                .where((m) => m['type'] == 'use_lifeline')
                .length,
            1,
          );
          expect(_board(tester).suggestedFrom, isNull);
          expect(_board(tester).position.fen, fen);
          _expectOpponent(tester, fixture);
          expect(tester.takeException(), isNull);
        } finally {
          await _close(tester, fixture);
        }
      },
    );
  }

  for (final (size, computer) in [
    (const Size(320, 568), false),
    (const Size(650, 360), true),
  ]) {
    testWidgets(
      'legacy online board retains opponent panel and quick action authority at $size',
      (tester) async {
        final fixture = await _open(
          tester,
          pack: piecePacks.singleWhere((p) => p.id == PiecePackId.japanese),
          size: size,
          textScale: 1.5,
          blackComputer: computer,
        );
        try {
          _expectOpponent(tester, fixture);
          final board = tester.getRect(find.byType(ChessBoard));
          final actions = tester.getRect(
            find.byKey(const ValueKey('neon-live-quick-actions')),
          );
          if (size.width < size.height) {
            expect(actions.top, greaterThanOrEqualTo(board.bottom));
          }
          expect(actions.bottom, lessThanOrEqualTo(size.height));
          expect(
            find.byKey(const ValueKey('analyse-threats')).hitTestable(),
            findsOneWidget,
          );
          if (computer) {
            final suggestion = find.byKey(
              const ValueKey('use-online-computer-lifeline'),
            );
            expect(suggestion.hitTestable(), findsOneWidget);
            await tester.tap(suggestion);
            await tester.pump();
            expect(
              fixture.channel.sent
                  .where((m) => m['type'] == 'use_lifeline')
                  .length,
              1,
            );
            expect(_board(tester).suggestedFrom, isNull);
          } else {
            expect(
              find.byKey(const ValueKey('use-online-computer-lifeline')),
              findsNothing,
            );
            await tester.tap(find.byKey(const ValueKey('analyse-threats')));
            await tester.pump();
            expect(
              fixture.channel.sent.where((m) => m['type'] == 'use_lifeline'),
              isEmpty,
            );
          }
          expect(tester.takeException(), isNull);
        } finally {
          await _close(tester, fixture);
        }
      },
    );
  }

  testWidgets(
    'landscape opponent-panel swap preserves selection, profile and board commands',
    (tester) async {
      final game = GameSession.fromMoves(moves: ['e2e4', 'd7d5']);
      final fixture = await _open(
        tester,
        game: game,
        size: const Size(650, 360),
      );
      try {
        await _select(tester, Square.e4);
        final targets = _board(tester).legalTargets;
        expect(
          tester.getRect(_opponentPanel).right,
          lessThan(tester.getRect(find.byType(ChessBoard)).left),
        );
        await tester.tap(find.byKey(const ValueKey('neon-live-swap-panels')));
        await tester.pump();
        expect(
          tester.getRect(find.byType(ChessBoard)).right,
          lessThan(tester.getRect(_opponentPanel).left),
        );
        expect(_board(tester).selected, Square.e4);
        expect(_board(tester).legalTargets, targets);
        _expectOpponent(tester, fixture);
        await tester.drag(find.byType(ChessBoard), const Offset(-100, 0));
        await tester.pump();
        expect(_board(tester).appearance!.standardPieces, isTrue);
        expect(_board(tester).selected, Square.e4);
        await _select(tester, Square.d5);
        expect(fixture.channel.sent.last['type'], 'move');
        expect(fixture.channel.sent.last['move'], containsPair('from', 'e4'));
        expect(fixture.channel.sent.last['move'], containsPair('to', 'd5'));
        expect(_board(tester).position.fen, game.position.fen);
        _expectOpponent(tester, fixture);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  testWidgets(
    'new online round defaults to Classic without a popup and uses authoritative clocks',
    (tester) async {
      final fixture = await _open(tester);
      try {
        await tester.tap(
          find.byKey(const ValueKey('online-quick-piece-style-toggle')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await _select(tester, Square.e2);
        fixture.channel.receive({
          'type': 'game_state',
          'state': stateJson(
            sequence: 2,
            round: 2,
            whiteMs: 42100,
            blackMs: 33000,
          ),
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const ValueKey('piece-type-choice')), findsNothing);
        expect(_board(tester).selected, isNull);
        final header = tester.widget<NeonLiveStatusBar>(
          find.byType(NeonLiveStatusBar),
        );
        expect(header.whiteTime.inMilliseconds, closeTo(42100, 1000));
        expect(header.blackTime.inMilliseconds, 33000);
        expect(_board(tester).appearance!.standardPieces, isTrue);
        expect(_board(tester).appearance!.animatedArena, isFalse);
        expect(_board(tester).position.fen, fixture.client.state!.fen);
        expect(fixture.channel.sent.where((m) => m['type'] == 'move'), isEmpty);
        _expectOpponent(tester, fixture);
        await _select(tester, Square.e2);
        expect(_board(tester).selected, Square.e2);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  testWidgets(
    'server completion presents the actual result directly without piece choice',
    (tester) async {
      final fixture = await _open(tester);
      try {
        await fixture.accept(tester, GameSession(), sequence: 2, round: 2);
        expect(find.byKey(const ValueKey('piece-type-choice')), findsNothing);
        fixture.channel.receive({
          'type': 'game_state',
          'state': stateJson(
            sequence: 3,
            round: 2,
            status: 'complete',
            whiteMs: 0,
            result: {'winner': 'b', 'reason': 'timeout'},
          ),
        });
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        for (
          var i = 0;
          i < 30 &&
              find
                  .byKey(const ValueKey('checkmate-heading'))
                  .evaluate()
                  .isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 25));
        }
        expect(fixture.client.state!.status, 'complete');
        expect(find.byKey(const ValueKey('piece-type-choice')), findsNothing);
        expect(find.byKey(const ValueKey('checkmate-heading')), findsOneWidget);
        expect(_board(tester).appearance!.standardPieces, isTrue);
        expect(fixture.client.state!.winner, 'b');
        expect(find.byType(NeonLiveArena), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  testWidgets('rapid new rounds default to Classic and clear stale selection', (
    tester,
  ) async {
    final fixture = await _open(tester);
    try {
      await tester.tap(
        find.byKey(const ValueKey('online-quick-piece-style-toggle')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await fixture.accept(tester, GameSession(), sequence: 2, round: 2);
      await _select(tester, Square.e2);
      expect(_board(tester).selected, Square.e2);
      await fixture.accept(tester, GameSession(), sequence: 3, round: 3);
      await tester.pump(const Duration(milliseconds: 300));
      expect(fixture.client.state!.round, 3);
      expect(_board(tester).selected, isNull);
      expect(_board(tester).appearance!.standardPieces, isTrue);
      expect(_board(tester).appearance!.animatedArena, isFalse);
      expect(find.byKey(const ValueKey('piece-type-choice')), findsNothing);
      _expectOpponent(tester, fixture);
      expect(tester.takeException(), isNull);
    } finally {
      await _close(tester, fixture);
    }
  });

  for (final (size, scale) in [
    (const Size(320, 568), 1.0),
    (const Size(320, 568), 1.5),
    (const Size(650, 360), 1.0),
    (const Size(650, 360), 1.5),
  ]) {
    testWidgets(
      'opponent profile and interactive board fit $size at scale $scale',
      (tester) async {
        final fixture = await _open(tester, size: size, textScale: scale);
        try {
          _expectOpponent(tester, fixture);
          final panel = tester.getRect(_opponentPanel);
          final board = tester.getRect(find.byType(ChessBoard));
          expect(panel.height, greaterThan(0));
          expect(board.width, closeTo(board.height, .1));
          expect(board.height, greaterThan(80));
          if (size.width > size.height) {
            expect(panel.right, lessThanOrEqualTo(board.left));
            expect(
              find.byKey(
                const ValueKey('neon-live-landscape-action-board-row'),
              ),
              findsOneWidget,
            );
          } else {
            expect(panel.bottom, lessThanOrEqualTo(board.top));
          }
          expect(board.left, greaterThanOrEqualTo(0));
          expect(board.right, lessThanOrEqualTo(size.width));
          expect(board.bottom, lessThanOrEqualTo(size.height));
          expect(find.byType(NeonLiveStatusBar), findsOneWidget);
          final balance = tester.getRect(
            find.byKey(const ValueKey('arena-credit-header-balance')),
          );
          final amount = tester.getRect(
            find.byKey(const ValueKey('arena-credit-header-amount')),
          );
          expect(balance.right, lessThanOrEqualTo(size.width));
          expect(amount.left, greaterThanOrEqualTo(balance.left));
          expect(amount.right, lessThanOrEqualTo(balance.right));
          if (size.width < size.height) {
            await tester.ensureVisible(find.byTooltip('Hide top bar'));
            await tester.pump(const Duration(milliseconds: 100));
            expect(
              tester.getRect(
                find.byKey(const ValueKey('arena-credit-header-balance')),
              ),
              balance,
            );
          }
          expect(_board(tester).showCoordinates, isTrue);
          await _select(tester, Square.e2);
          expect(_board(tester).selected, Square.e2);
          expect(_board(tester).legalTargets, contains(Square.e4));
          expect(
            find.byKey(const ValueKey('neon-live-controls-button')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('neon-live-board-button')),
            findsNothing,
          );
          final actions = find.byKey(const ValueKey('neon-live-quick-actions'));
          expect(actions.hitTestable(), findsOneWidget);
          expect(
            find.byKey(const ValueKey('analyse-threats')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('use-online-computer-lifeline')),
            findsNothing,
          );
          final controller = tester
              .widget<NeonLiveGameLayout>(find.byType(NeonLiveGameLayout))
              .scrollController;
          if (size.width < size.height) {
            expect(
              tester.getRect(actions).top,
              greaterThanOrEqualTo(board.bottom),
            );
            expect(
              tester.getRect(actions).bottom,
              lessThanOrEqualTo(size.height),
            );
          }
          final secondaryControl = find.text('Offer draw');
          // Secondary controls may scroll; the prominent opponent stays available
          // above the portrait board and returns with the same identity.
          await tester.scrollUntilVisible(
            secondaryControl,
            120,
            scrollable: find
                .descendant(
                  of: find.byKey(
                    ValueKey(
                      size.width < size.height
                          ? 'portrait-online-match-scroll'
                          : 'landscape-online-match-scroll',
                    ),
                  ),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pump();
          expect(secondaryControl.hitTestable(), findsOneWidget);
          if (size.width < size.height) {
            _expectOpponent(tester, fixture);
            expect(tester.getRect(_opponentPanel), panel);
          } else {
            // Landscape uses one scrolling page; its profile row can be
            // virtualized while the secondary controls are in view.
            expect(controller.offset, greaterThan(0));
          }
          controller.jumpTo(0);
          await tester.pump();
          _expectOpponent(tester, fixture);
          expect(tester.getRect(find.byType(ChessBoard)), board);
          expect(tester.getRect(_opponentPanel), panel);
          expect(_opponentPanel.hitTestable(), findsOneWidget);
          expect(_board(tester).selected, Square.e2);
          expect(tester.takeException(), isNull);
        } finally {
          await _close(tester, fixture);
        }
      },
    );
  }
}
