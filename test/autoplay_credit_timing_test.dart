// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/game_time_control.dart';
import 'package:battle_chess_arena/src/domain/online_credits.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/capture_battle_overlay.dart';
import 'package:battle_chess_arena/src/features/play/checkmate_animation.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_arena.dart';
import 'package:battle_chess_arena/src/services/arena_credit_controller.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/game_history_storage.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/autoplay.dart';

class _Search {
  _Search(this.fen, this.difficulty, this.botLevel);
  final String fen;
  final ComputerDifficulty difficulty;
  final int? botLevel;
  final reply = Completer<String?>();
}

class _Engine implements ComputerPlayer {
  final requests = <_Search>[];
  @override
  Future<String?> bestMove(
    String fen, {
    ComputerDifficulty difficulty = ComputerDifficulty.medium,
    int? botLevel,
  }) {
    final search = _Search(fen, difficulty, botLevel);
    requests.add(search);
    return search.reply.future;
  }

  @override
  void dispose() {}
}

class _Fixture {
  _Fixture(this.engine, this.wallet);
  final _Engine engine;
  final ArenaCreditController wallet;
}

Finder _key(String key) => find.byKey(ValueKey(key));
ChessBoard _board(WidgetTester tester) =>
    tester.widget<ChessBoard>(find.byType(ChessBoard).first);
List<OnlineCreditTransaction> _autoFees(_Fixture fixture) => fixture
    .wallet
    .account!
    .recentTransactions
    .where((transaction) => transaction.reason == 'auto_play_move')
    .toList();

SavedGame _saved(
  List<String> moves, {
  Side humanSide = Side.white,
  PiecePackId pack = PiecePackId.anime,
  bool fastBattles = false,
}) => SavedGame(
  mode: PlayerMode.computer,
  humanSide: humanSide,
  homePack: pack,
  difficulty: ComputerDifficulty.easy,
  moves: moves,
  whiteMilliseconds: 600000,
  blackMilliseconds: 600000,
  fastBattles: fastBattles,
  whitePack: pack,
  blackPack: pack,
  boardPack: pack,
  updatedAtEpochMs: 1,
  timeControl: GameTimeControl.practice,
);

