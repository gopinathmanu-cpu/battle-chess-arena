import 'package:battle_chess_arena/src/domain/animated_army_theme.dart';
import 'package:battle_chess_arena/src/domain/neon_live_action.dart';
import 'package:battle_chess_arena/src/domain/piece_selection_commentary.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> replies(
  Position position,
  Square source, {
  AnimatedArmyTheme theme = AnimatedArmyTheme.neon,
}) => pieceSelectionCommentary(
  position: position,
  action: NeonLiveAction.selection(position: position, source: source)!,
  theme: theme,
);

void main() {
  test('all roles have short varied replies and army-specific voice', () {
    final board = Chess.fromSetup(
      Setup.parseFen('4k3/8/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1'),
    );
    for (final theme in AnimatedArmyTheme.values) {
      for (final source in [
        Square.a2,
        Square.b1,
        Square.c1,
        Square.a1,
        Square.d1,
        Square.e1,
      ]) {
        final lines = replies(board, source, theme: theme);
        expect(lines.length, greaterThanOrEqualTo(2));
        expect(lines.toSet().length, lines.length);
        expect(lines.every((line) => line.length <= 60), isTrue);
        expect(
          lines.any((line) => line.contains('Aurora') || line.contains('Void')),
          isFalse,
        );
      }
    }
    expect(replies(Chess.initial, Square.g1), contains('Ready for the leap.'));
    expect(replies(Chess.initial, Square.e2), contains('One step at a time.'));
    expect(
      replies(Chess.initial, Square.g1),
      contains('Systems ready, commander.'),
    );
    expect(
      replies(Chess.initial, Square.g1, theme: AnimatedArmyTheme.olympian),
      contains('The legion awaits your command.'),
    );
  });

  test('check responses describe actual legal escapes or cover', () {
    final board = Chess.fromSetup(
      Setup.parseFen('1k2r3/8/8/8/8/8/R7/4K3 w - - 0 1'),
    );
    expect(board.isCheck, isTrue);
    expect(replies(board, Square.e1), contains('Guide me to safety.'));
    expect(replies(board, Square.a2), contains('Our king needs cover.'));
    expect(replies(board, Square.a2).join(' '), isNot(contains('win')));
  });

  test('a pinned piece cannot claim an illegal capture', () {
    final board = Chess.fromSetup(
      Setup.parseFen('k3r3/8/8/8/8/3p4/4B3/4K3 w - - 0 1'),
    );
    expect(board.legalMovesOf(Square.e2).isEmpty, isTrue);
    expect(replies(board, Square.e2), contains('I have no legal move yet.'));
    expect(replies(board, Square.e2).join(' '), isNot(contains('D3')));
  });

  test('capture comments identify the most valuable legal victim', () {
    final board = Chess.fromSetup(
      Setup.parseFen('4k3/8/8/3q4/3R1p2/8/8/4K3 w - - 0 1'),
    );
    expect(replies(board, Square.d4), contains('I can take the queen on D5.'));
    expect(
      replies(
        board,
        Square.d4,
      ).every((line) => line.contains('queen') && line.contains('D5')),
      isTrue,
    );
  });

  test('en passant names the actual victim square', () {
    final board = Chess.fromSetup(
      Setup.parseFen('4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1'),
    );
    expect(replies(board, Square.e5), contains('I can take the pawn on D5.'));
  });

  test(
    'promotion and possible check are accurate without claiming victory',
    () {
      final promotion = Chess.fromSetup(
        Setup.parseFen('4k3/P7/8/8/8/8/8/4K3 w - - 0 1'),
      );
      expect(
        replies(promotion, Square.a7),
        contains('One step from promotion.'),
      );
      final check = Chess.fromSetup(
        Setup.parseFen('4k3/8/8/8/8/8/R7/4K3 w - - 0 1'),
      );
      expect(
        replies(check, Square.a2),
        contains('I have a move that gives check.'),
      );
      expect(replies(check, Square.a2).join(' '), isNot(contains('capture')));
    },
  );

  test('a stale selection uses the current board legal facts', () {
    final original = Chess.fromSetup(
      Setup.parseFen('4k3/8/8/3q4/3R1p2/8/8/4K3 w - - 0 1'),
    );
    final stale = NeonLiveAction.selection(
      position: original,
      source: Square.d4,
    )!;
    final current = Chess.fromSetup(
      Setup.parseFen('4k3/8/8/8/3R1p2/8/8/4K3 w - - 0 1'),
    );
    final lines = pieceSelectionCommentary(
      position: current,
      action: stale,
      theme: AnimatedArmyTheme.neon,
    );
    expect(lines, contains('I can take the pawn on F4.'));
    expect(lines.join(' '), isNot(contains('D5')));
  });

  test('a selection for another turn or missing piece has no reply', () {
    final selected = NeonLiveAction.selection(
      position: Chess.initial,
      source: Square.e2,
    )!;
    final after = Chess.initial.play(
      const NormalMove(from: Square.e2, to: Square.e4),
    );
    expect(
      pieceSelectionCommentary(
        position: after,
        action: selected,
        theme: AnimatedArmyTheme.neon,
      ),
      isEmpty,
    );
  });
}
