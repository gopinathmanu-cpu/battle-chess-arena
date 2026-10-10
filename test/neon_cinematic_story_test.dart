import 'package:battle_chess_arena/src/domain/animated_army_theme.dart';
import 'package:battle_chess_arena/src/domain/cinematic_replay.dart';
import 'package:battle_chess_arena/src/domain/neon_cinematic_story.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

CinematicReplay _replay(List<String> moves, {String? result}) =>
    CinematicReplay.fromMoves(moves: moves, resultTitle: result);

void main() {
  for (final theme in AnimatedArmyTheme.values) {
    test('${theme.name} world preserves actual routes, victims and results', () {
      final replay = _replay([
        'e2e4',
        'd7d5',
        'e4d5',
        'd8d5',
        'b1c3',
        'd5d6',
        'g1f3',
        'g8f6',
      ], result: 'Game unfinished');
      final story = NeonCinematicStory(replay, theme: theme);
      final intro = story.intro();
      expect(intro.title, theme.displayName);
      expect(intro.narration, contains("White's ${theme.whiteFaction}"));
      expect(intro.narration, contains("Black's ${theme.blackFaction}"));
      for (var index = 0; index < replay.totalPlies; index++) {
        final scene = replay.scenes[index];
        final narration = story.move(index).narration;
        expect(
          narration,
          contains('${scene.source.name} to ${scene.target.name}'),
        );
        expect(
          narration,
          startsWith(scene.side == Side.white ? 'White' : 'Black'),
        );
        if (scene.resolution.defender case final victim?) {
          final opponent = scene.side == Side.white ? 'Black' : 'White';
          expect(
            narration,
            contains(
              "capturing $opponent's ${victim.role.name} on ${scene.captureSquare!.name}",
            ),
          );
        }
        expect(narration, isNot(contains('guaranteed')));
        expect(narration, isNot(contains('best move')));
      }
      if (theme != AnimatedArmyTheme.neon) {
        expect(story.move(0).narration, contains(theme.whiteFaction));
        expect(story.move(7).narration, contains(theme.blackFaction));
        expect(story.move(1).narration, isNot(contains(theme.blackFaction)));
      }
      final finale = story.finale();
      expect(finale.title, 'Game unfinished');
      expect(finale.narration, contains('Review the moves played so far.'));
      expect(finale.narration, isNot(contains('wins')));
      expect(finale.narration, isNot(contains('fight another day')));
      expect(finale.narration, isNot(contains('preserves')));
      expect(finale.narration, isNot(contains('remembers')));
      expect(finale.narration, isNot(contains('holds this record')));
    });

    test('${theme.name} encourages only the recorded losing perspective', () {
      final replay = _replay([
        'f2f3',
        'e7e5',
        'g2g4',
        'd8h4',
      ], result: 'Black wins by checkmate');
      final losing = NeonCinematicStory(
        replay,
        theme: theme,
        playerSide: Side.white,
      );
      final winning = NeonCinematicStory(
        replay,
        theme: theme,
        playerSide: Side.black,
      );
      expect(
        losing.move(3).narration,
        contains('White has no legal reply; Black wins.'),
      );
      expect(losing.finale().title, replay.resultTitle);
      expect(
        losing.finale().narration,
        contains('Learn from this game and fight another day.'),
      );
      expect(winning.finale().narration, isNot(contains('fight another day')));
      if (theme != AnimatedArmyTheme.neon) {
        expect(
          losing.finale().narration,
          contains('${theme.blackFaction} wins'),
        );
        expect(
          losing.finale().narration,
          isNot(contains('${theme.whiteFaction} wins')),
        );
      }
      final draw = NeonCinematicStory(
        _replay(['e2e4'], result: 'Draw by agreement'),
        theme: theme,
        playerSide: Side.white,
        winnerSide: Side.black,
      ).finale();
      expect(draw.narration, contains('Neither side won.'));
      expect(draw.narration, isNot(contains('fight another day')));
      expect(draw.narration, isNot(contains('wins')));
    });
  }

  test('every actual move uses plain White/Black routes without filler', () {
    final replay = _replay(['e2e4', 'd7d5', 'e4d5', 'd8d5', 'b1c3', 'd5d6']);
    final story = NeonCinematicStory(replay);
    expect(story.intro().title, 'Neon Dominion');
    expect(story.intro().narration, contains('White'));
    expect(story.intro().narration, contains('Black'));
    for (var i = 0; i < replay.totalPlies; i++) {
      final scene = replay.scenes[i];
      final beat = story.move(i);
      expect(beat.title, isNotEmpty);
      expect(
        beat.narration,
        startsWith(scene.side == Side.white ? 'White' : 'Black'),
      );
      expect(
        beat.narration,
        contains('${scene.source.name} to ${scene.target.name}'),
      );
      for (final filler in [
        'rain',
        'footprint',
        'streets',
        'skyline',
        'neon haze',
        'Aurora',
        'Void',
        'brilliant',
        'best move',
        'sacrifice',
        'guaranteed',
      ]) {
        expect(beat.narration, isNot(contains(filler)));
      }
    }
    expect(() => story.move(-1), throwsRangeError);
    expect(() => story.move(replay.totalPlies), throwsRangeError);
  });

  test('quiet commentary and tactical facts are deterministic', () {
    final replay = _replay(['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6']);
    final first = NeonCinematicStory(replay);
    final second = NeonCinematicStory(replay);
    expect(first.move(0).narration, 'White moves its pawn e2 to e4.');
    expect(first.move(1).narration, 'Black moves its pawn e7 to e5.');
    expect(first.move(0).visualDuration, const Duration(milliseconds: 2200));
    for (var i = 0; i < replay.totalPlies; i++) {
      expect(first.move(i).title, second.move(i).title);
      expect(first.move(i).narration, second.move(i).narration);
      expect(first.move(i).visualDuration, second.move(i).visualDuration);
    }
    expect(first.finale().narration, second.finale().narration);
  });

  test('capture identifies actual victim and legal recapture risk', () {
    final story = NeonCinematicStory(_replay(['e2e4', 'd7d5', 'e4d5', 'd8d5']));
    final whiteCapture = story.move(2);
    expect(whiteCapture.title, 'White captures a pawn');
    expect(
      whiteCapture.narration,
      contains("White's pawn moves e4 to d5, capturing Black's pawn on d5."),
    );
    expect(
      whiteCapture.narration,
      contains("Black can reply by capturing White's pawn on d5."),
    );
    expect(whiteCapture.narration, isNot(contains('White threatens')));
    expect(whiteCapture.visualDuration, const Duration(seconds: 4));
    expect(
      story.move(3).narration,
      contains("Black's queen moves d8 to d5, capturing White's pawn on d5."),
    );
  });

  test('new opponent threats include discovered attacks from other pieces', () {
    final story = NeonCinematicStory(
      _replay(['b1c3', 'c7c6', 'g1f3', 'd8a5', 'a2a3', 'a5a6', 'e2e3']),
    );
    final beat = story.move(6);
    expect(beat.narration, startsWith('White moves its pawn e2 to e3.'));
    expect(beat.narration, contains("White threatens Black's queen on a6."));
    expect(beat.narration, isNot(contains('fork')));
  });

  test('pinned knight and forward-facing pawns produce no invented reply', () {
    final story = NeonCinematicStory(
      _replay(['e2e4', 'b8c6', 'f1b5', 'd7d5', 'e4e5']),
    );
    final beat = story.move(4);
    expect(beat.narration, contains("White threatens Black's knight on c6."));
    expect(beat.narration, isNot(contains('Black can reply')));
    expect(beat.narration, isNot(contains('fork')));
    expect(
      NeonCinematicStory(_replay(['e2e4', 'e7e5'])).move(1).narration,
      'Black moves its pawn e7 to e5.',
    );
  });

  test('a new knight fork names only actual legal targets', () {
    final replay = _replay([
      'e2e4',
      'e7e5',
      'g1f3',
      'b8c6',
      'f1c4',
      'g8f6',
      'f3g5',
      'f8c5',
      'g5f7',
    ]);
    final beat = NeonCinematicStory(replay).move(8);
    expect(beat.title, 'White creates a knight fork');
    expect(
      beat.narration,
      contains(
        "White's knight on f7 forks Black's queen on d8 and rook on h8.",
      ),
    );
    expect(
      beat.narration,
      contains("White also threatens Black's pawn on e5."),
    );
    expect(beat.narration, isNot(contains('wins material')));
    expect(beat.narration, isNot(contains('forced')));
  });

  test('long threat lists name at most three victims plus a remaining count', () {
    final story = NeonCinematicStory(_replay(['e2e4', 'e7e5', 'a2a3', 'd8h4']));
    final beat = story.move(3);
    expect(
      beat.narration,
      contains(
        "Black threatens White's pawn on a3, pawn on e4, pawn on f2 and 1 more piece.",
      ),
    );
    expect(beat.narration, isNot(contains('pawn on h2')));
    expect(beat.narration, isNot(contains('fork')));
  });

  test('castling gives actual king and rook routes for both wings and sides', () {
    final kingside = NeonCinematicStory(
      _replay(['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6', 'e1h1']),
    );
    expect(
      kingside.move(6).narration,
      contains(
        'White castles kingside. The king moves e1 to g1; the rook moves h1 to f1.',
      ),
    );
    final queenside = NeonCinematicStory(
      _replay([
        'e2e4',
        'e7e5',
        'd2d4',
        'd7d5',
        'b1c3',
        'b8c6',
        'c1e3',
        'c8e6',
        'd1d2',
        'd8d7',
        'e1c1',
        'e8c8',
      ]),
    );
    expect(
      queenside.move(10).narration,
      contains(
        'White castles queenside. The king moves e1 to c1; the rook moves a1 to d1.',
      ),
    );
    expect(
      queenside.move(11).narration,
      contains(
        'Black castles queenside. The king moves e8 to c8; the rook moves a8 to d8.',
      ),
    );
  });

  test('en passant describes off-target victim and real next-turn reply', () {
    final story = NeonCinematicStory(
      _replay(['e2e4', 'h7h6', 'e4e5', 'd7d5', 'e5d6']),
    );
    expect(story.move(3).narration, contains("pawn on d5 en passant."));
    final beat = story.move(4);
    expect(beat.narration, contains('e5 to d6'));
    expect(beat.narration, contains("En passant captures Black's pawn on d5."));
    expect(beat.narration, isNot(contains('captures Black\'s pawn on d6')));
    expect(
      beat.narration,
      contains("White threatens Black's pawn on c7 and pawn on e7."),
    );
  });

  test('promotion names chosen role, captured rook and measured material', () {
    for (final entry in {
      'q': 'queen',
      'r': 'rook',
      'b': 'bishop',
      'n': 'knight',
    }.entries) {
      final replay = _replay([
        'a2a4',
        'h7h5',
        'a4a5',
        'h5h4',
        'a5a6',
        'h4h3',
        'a6b7',
        'h3g2',
        'b7a8${entry.key}',
      ]);
      final beat = NeonCinematicStory(replay).move(8);
      expect(beat.narration, contains('b7 to a8'));
      expect(beat.narration, contains("capturing Black's rook on a8"));
      expect(beat.narration, contains('promotes to a ${entry.value}'));
      expect(beat.visualDuration, const Duration(seconds: 5));
      expect(beat.narration, isNot(contains('safe')));
      if (entry.key == 'q') {
        expect(
          beat.narration,
          contains('White now leads by 13 points in material.'),
        );
      }
    }
  });

  test('check calls for a response without announcing a win', () {
    final beat = NeonCinematicStory(_replay(['e2e4', 'f7f6', 'd1h5'])).move(2);
    expect(beat.title, 'White gives check');
    expect(beat.narration, contains('Check. Black must respond.'));
    expect(beat.narration, isNot(contains('Checkmate')));
    expect(beat.narration, isNot(contains('wins')));
    expect(beat.visualDuration, const Duration(seconds: 5));
  });

  test('real mate ends legal replies without claiming a captured king', () {
    final replay = _replay(['f2f3', 'e7e5', 'g2g4', 'd8h4']);
    final story = NeonCinematicStory(replay);
    final beat = story.move(3);
    expect(beat.title, 'Black wins by checkmate');
    expect(
      beat.narration,
      contains('Checkmate. White has no legal reply; Black wins.'),
    );
    expect(beat.narration, isNot(contains('captur')));
    expect(beat.narration, isNot(contains('can reply')));
    expect(beat.visualDuration, const Duration(seconds: 6));
    expect(story.finale().title, 'Black wins by checkmate');
  });

  test(
    'losing player receives encouragement only for a verified opponent win',
    () {
      final mate = _replay(['f2f3', 'e7e5', 'g2g4', 'd8h4']);
      final lost = NeonCinematicStory(mate, playerSide: Side.white).finale();
      expect(lost.title, 'Black wins by checkmate');
      expect(
        lost.narration,
        contains('Learn from this game and fight another day.'),
      );
      expect(
        NeonCinematicStory(mate, playerSide: Side.black).finale().narration,
        isNot(contains('fight another day')),
      );
      expect(
        NeonCinematicStory(mate).finale().narration,
        isNot(contains('fight another day')),
      );
      for (final result in [
        'Computer Wins · Timeout',
        'Captain Orion wins · Resignation',
      ]) {
        final replay = _replay(['e2e4'], result: result);
        expect(
          NeonCinematicStory(
            replay,
            playerSide: Side.white,
            winnerSide: Side.black,
          ).finale().narration,
          contains('fight another day'),
        );
        expect(
          NeonCinematicStory(replay, playerSide: Side.white).finale().narration,
          isNot(contains('fight another day')),
        );
      }
    },
  );

  test(
    'clock and resignation endings retain actual reason without fabricated mate',
    () {
      for (final result in [
        'White wins on time',
        'Black wins by resignation',
      ]) {
        final finale = NeonCinematicStory(
          _replay(['e2e4', 'e7e5', 'g1f3'], result: result),
        ).finale();
        expect(finale.title, result);
        expect(finale.narration, startsWith('$result.'));
        expect(finale.narration.toLowerCase(), isNot(contains('checkmate')));
        expect(
          finale.narration,
          contains(
            result.contains('time') ? 'clock decided' : 'ended by resignation',
          ),
        );
      }
    },
  );

  test(
    'draw unfinished cancel and abort override supplied winner and mate',
    () {
      for (final result in [
        'Draw by agreement',
        'Game drawn',
        'Game unfinished',
        'Game incomplete',
        'Game cancelled',
        'Game aborted',
      ]) {
        final replay = _replay([
          'f2f3',
          'e7e5',
          'g2g4',
          'd8h4',
        ], result: result);
        final finale = NeonCinematicStory(
          replay,
          playerSide: Side.white,
          winnerSide: Side.black,
        ).finale();
        expect(finale.title, result);
        expect(finale.narration, startsWith('$result.'));
        expect(finale.narration, isNot(contains('fight another day')));
        expect(finale.narration.toLowerCase(), isNot(contains('checkmate')));
        expect(finale.narration, isNot(contains('no legal response')));
        if (result.toLowerCase().contains('draw')) {
          expect(finale.narration, contains('Neither side won.'));
        }
      }
    },
  );

  test('empty and neutral results do not invent winner or player loss', () {
    final story = NeonCinematicStory(
      _replay([], result: 'Game cancelled'),
      playerSide: Side.white,
    );
    expect(story.finale().narration, contains('No moves were played.'));
    expect(() => story.move(0), throwsRangeError);
    final neutral = NeonCinematicStory(
      _replay(['e2e4', 'e7e5']),
      playerSide: Side.white,
    ).finale();
    expect(neutral.narration, isNot(contains('fight another day')));
    expect(neutral.narration.toLowerCase(), isNot(contains('checkmate')));
  });
}