Future<_Fixture> _open(
  WidgetTester tester, {
  int credits = 5,
  PiecePackId pack = PiecePackId.anime,
  SavedGame? savedGame,
  Size size = const Size(1200, 1000),
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final engine = _Engine();
  final wallet = ArenaCreditController()
    ..acceptServerAccount(
      profileToken: 'autoplay-test-profile',
      account: OnlineCreditAccount.balanceOnly(credits),
      policy: defaultOnlineCreditPolicy,
    );
  await tester.pumpWidget(
    ArenaCreditScope(
      controller: wallet,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: AnimationLabScreen(
          pack: piecePacks.singleWhere((p) => p.id == pack),
          mode: PlayerMode.computer,
          difficulty: ComputerDifficulty.easy,
          timeControl: GameTimeControl.practice,
          savedGame: savedGame,
          computerPlayer: engine,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  return _Fixture(engine, wallet);
}

Future<void> _close(WidgetTester tester, _Fixture fixture) async {
  await tester.pumpWidget(const SizedBox());
  for (final request in fixture.engine.requests) {
    if (!request.reply.isCompleted) request.reply.complete(null);
  }
  await tester.pump(const Duration(seconds: 3));
  var historyDone = false;
  Object? failure;
  GameHistoryStorage().loadSnapshot().then(
    (_) => historyDone = true,
    onError: (Object error) {
      failure = error;
      historyDone = true;
    },
  );
  for (var frame = 0; !historyDone && frame < 30; frame++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(historyDone, isTrue);
  expect(failure, isNull);
  await tester.pump();
  fixture.wallet.dispose();
  expect(tester.takeException(), isNull);
}

Future<void> _toggle(WidgetTester tester) => toggleAutoPlay(tester);

Future<void> _startAutomaticSearch(
  WidgetTester tester,
  _Fixture fixture,
) async {
  await _toggle(tester);
  await tester.pump(const Duration(microseconds: 2000001));
  expect(fixture.engine.requests, hasLength(1));
}

Future<void> _answer(
  WidgetTester tester,
  _Fixture fixture,
  String move, {
  int index = 0,
}) async {
  fixture.engine.requests[index].reply.complete(move);
  await tester.pump();
  await tester.pump();
}

Future<void> _blinkPhase(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(microseconds: 1200001));
}

Future<void> _manualMove(WidgetTester tester, String move) async {
  await tester.ensureVisible(_key('square-${move.substring(0, 2)}'));
  await tester.tap(_key('square-${move.substring(0, 2)}'));
  await tester.pump();
  await tester.tap(_key('square-${move.substring(2, 4)}'));
  await tester.pump();
}

void main() {
  testWidgets(
    'autoplay confirmation explains free play and cancellation leaves the game unchanged',
    (tester) async {
      final fixture = await _open(tester);
      try {
        final fen = _board(tester).position.fen;
        await tester.tap(_key('auto-play-toggle'));
        await tester.pump();
        expect(_key('auto-play-confirmation'), findsOneWidget);
        expect(find.textContaining('Auto-play is free'), findsOneWidget);
        await tester.pump(const Duration(seconds: 10));
        expect(fixture.engine.requests, isEmpty);
        expect(fixture.wallet.credits, 5);
        expect(_board(tester).position.fen, fen);
        await tester.tap(_key('cancel-auto-play'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        expect(_key('auto-play-confirmation'), findsNothing);
        expect(fixture.engine.requests, isEmpty);
        expect(_autoFees(fixture), isEmpty);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  testWidgets('every autoplay enable asks again while stopping is immediate', (
    tester,
  ) async {
    final fixture = await _open(tester);
    try {
      await _toggle(tester);
      expect(find.byTooltip('Stop auto-play'), findsOneWidget);
      await tester.tap(_key('auto-play-toggle'));
      await tester.pump();
      expect(_key('auto-play-confirmation'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      expect(fixture.engine.requests, isEmpty);
      await tester.tap(_key('auto-play-toggle'));
      await tester.pump();
      expect(_key('auto-play-confirmation'), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(_key('auto-play-confirmation'), findsNothing);
      expect(fixture.engine.requests, isEmpty);
      expect(fixture.wallet.credits, 5);
      await _startAutomaticSearch(tester, fixture);
      expect(fixture.engine.requests, hasLength(1));
      expect(_autoFees(fixture), isEmpty);
    } finally {
      await _close(tester, fixture);
    }
  });

  for (final pack in [PiecePackId.futuristic, PiecePackId.greek]) {
    for (final size in [const Size(320, 568), const Size(740, 360)]) {
      testWidgets(
        'quick assists remain visible for $pack at $size and 2x text',
        (tester) async {
          final fixture = await _open(
            tester,
            pack: pack,
            size: size,
            textScale: 2,
          );
          try {
            final suggest = _key('use-computer-lifeline');
            final scan = _key('analyse-threats');
            expect(suggest.hitTestable(), findsOneWidget);
            expect(scan.hitTestable(), findsOneWidget);
            final board = tester.getRect(find.byType(ChessBoard));
            expect(board.bottom, lessThanOrEqualTo(size.height));
            expect(board.top, greaterThanOrEqualTo(0));
            if (size.height > size.width) {
              expect(tester.getTopLeft(suggest).dy, greaterThan(board.bottom));
            } else if (pack == PiecePackId.futuristic) {
              final arena = tester.getRect(find.byType(NeonLiveArena));
              expect(tester.getTopLeft(suggest).dy, greaterThan(arena.bottom));
              await tester.tap(_key('neon-live-swap-panels'));
              await tester.pump();
              expect(
                tester.getCenter(find.byType(ChessBoard)).dx,
                lessThan(tester.getCenter(find.byType(NeonLiveArena)).dx),
              );
              expect(suggest.hitTestable(), findsOneWidget);
              expect(scan.hitTestable(), findsOneWidget);
            }
            final counter = _key('arena-credit-header-balance');
            final counterRect = tester.getRect(counter);
            expect(counterRect.right, lessThanOrEqualTo(size.width));
            expect(counterRect.left, greaterThanOrEqualTo(0));
            expect(
              tester.getRect(_key('arena-credit-header-amount')).right,
              lessThanOrEqualTo(counterRect.right),
            );
            await _toggle(tester);
            expect(tester.getRect(counter), counterRect);
            await _toggle(tester);
            expect(tester.getRect(counter), counterRect);
            expect(tester.takeException(), isNull);
          } finally {
            await _close(tester, fixture);
          }
        },
      );
    }
  }
  testWidgets('automatic, opponent and manual moves all stay free', (
    tester,
  ) async {
    final fixture = await _open(tester);
    try {
      await _startAutomaticSearch(tester, fixture);
      expect(fixture.wallet.credits, 5);
      expect(fixture.engine.requests.single.difficulty, assistanceDifficulty);
      expect(fixture.engine.requests.single.botLevel, assistanceBotLevel);
      await _answer(tester, fixture, 'e2e4');
      expect(_board(tester).previewFrom, Square.e2);
      expect(fixture.wallet.credits, 5);
      await _blinkPhase(tester);
      expect(_board(tester).position.board.pieceAt(Square.e4), Piece.whitePawn);
      expect(fixture.wallet.credits, 5);
      expect(_autoFees(fixture), isEmpty);
      await _toggle(tester);
      await _blinkPhase(tester);
      await tester.pump(const Duration(milliseconds: 1999));
      expect(fixture.engine.requests, hasLength(1));
      await tester.pump(const Duration(milliseconds: 2));
      expect(fixture.engine.requests, hasLength(2));
      expect(fixture.engine.requests.last.difficulty, ComputerDifficulty.easy);
      expect(fixture.engine.requests.last.botLevel, isNull);
      await _answer(tester, fixture, 'e7e5', index: 1);
      await _blinkPhase(tester);
      await _blinkPhase(tester);
      expect(fixture.wallet.credits, 5);
      expect(_autoFees(fixture), isEmpty);
      await _manualMove(tester, 'g1f3');
      expect(
        _board(tester).position.board.pieceAt(Square.f3),
        Piece.whiteKnight,
      );
      expect(fixture.wallet.credits, 5);
      expect(_autoFees(fixture), isEmpty);
      expect(fixture.wallet.account!.lifetimeSpent, 0);
    } finally {
      await _close(tester, fixture);
    }
  });

  for (final side in Side.values) {
    testWidgets('sustained $side autoplay keeps all moves free', (
      tester,
    ) async {
      final fixture = await _open(
        tester,
        savedGame: side == Side.black
            ? _saved(['e2e4'], humanSide: side)
            : null,
      );
      try {
        final moves = side == Side.white
            ? ['e2e4', 'e7e5', 'g1f3']
            : ['e7e5', 'g1f3', 'b8c6'];
        await _toggle(tester);
        for (var index = 0; index < moves.length; index++) {
          await tester.pump(const Duration(microseconds: 2000001));
          expect(fixture.engine.requests, hasLength(index + 1));
          final request = fixture.engine.requests[index];
          expect(
            request.difficulty,
            index.isEven ? assistanceDifficulty : ComputerDifficulty.easy,
          );
          expect(request.botLevel, index.isEven ? assistanceBotLevel : null);
          await _answer(tester, fixture, moves[index], index: index);
          await _blinkPhase(tester);
          expect(fixture.wallet.credits, 5);
          expect(_autoFees(fixture), isEmpty);
          expect(
            _board(tester).position.board
                .pieceAt(Square.fromName(moves[index].substring(2, 4)))!
                .color,
            index.isEven ? side : side.opposite,
          );
          await _blinkPhase(tester);
        }
        await _toggle(tester);
        expect(fixture.wallet.account!.lifetimeSpent, 0);
        expect(_autoFees(fixture).every((fee) => fee.delta == -1), isTrue);
      } finally {
        await _close(tester, fixture);
      }
    });
  }

  testWidgets('zero credits allow autoplay to complete a user move', (
    tester,
  ) async {
    final fixture = await _open(tester, credits: 0);
    try {
      await _startAutomaticSearch(tester, fixture);
      await _answer(tester, fixture, 'e2e4');
      await _blinkPhase(tester);
      expect(_board(tester).position.board.pieceAt(Square.e4), Piece.whitePawn);
      expect(fixture.wallet.credits, 0);
      expect(_autoFees(fixture), isEmpty);
      expect(find.byTooltip('Stop auto-play'), findsOneWidget);
      await _toggle(tester);
    } finally {
      await _close(tester, fixture);
    }
  });

  testWidgets(
    'credit depletion during preview does not interrupt a free automatic move',
    (tester) async {
      final fixture = await _open(tester, credits: 1);
      try {
        await _startAutomaticSearch(tester, fixture);
        await _answer(tester, fixture, 'e2e4');
        expect(_board(tester).previewFrom, Square.e2);
        expect(
          fixture.wallet.trySpendLocal(cost: 1, reason: 'move_suggestion'),
          isTrue,
        );
        await _blinkPhase(tester);
        expect(
          _board(tester).position.board.pieceAt(Square.e4),
          Piece.whitePawn,
        );
        expect(_board(tester).previewFrom, Square.e2);
        expect(_board(tester).lastMoveFrom, Square.e2);
        expect(_autoFees(fixture), isEmpty);
        expect(find.byTooltip('Stop auto-play'), findsOneWidget);
        await _toggle(tester);
        expect(fixture.engine.requests, hasLength(1));
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  for (final cancellation in ['engine request', 'source preview']) {
    testWidgets(
      'stopping during $cancellation discards the move without charge',
      (tester) async {
        final fixture = await _open(tester);
        try {
          final fen = _board(tester).position.fen;
          await _startAutomaticSearch(tester, fixture);
          if (cancellation == 'source preview') {
            await _answer(tester, fixture, 'e2e4');
            await tester.pump(const Duration(milliseconds: 400));
          }
          await _toggle(tester);
          if (cancellation == 'engine request') {
            await _answer(tester, fixture, 'e2e4');
          }
          await tester.pump(const Duration(seconds: 5));
          expect(_board(tester).position.fen, fen);
          expect(_board(tester).previewFrom, isNull);
          expect(fixture.wallet.credits, 5);
          expect(_autoFees(fixture), isEmpty);
          expect(fixture.engine.requests, hasLength(1));
        } finally {
          await _close(tester, fixture);
        }
      },
    );
  }

  for (final failure in ['no move', 'illegal move', 'engine error']) {
    testWidgets('$failure from automatic search never spends credits', (
      tester,
    ) async {
      final fixture = await _open(tester);
      try {
        final fen = _board(tester).position.fen;
        await _startAutomaticSearch(tester, fixture);
        final reply = fixture.engine.requests.single.reply;
        if (failure == 'engine error') {
          reply.completeError(StateError('Unavailable test engine'));
        } else {
          reply.complete(failure == 'no move' ? null : 'e2e5');
        }
        await tester.pump();
        await _blinkPhase(tester);
        expect(_board(tester).position.fen, fen);
        expect(fixture.wallet.credits, 5);
        expect(_autoFees(fixture), isEmpty);
        expect(find.byType(CaptureBattleOverlay), findsNothing);
      } finally {
        await _close(tester, fixture);
      }
    });
  }

  testWidgets('late engine completion after screen disposal cannot charge', (
    tester,
  ) async {
    final fixture = await _open(tester);
    try {
      await _startAutomaticSearch(tester, fixture);
      await tester.pumpWidget(const SizedBox());
      await _answer(tester, fixture, 'e2e4');
      await tester.pump(const Duration(seconds: 3));
      expect(fixture.wallet.credits, 5);
      expect(_autoFees(fixture), isEmpty);
    } finally {
      await _close(tester, fixture);
    }
  });

  testWidgets(
    'move suggestions use maximum assistance and only suggestion fee',
    (tester) async {
      final fixture = await _open(tester);
      try {
        final fen = _board(tester).position.fen;
        final hint = _key('use-computer-lifeline');
        await tester.ensureVisible(hint);
        await tester.tap(hint);
        await tester.pump();
        final request = fixture.engine.requests.single;
        expect(request.difficulty, assistanceDifficulty);
        expect(request.botLevel, assistanceBotLevel);
        expect(fixture.wallet.credits, 5);
        await _answer(tester, fixture, 'e2e4');
        expect(_board(tester).position.fen, fen);
        expect(_board(tester).suggestedFrom, Square.e2);
        expect(_board(tester).suggestedTo, Square.e4);
        expect(fixture.wallet.credits, 4);
        expect(fixture.wallet.lastChange!.reason, 'move_suggestion');
        expect(_autoFees(fixture), isEmpty);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  for (final (pack, animation) in [
    (PiecePackId.japanese, Duration.zero),
    (PiecePackId.anime, const Duration(milliseconds: 850)),
    (PiecePackId.indianEpic, const Duration(milliseconds: 850)),
    (PiecePackId.greek, const Duration(milliseconds: 850)),
    (PiecePackId.futuristic, const Duration(milliseconds: 850)),
  ]) {
    testWidgets(
      '$pack manual quiet move waits two seconds after its animation',
      (tester) async {
        final fixture = await _open(tester, pack: pack);
        try {
          await _manualMove(tester, 'e2e4');
          expect(
            _board(tester).position.board.pieceAt(Square.e4),
            Piece.whitePawn,
          );
          expect(fixture.engine.requests, isEmpty);
          await tester.pump(animation);
          await tester.pump(const Duration(milliseconds: 1999));
          expect(fixture.engine.requests, isEmpty);
          await tester.pump(const Duration(milliseconds: 2));
          expect(fixture.engine.requests, hasLength(1));
          expect(
            fixture.engine.requests.single.difficulty,
            ComputerDifficulty.easy,
          );
          expect(fixture.wallet.credits, 5);
          expect(_autoFees(fixture), isEmpty);
        } finally {
          await _close(tester, fixture);
        }
      },
    );
  }

  testWidgets(
    'manual capture holds reply gap until the capture animation ends',
    (tester) async {
      final fixture = await _open(tester, savedGame: _saved(['e2e4', 'd7d5']));
      try {
        await _manualMove(tester, 'e4d5');
        expect(find.byType(CaptureBattleOverlay), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1599));
        expect(find.byType(CaptureBattleOverlay), findsOneWidget);
        expect(fixture.engine.requests, isEmpty);
        await tester.pump(const Duration(milliseconds: 1));
        expect(find.byType(CaptureBattleOverlay), findsNothing);
        await tester.pump(const Duration(milliseconds: 1999));
        expect(fixture.engine.requests, isEmpty);
        await tester.pump(const Duration(milliseconds: 2));
        expect(fixture.engine.requests, hasLength(1));
        expect(fixture.wallet.credits, 5);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  testWidgets(
    'automatic capture is free at landing and waits after target animation',
    (tester) async {
      final fixture = await _open(tester, savedGame: _saved(['e2e4', 'd7d5']));
      try {
        await _startAutomaticSearch(tester, fixture);
        await _answer(tester, fixture, 'e4d5');
        await _blinkPhase(tester);
        expect(find.byType(CaptureBattleOverlay), findsOneWidget);
        expect(fixture.wallet.credits, 5);
        expect(_autoFees(fixture), isEmpty);
        await tester.pump(const Duration(milliseconds: 1600));
        expect(find.byType(CaptureBattleOverlay), findsNothing);
        expect(_board(tester).blinkingSquare, Square.d5);
        await _blinkPhase(tester);
        await tester.pump(const Duration(milliseconds: 1999));
        expect(fixture.engine.requests, hasLength(1));
        await tester.pump(const Duration(milliseconds: 2));
        expect(fixture.engine.requests, hasLength(2));
        expect(fixture.wallet.credits, 5);
        expect(_autoFees(fixture), isEmpty);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  testWidgets(
    'quiet Neon mate finishes action and mate film before result controls',
    (tester) async {
      final fixture = await _open(
        tester,
        pack: PiecePackId.futuristic,
        savedGame: _saved(
          ['f2f3', 'e7e5', 'g2g4'],
          humanSide: Side.black,
          pack: PiecePackId.futuristic,
        ),
      );
      try {
        await _manualMove(tester, 'd8h4');
        expect(_board(tester).position.isCheckmate, isTrue);
        expect(find.byType(CheckmateAnimation), findsNothing);
        expect(_key('result-atmosphere'), findsNothing);
        await tester.pump(const Duration(milliseconds: 849));
        expect(find.byType(CheckmateAnimation), findsNothing);
        expect(_key('result-atmosphere'), findsNothing);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(find.byType(CheckmateAnimation), findsOneWidget);
        expect(
          tester
              .widget<CheckmateAnimation>(find.byType(CheckmateAnimation))
              .winner,
          Side.black,
        );
        expect(_key('result-atmosphere'), findsNothing);
        await tester.pump();
        await tester.pump(
          checkmateAnimationDuration - const Duration(milliseconds: 1),
        );
        expect(find.byType(CheckmateAnimation), findsOneWidget);
        expect(_key('result-atmosphere'), findsNothing);
        await tester.pump(const Duration(milliseconds: 2));
        await tester.pump();
        await tester.pump();
        expect(find.byType(CheckmateAnimation), findsNothing);
        expect(_key('result-atmosphere'), findsOneWidget);
        expect(fixture.engine.requests, isEmpty);
        expect(fixture.wallet.credits, 5);
      } finally {
        await _close(tester, fixture);
      }
    },
  );

  for (final skip in [false, true]) {
    testWidgets(
      '${skip ? 'skipped' : 'fast'} capture still finishes Neon action before the reply gap',
      (tester) async {
        final fixture = await _open(
          tester,
          pack: PiecePackId.futuristic,
          savedGame: _saved(
            ['e2e4', 'd7d5'],
            pack: PiecePackId.futuristic,
            fastBattles: !skip,
          ),
        );
        try {
          await _manualMove(tester, 'e4d5');
          expect(find.byType(CaptureBattleOverlay), findsOneWidget);
          if (skip) {
            await tester.pump(const Duration(milliseconds: 100));
            await tester.tap(find.text('Skip'));
            await tester.pump();
          } else {
            await tester.pump(const Duration(milliseconds: 799));
            expect(find.byType(CaptureBattleOverlay), findsOneWidget);
            await tester.pump(const Duration(milliseconds: 1));
          }
          expect(find.byType(CaptureBattleOverlay), findsNothing);
          expect(fixture.engine.requests, isEmpty);
          final elapsed = Duration(milliseconds: skip ? 100 : 800);
          await tester.pump(
            neonLiveMoveAnimationDuration -
                elapsed -
                const Duration(milliseconds: 1),
          );
          expect(fixture.engine.requests, isEmpty);
          await tester.pump(const Duration(milliseconds: 1));
          await tester.pump(const Duration(milliseconds: 1999));
          expect(fixture.engine.requests, isEmpty);
          await tester.pump(const Duration(milliseconds: 2));
          expect(fixture.engine.requests, hasLength(1));
          expect(fixture.wallet.credits, 5);
          expect(_autoFees(fixture), isEmpty);
        } finally {
          await _close(tester, fixture);
        }
      },
    );
  }

  testWidgets(
    'backgrounding a manual reply restarts a full two-second gap on return',
    (tester) async {
      final fixture = await _open(tester);
      try {
        await _manualMove(tester, 'e2e4');
        await tester.pump(const Duration(seconds: 1));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump(const Duration(seconds: 5));
        expect(fixture.engine.requests, isEmpty);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1999));
        expect(fixture.engine.requests, isEmpty);
        await tester.pump(const Duration(milliseconds: 2));
        expect(fixture.engine.requests, hasLength(1));
        expect(fixture.wallet.credits, 5);
      } finally {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await _close(tester, fixture);
      }
    },
  );
}
