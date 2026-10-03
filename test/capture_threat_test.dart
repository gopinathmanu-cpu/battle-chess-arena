import 'package:battle_chess_arena/src/domain/capture_threat.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

List<CaptureThreat> threats(String fen, {Side defender = Side.white}) =>
    immediateCaptureThreats(
      Chess.fromSetup(Setup.parseFen(fen)),
      defender: defender,
    );

void main() {
  test('initial board has no capture threats', () {
    expect(
      immediateCaptureThreats(Chess.initial, defender: Side.white),
      isEmpty,
    );
  });

  test(
    'shows each legal attacker/victim pair in stable material-first order',
    () {
      const fen = 'r6k/8/2b5/3P4/Q7/8/8/6K1 w - - 0 1';
      final result = threats(fen);
      expect(result.map((t) => '${t.from.name}${t.to.name}'), [
        'a8a4',
        'c6a4',
        'c6d5',
      ]);
      expect(result.map((t) => t.targetSquare), [
        Square.a4,
        Square.a4,
        Square.d5,
      ]);
      expect(
        result.every(
          (t) => t.attacker.color == Side.black && t.target.color == Side.white,
        ),
        isTrue,
      );
    },
  );

  test(
    'pawn pushes, blocked sliding attacks, and castling are not captures',
    () {
      expect(threats('7k/8/8/3p4/3PP3/8/8/7K w - - 0 1').map((t) => t.to), [
        Square.e4,
      ]);
      expect(threats('r6k/8/P7/8/Q7/8/8/6K1 w - - 0 1').map((t) => t.to), [
        Square.a6,
      ]);
      expect(threats('r3k2r/8/8/8/8/8/8/4K3 w kq - 0 1'), isEmpty);
    },
  );

  test('pinned attackers and unsafe king captures are excluded', () {
    expect(threats('6k1/6n1/4P3/8/8/8/8/K5R1 w - - 0 1'), isEmpty);
    expect(threats('6k1/6P1/5K2/8/8/8/8/8 w - - 0 1'), isEmpty);
  });

  test('an active check is shown before the remaining capture threats', () {
    final result = threats('k3r3/8/2n5/8/3P4/8/8/4K3 w - - 0 1');
    expect(result.first.isCheck, isTrue);
    expect(result.first.from, Square.e8);
    expect(result.first.targetSquare, Square.e1);
    expect(result.first.target.role, Role.king);
    expect(result.first.description, startsWith('Check ·'));
    expect(result.any((t) => t.from == Square.c6 && t.to == Square.d4), isTrue);
  });

  test('promotion choices share one attacker/victim display pair', () {
    final result = threats('7k/8/8/8/8/7K/1p6/R7 w - - 0 1');
    expect(result, hasLength(1));
    expect(result.single.from, Square.b2);
    expect(result.single.to, Square.a1);
    expect(result.single.promotes, isTrue);
  });

  test(
    'en passant identifies the actual victim and rejects discovered king exposure',
    () {
      final result = threats('7k/8/8/8/3pP3/8/8/7K b - e3 0 1');
      expect(result, hasLength(1));
      expect(result.single.from, Square.d4);
      expect(result.single.to, Square.e3);
      expect(result.single.targetSquare, Square.e4);
      expect(result.single.enPassant, isTrue);
      expect(threats('8/8/8/8/k2pP2R/8/8/7K b - e3 0 1'), isEmpty);
    },
  );

  test(
    'turn projection does not mutate history or retain another sides en passant',
    () {
      final game = GameSession.fromMoves(
        moves: ['e2e4', 'a7a6', 'e4e5', 'd7d5'],
      );
      final before = game.position.fen;
      expect(game.position.epSquare, Square.d6);
      final result = immediateCaptureThreats(
        game.position,
        defender: Side.white,
      );
      expect(result.any((t) => t.enPassant), isFalse);
      expect(game.position.fen, before);
      expect(game.uciMoves, ['e2e4', 'a7a6', 'e4e5', 'd7d5']);
    },
  );

  test('black defender sees white threats', () {
    final game = GameSession.fromMoves(moves: ['e2e4', 'd7d5', 'b1c3']);
    final result = immediateCaptureThreats(game.position, defender: Side.black);
    expect(result.map((t) => t.from).toSet(), {Square.c3, Square.e4});
    expect(result.every((t) => t.targetSquare == Square.d5), isTrue);
  });
}
