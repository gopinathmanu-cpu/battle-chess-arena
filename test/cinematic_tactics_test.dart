import 'package:battle_chess_arena/src/domain/cinematic_replay.dart';
import 'package:battle_chess_arena/src/domain/cinematic_tactics.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

CinematicReplay _replay(List<String> moves) =>
    CinematicReplay.fromMoves(moves: moves);

void main() {
  test('facing pawns cannot capture forwards and create no false threats', () {
    final scene = _replay(['e2e4', 'e7e5']).scenes.last;
    final facts = CinematicTactics.after(scene);
    expect(facts.opponentThreats, isEmpty);
    expect(facts.ownPiecesAtRisk, isEmpty);
    expect(facts.newForks, isEmpty);
    expect(facts.materialBefore, 0);
    expect(facts.materialAfter, 0);
  });

  test('capture leaves actual legal recapture while victim is gone', () {
    final scene = _replay(['e2e4', 'd7d5', 'e4d5']).scenes.last;
    final facts = CinematicTactics.after(scene);
    expect(facts.opponentThreats, isEmpty);
    final risk = facts.ownPiecesAtRisk.single;
    expect(risk.piece, Piece.whitePawn);
    expect(risk.square, Square.d5);
    expect(risk.sourceSquares, {Square.d8});
    expect(risk.attacks.single.attacker, Piece.blackQueen);
    expect(
      scene.after.isLegal(const NormalMove(from: Square.d8, to: Square.d5)),
      isTrue,
    );
    expect(facts.materialBefore, 0);
    expect(facts.materialAfter, 1);
    expect(facts.materialGain, 1);
  });

  test('pinned knight geometrically attacks a pawn but has no legal reply', () {
    final scene = _replay(['e2e4', 'b8c6', 'f1b5', 'd7d5', 'e4e5']).scenes.last;
    expect(
      scene.after.board.attacksTo(Square.e5, Side.black).squares,
      contains(Square.c6),
    );
    expect(
      scene.after.isLegal(const NormalMove(from: Square.c6, to: Square.e5)),
      isFalse,
    );
    final facts = CinematicTactics.after(scene);
    expect(facts.ownPiecesAtRisk, isEmpty);
    expect(facts.opponentThreats.single.square, Square.c6);
    expect(facts.newForks, isEmpty);
  });

  test('check restricts replies to captures that actually answer check', () {
    final scene = _replay(['e2e4', 'f7f5', 'a2a3', 'g8f6', 'd1h5']).scenes.last;
    expect(scene.isCheck, isTrue);
    expect(
      scene.after.board.attacksTo(Square.e4, Side.black).squares,
      contains(Square.f6),
    );
    expect(
      scene.after.isLegal(const NormalMove(from: Square.f6, to: Square.e4)),
      isFalse,
    );
    final facts = CinematicTactics.after(scene);
    expect(
      facts.ownPiecesAtRisk.any((risk) => risk.square == Square.e4),
      isFalse,
    );
    final queen = facts.ownPiecesAtRisk.single;
    expect(queen.square, Square.h5);
    expect(queen.sourceSquares, {Square.f6});
    expect(
      scene.after.isLegal(const NormalMove(from: Square.f6, to: Square.h5)),
      isTrue,
    );
    expect(facts.opponentThreats.first.isCheck, isTrue);
    expect(facts.opponentThreats.first.piece, Piece.blackKing);
  });

  test('real opponent reply retains its own en passant right', () {
    final replay = _replay(['e2e4', 'a7a6', 'e4e5', 'd7d5']);
    final scene = replay.scenes.last;
    final fen = scene.after.fen;
    final facts = CinematicTactics.after(scene);
    expect(facts.opponentThreats, isEmpty);
    final risk = facts.ownPiecesAtRisk.singleWhere(
      (risk) => risk.square == Square.d5,
    );
    expect(risk.piece, Piece.blackPawn);
    expect(risk.square, Square.d5);
    expect(risk.sourceSquares, {Square.e5});
    expect(risk.attacks.single.to, Square.d6);
    expect(risk.attacks.single.enPassant, isTrue);
    expect(
      scene.after.isLegal(const NormalMove(from: Square.e5, to: Square.d6)),
      isTrue,
    );
    expect(scene.after.fen, fen);
    expect(scene.after.epSquare, Square.d6);
    expect(replay.uciMoves, ['e2e4', 'a7a6', 'e4e5', 'd7d5']);
  });

  const forkMoves = [
    'e2e4',
    'e7e5',
    'g1f3',
    'b8c6',
    'f1c4',
    'g8f6',
    'f3g5',
    'f8c5',
    'g5f7',
  ];
  test(
    'one legal knight creates a queen-rook fork without promising a win',
    () {
      final scene = _replay(forkMoves).scenes.last;
      final facts = CinematicTactics.after(scene);
      final fork = facts.newForks.single;
      expect(fork.attacker, Piece.whiteKnight);
      expect(fork.source, Square.f7);
      expect(fork.targets.map((t) => t.square), [Square.d8, Square.h8]);
      expect(fork.targets.map((t) => t.piece), [
        Piece.blackQueen,
        Piece.blackRook,
      ]);
      final view = scene.after.copyWith(turn: Side.white, epSquare: null);
      for (final target in fork.targets) {
        expect(
          view.isLegal(NormalMove(from: fork.source, to: target.square)),
          isTrue,
        );
      }
      expect(facts.materialGain, 1);
    },
  );

  test('preexisting fork is not credited to an unrelated later move', () {
    final scene = _replay([...forkMoves, 'a7a6', 'h2h3']).scenes.last;
    final facts = CinematicTactics.after(scene);
    expect(
      facts.opponentThreats.any(
        (t) => t.square == Square.d8 && t.sourceSquares.contains(Square.f7),
      ),
      isTrue,
    );
    expect(
      facts.opponentThreats.any(
        (t) => t.square == Square.h8 && t.sourceSquares.contains(Square.f7),
      ),
      isTrue,
    );
    expect(facts.newForks, isEmpty);
  });

  test(
    'separate attackers and pawn-only targets are not exceptional forks',
    () {
      final pawn = CinematicTactics.after(
        _replay(['e2e4', 'd7d5', 'b1c3']).scenes.last,
      );
      expect(pawn.opponentThreats.single.sourceSquares, {Square.c3, Square.e4});
      expect(pawn.newForks, isEmpty);
      final four = CinematicTactics.after(
        _replay(['e2e4', 'e7e5', 'a2a3', 'd8h4']).scenes.last,
      );
      expect(four.opponentThreats.map((t) => t.square), [
        Square.a3,
        Square.e4,
        Square.f2,
        Square.h2,
      ]);
      expect(four.newForks, isEmpty);
    },
  );

  test('promotion material uses the actual chosen role and captured rook', () {
    const prefix = [
      'a2a4',
      'h7h5',
      'a4a5',
      'h5h4',
      'a5a6',
      'h4h3',
      'a6b7',
      'h3g2',
    ];
    for (final choice in {'q': 13, 'r': 9, 'b': 7, 'n': 7}.entries) {
      final scene = _replay([...prefix, 'b7a8${choice.key}']).scenes.last;
      final facts = CinematicTactics.after(scene);
      expect(facts.materialBefore, 0);
      expect(facts.materialAfter, choice.value);
      expect(facts.materialGain, choice.value);
      expect(facts.opponentThreats.any((t) => t.square == Square.a8), isFalse);
    }
  });

  test(
    'queen capture measures present material and does not change replay',
    () {
      final replay = _replay([
        'e2e4',
        'd7d5',
        'e4d5',
        'd8d5',
        'b1c3',
        'a7a6',
        'c3d5',
      ]);
      final scene = replay.scenes.last;
      final before = scene.before.fen;
      final after = scene.after.fen;
      final facts = CinematicTactics.after(scene);
      expect(facts.materialBefore, 0);
      expect(facts.materialAfter, 9);
      expect(facts.materialGain, 9);
      expect(scene.before.fen, before);
      expect(scene.after.fen, after);
      expect(() => facts.opponentThreats.clear(), throwsUnsupportedError);
      expect(() => facts.ownPiecesAtRisk.clear(), throwsUnsupportedError);
      expect(() => facts.newForks.clear(), throwsUnsupportedError);
      final fork = CinematicTactics.after(
        _replay(forkMoves).scenes.last,
      ).newForks.single;
      expect(() => fork.targets.clear(), throwsUnsupportedError);
    },
  );

  test('castled rook and promoted knight use their actual new sources', () {
    final castle = _replay([
      'e2e4',
      'e7e6',
      'f2f4',
      'a7a6',
      'f4f5',
      'a6a5',
      'f5e6',
      'd7e6',
      'g1h3',
      'b8c6',
      'f1c4',
      'g8f6',
      'e1g1',
    ]).scenes.last;
    final rookThreat = CinematicTactics.after(
      castle,
    ).opponentThreats.singleWhere((t) => t.square == Square.f6);
    expect(rookThreat.sourceSquares, {Square.f1});
    expect(rookThreat.attacks.single.attacker, Piece.whiteRook);
    final promotion = _replay([
      'a2a4',
      'h7h5',
      'a4a5',
      'h5h4',
      'a5a6',
      'h4h3',
      'a6b7',
      'h3g2',
      'b7a8n',
    ]).scenes.last;
    final knightThreat = CinematicTactics.after(
      promotion,
    ).opponentThreats.singleWhere((t) => t.square == Square.c7);
    expect(knightThreat.sourceSquares, {Square.a8});
    expect(knightThreat.attacks.single.attacker, Piece.whiteKnight);
  });

  test('checkmate has no legal opponent reply and never a capturable king', () {
    final scene = _replay(['f2f3', 'e7e5', 'g2g4', 'd8h4']).scenes.last;
    final facts = CinematicTactics.after(scene);
    expect(facts.ownPiecesAtRisk, isEmpty);
    expect(facts.opponentThreats.first.piece, Piece.whiteKing);
    expect(facts.opponentThreats.first.isCheck, isTrue);
    expect(facts.opponentThreats.first.attacks.every((a) => a.isCheck), isTrue);
  });
}
