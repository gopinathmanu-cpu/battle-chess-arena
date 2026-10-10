import 'package:battle_chess_arena/src/domain/cinematic_replay.dart';
import 'package:battle_chess_arena/src/domain/cinematic_threats.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

CinematicReplay _replay(List<String> moves) =>
    CinematicReplay.fromMoves(moves: moves);

void main() {
  test('an opening pawn advance has no invented threatened victims', () {
    final scene = _replay(['e2e4']).scenes.single;
    expect(cinematicThreatsAfter(scene), isEmpty);
  });

  test(
    'multiple legal attackers share one opponent bubble and stable sources',
    () {
      final replay = _replay(['e2e4', 'd7d5', 'b1c3']);
      final result = cinematicThreatsAfter(replay.scenes.last);
      expect(result, hasLength(1));
      final target = result.single;
      expect(target.square, Square.d5);
      expect(target.piece, Piece.blackPawn);
      expect(target.sourceSquares, {Square.c3, Square.e4});
      expect(target.attacks.map((attack) => attack.from), [
        Square.c3,
        Square.e4,
      ]);
      expect(target.newlyThreatened, isFalse);
      expect(target.isCheck, isFalse);
      expect(
        target.attacks.every((attack) => attack.attacker.color == Side.white),
        isTrue,
      );
      expect(() => result.clear(), throwsUnsupportedError);
      expect(() => target.attacks.clear(), throwsUnsupportedError);
      expect(() => target.sourceSquares.clear(), throwsUnsupportedError);
    },
  );

  test(
    'new threats differ from all current threats and never retain victims',
    () {
      final replay = _replay(['e2e4', 'd7d5', 'e4d5']);
      final blackThreats = cinematicThreatsAfter(replay.scenes[1]);
      final whitePawn = blackThreats.singleWhere(
        (target) => target.square == Square.e4,
      );
      expect(whitePawn.newlyThreatened, isTrue);
      expect(whitePawn.piece, Piece.whitePawn);
      expect(whitePawn.sourceSquares, {Square.d5});
      final capture = replay.scenes.last;
      expect(capture.resolution.defender, Piece.blackPawn);
      final afterCapture = cinematicThreatsAfter(capture);
      expect(afterCapture.any((target) => target.square == Square.d5), isFalse);
      expect(
        afterCapture.every((target) => target.piece.color == Side.black),
        isTrue,
      );
      for (final target in afterCapture) {
        expect(capture.after.board.pieceAt(target.square), target.piece);
      }
    },
  );

  test(
    'a discovered threat can come from a stationary piece of the moving army',
    () {
      final replay = _replay([
        'b1c3',
        'c7c6',
        'g1f3',
        'd8a5',
        'a2a3',
        'a5a6',
        'e2e3',
      ]);
      final scene = replay.scenes.last;
      expect(scene.source, Square.e2);
      final result = cinematicThreatsAfter(scene);
      final queen = result.singleWhere((target) => target.square == Square.a6);
      expect(queen.piece, Piece.blackQueen);
      expect(queen.sourceSquares, contains(Square.f1));
      expect(queen.sourceSquares, isNot(contains(scene.target)));
      expect(queen.newlyThreatened, isTrue);
      expect(queen.attacks.single.attacker, Piece.whiteBishop);
    },
  );

  test('pinned attackers do not create illegal capture opportunities', () {
    final replay = _replay(['e2e4', 'b8c6', 'f1b5', 'd7d6', 'e4e5', 'e7e6']);
    final scene = replay.scenes.last;
    expect(scene.after.board.pieceAt(Square.c6), Piece.blackKnight);
    expect(
      scene.after.board.attacksTo(Square.e5, Side.black).squares,
      contains(Square.c6),
    );
    final pawn = cinematicThreatsAfter(
      scene,
    ).singleWhere((target) => target.square == Square.e5);
    expect(pawn.piece, Piece.whitePawn);
    expect(pawn.sourceSquares, {Square.d6});
    expect(pawn.sourceSquares, isNot(contains(Square.c6)));
    expect(pawn.attacks.single.attacker, Piece.blackPawn);
  });

  test(
    'check is first and labels the king as checked rather than capturable',
    () {
      final scene = _replay(['e2e4', 'f7f6', 'd1h5']).scenes.last;
      expect(scene.after.isCheck, isTrue);
      final threats = cinematicThreatsAfter(scene);
      expect(threats.first.square, Square.e8);
      expect(threats.first.piece, Piece.blackKing);
      expect(threats.first.isCheck, isTrue);
      expect(threats.first.newlyThreatened, isTrue);
      expect(threats.first.sourceSquares, {Square.h5});
      expect(threats.first.attacks.every((attack) => attack.isCheck), isTrue);
      expect(threats.any((target) => target.square == Square.h7), isTrue);
      expect(
        threats.every(
          (target) => target.piece.role != Role.king || target.isCheck,
        ),
        isTrue,
      );
    },
  );

  test('the castled rook creates threats from its actual new square', () {
    final scene = _replay([
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
    expect(scene.isCastling, isTrue);
    final knight = cinematicThreatsAfter(
      scene,
    ).singleWhere((target) => target.square == Square.f6);
    expect(knight.piece, Piece.blackKnight);
    expect(knight.sourceSquares, {Square.f1});
    expect(knight.attacks.single.attacker, Piece.whiteRook);
    expect(knight.newlyThreatened, isTrue);
    expect(knight.sourceSquares, isNot(contains(Square.h1)));
  });

  test(
    'promotion threatens with the chosen new role rather than the old pawn',
    () {
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
      final queen = _replay([...prefix, 'b7a8q']).scenes.last;
      final queenThreat = cinematicThreatsAfter(
        queen,
      ).singleWhere((target) => target.square == Square.b8);
      expect(queenThreat.piece, Piece.blackKnight);
      expect(queenThreat.attacks.single.attacker, Piece.whiteQueen);
      expect(queenThreat.sourceSquares, {Square.a8});
      expect(queenThreat.newlyThreatened, isTrue);

      final knight = _replay([...prefix, 'b7a8n']).scenes.last;
      final knightThreat = cinematicThreatsAfter(
        knight,
      ).singleWhere((target) => target.square == Square.c7);
      expect(knightThreat.piece, Piece.blackPawn);
      expect(knightThreat.attacks.single.attacker, Piece.whiteKnight);
      expect(knightThreat.sourceSquares, {Square.a8});
      expect(
        cinematicThreatsAfter(
          knight,
        ).any((target) => target.square == Square.a8),
        isFalse,
      );
    },
  );

  test(
    'en passant removes its off-target victim before threat bubbles appear',
    () {
      final scene = _replay([
        'e2e4',
        'a7a6',
        'e4e5',
        'd7d5',
        'e5d6',
      ]).scenes.last;
      expect(scene.isEnPassant, isTrue);
      expect(scene.captureSquare, Square.d5);
      final threats = cinematicThreatsAfter(scene);
      expect(threats.any((target) => target.square == Square.d5), isFalse);
      for (final square in [Square.c7, Square.e7]) {
        final pawn = threats.singleWhere((target) => target.square == square);
        expect(pawn.piece, Piece.blackPawn);
        expect(pawn.sourceSquares, {Square.d6});
        expect(pawn.newlyThreatened, isTrue);
      }
    },
  );

  test(
    'hypothetical turn flips discard opponent en passant and preserve replay',
    () {
      final replay = _replay(['e2e4', 'a7a6', 'e4e5', 'd7d5']);
      final scene = replay.scenes.last;
      final beforeFen = scene.before.fen;
      final afterFen = scene.after.fen;
      final moves = replay.uciMoves.toList();
      expect(scene.after.turn, Side.white);
      expect(scene.after.epSquare, Square.d6);
      final first = cinematicThreatsAfter(scene);
      final second = cinematicThreatsAfter(scene);
      expect(
        first
            .expand((target) => target.attacks)
            .any((attack) => attack.enPassant),
        isFalse,
      );
      expect(first.every((target) => target.piece.color == Side.white), isTrue);
      expect(
        first.map((target) => target.square).toList(),
        second.map((target) => target.square).toList(),
      );
      expect(scene.before.fen, beforeFen);
      expect(scene.after.fen, afterFen);
      expect(scene.after.epSquare, Square.d6);
      expect(replay.uciMoves, moves);
    },
  );
}
