import 'package:battle_chess_arena/src/domain/cinematic_replay.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/neon_live_action.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

Position _position(String fen) => Chess.fromSetup(Setup.parseFen(fen));

NeonLiveAction _played(
  Position before,
  String uci, {
  Side viewer = Side.white,
}) {
  final game = GameSession(position: before);
  final resolution = game.playUci(uci)!;
  return NeonLiveAction.move(
    before: before,
    after: game.position,
    resolution: resolution,
    viewerSide: viewer,
  )!;
}

void main() {
  test('selection rejects empty opponent and terminal positions', () {
    expect(
      NeonLiveAction.selection(position: Chess.initial, source: Square.e4),
      isNull,
    );
    expect(
      NeonLiveAction.selection(position: Chess.initial, source: Square.e7),
      isNull,
    );
    final mate = CinematicReplay.fromMoves(
      moves: ['f2f3', 'e7e5', 'g2g4', 'd8h4'],
    ).finalPosition;
    expect(NeonLiveAction.selection(position: mate, source: Square.e1), isNull);
    final bareKings = _position('4k3/8/8/8/8/8/8/4K3 w - - 0 1');
    expect(
      NeonLiveAction.selection(position: bareKings, source: Square.e1),
      isNull,
    );
    final fifty = _position('6k1/8/8/8/8/8/8/4K2R w - - 100 70');
    expect(
      NeonLiveAction.selection(position: fifty, source: Square.h1),
      isNull,
    );
  });

  test(
    'selected hero keeps its viewer-relative lane and empty targets are not victims',
    () {
      final white = NeonLiveAction.selection(
        position: Chess.initial,
        source: Square.e2,
      )!;
      expect(white.actor, Piece.whitePawn);
      expect(white.source, Square.e2);
      expect(white.target, isNull);
      expect(white.actorOnLeft, isTrue);
      expect(white.isSelection, isTrue);
      expect(white.threats, isEmpty);
      expect(white.captured, isNull);
      expect(white.castling, isNull);
      final afterWhite = CinematicReplay.fromMoves(
        moves: ['e2e4'],
      ).finalPosition;
      final black = NeonLiveAction.selection(
        position: afterWhite,
        source: Square.e7,
      )!;
      expect(black.actor, Piece.blackPawn);
      expect(black.actorOnLeft, isFalse);
      final blackViewer = NeonLiveAction.selection(
        position: afterWhite,
        source: Square.e7,
        viewerSide: Side.black,
      )!;
      expect(blackViewer.actorOnLeft, isTrue);
      expect(black.actorOnLeft, _played(afterWhite, 'e7e5').actorOnLeft);
      expect(
        blackViewer.actorOnLeft,
        _played(afterWhite, 'e7e5', viewer: Side.black).actorOnLeft,
      );
      expect(black.threats, isEmpty);
    },
  );

  test('selection capture targets belong only to the selected piece', () {
    final position = CinematicReplay.fromMoves(
      moves: ['e2e4', 'd7d5', 'b1c3', 'g8f6'],
    ).finalPosition;
    final action = NeonLiveAction.selection(
      position: position,
      source: Square.c3,
    )!;
    expect(action.threats, hasLength(1));
    expect(action.threats.single.piece, Piece.blackPawn);
    expect(action.threats.single.square, Square.d5);
    expect(action.threats.single.destinations, {Square.d5});
    expect(action.threats.single.isKingThreat, isFalse);
  });

  test(
    'pinned capture is excluded while legal capture along the pin remains',
    () {
      final position = _position('k3r3/8/8/8/8/8/4R1q1/4K3 w - - 0 1');
      expect(
        position.isLegal(const NormalMove(from: Square.e2, to: Square.g2)),
        isFalse,
      );
      expect(
        position.isLegal(const NormalMove(from: Square.e2, to: Square.e8)),
        isTrue,
      );
      final action = NeonLiveAction.selection(
        position: position,
        source: Square.e2,
      )!;
      expect(action.threats.any((t) => t.square == Square.g2), isFalse);
      final rook = action.threats.singleWhere((t) => t.square == Square.e8);
      expect(rook.piece, Piece.blackRook);
      expect(rook.destinations, {Square.e8});
      final king = action.threats.singleWhere((t) => t.isKingThreat);
      expect(king.possibleCheck, isTrue);
      expect(king.isCheck, isFalse);
      expect(king.destinations, contains(Square.e8));
    },
  );

  test('pawns cannot capture a piece directly in front of them', () {
    final position = _position('4k3/8/4p3/4P3/8/8/8/4K3 w - - 0 1');
    final action = NeonLiveAction.selection(
      position: position,
      source: Square.e5,
    )!;
    expect(action.threats, isEmpty);
  });

  test(
    'selection en passant maps victim square to different legal landing',
    () {
      final position = _position('4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 2');
      final fen = position.fen;
      final action = NeonLiveAction.selection(
        position: position,
        source: Square.e5,
      )!;
      final pawn = action.threats.single;
      expect(pawn.piece, Piece.blackPawn);
      expect(pawn.square, Square.d5);
      expect(pawn.destinations, {Square.d6});
      expect(pawn.isCheck, isFalse);
      expect(pawn.possibleCheck, isFalse);
      expect(position.fen, fen);
      expect(position.epSquare, Square.d6);
    },
  );

  test(
    'possible check uses actual legal moves without proposing king capture',
    () {
      final position = _position('6k1/8/8/8/8/8/P7/4K2R w - - 0 1');
      final action = NeonLiveAction.selection(
        position: position,
        source: Square.h1,
      )!;
      final king = action.threats.single;
      expect(position.isCheck, isFalse);
      expect(king.piece, Piece.blackKing);
      expect(king.square, Square.g8);
      expect(king.isCheck, isFalse);
      expect(king.possibleCheck, isTrue);
      expect(king.destinations, containsAll([Square.g1, Square.h8]));
      expect(king.destinations, isNot(contains(king.square)));
      for (final destination in king.destinations) {
        final move = NormalMove(from: Square.h1, to: destination);
        expect(position.isLegal(move), isTrue);
        expect(position.play(move).isCheck, isTrue);
      }
    },
  );

  test('checking opportunity tests all underpromotions', () {
    final position = _position('8/1P1k4/8/8/8/8/8/4K3 w - - 0 1');
    expect(
      position
          .play(
            const NormalMove(
              from: Square.b7,
              to: Square.b8,
              promotion: Role.queen,
            ),
          )
          .isCheck,
      isFalse,
    );
    expect(
      position
          .play(
            const NormalMove(
              from: Square.b7,
              to: Square.b8,
              promotion: Role.knight,
            ),
          )
          .isCheck,
      isTrue,
    );
    final action = NeonLiveAction.selection(
      position: position,
      source: Square.b7,
    )!;
    final king = action.threats.single;
    expect(king.piece, Piece.blackKing);
    expect(king.possibleCheck, isTrue);
    expect(king.destinations, {Square.b8});
  });

  test(
    'king cannot capture a protected victim or attack enemy king illegally',
    () {
      final position = _position('8/8/8/8/8/4k3/3p4/4K3 w - - 0 1');
      expect(position.isCheck, isTrue);
      expect(
        position.isLegal(const NormalMove(from: Square.e1, to: Square.d2)),
        isFalse,
      );
      final action = NeonLiveAction.selection(
        position: position,
        source: Square.e1,
      )!;
      expect(action.threats, isEmpty);
    },
  );

  test('committed actor orientation follows actual viewer side', () {
    final white = _played(Chess.initial, 'e2e4');
    expect(white.actor, Piece.whitePawn);
    expect(white.source, Square.e2);
    expect(white.target, Square.e4);
    expect(white.isSelection, isFalse);
    expect(white.actorOnLeft, isTrue);
    expect(
      _played(Chess.initial, 'e2e4', viewer: Side.black).actorOnLeft,
      isFalse,
    );
    final beforeBlack = CinematicReplay.fromMoves(
      moves: ['e2e4'],
    ).finalPosition;
    expect(
      _played(beforeBlack, 'e7e5', viewer: Side.black).actorOnLeft,
      isTrue,
    );
    expect(_played(beforeBlack, 'e7e5').actorOnLeft, isFalse);
  });

  test(
    'moved-piece threats exclude unrelated attackers but include discovered check',
    () {
      final before = _position('4k3/8/8/8/2q5/3p4/4P3/n3R1K1 w - - 0 1');
      final action = _played(before, 'e2d3');
      expect(action.actor, Piece.whitePawn);
      expect(action.captured, Piece.blackPawn);
      expect(action.captureSquare, Square.d3);
      expect(action.threats.map((t) => t.square), [Square.e8, Square.c4]);
      expect(action.threats.any((t) => t.square == Square.a1), isFalse);
      expect(
        action.threats.any((t) => t.square == action.captureSquare),
        isFalse,
      );
      final king = action.threats.first;
      expect(king.isCheck, isTrue);
      expect(king.possibleCheck, isFalse);
      expect(king.destinations, isEmpty);
      expect(action.threats.last.destinations, {Square.c4});
    },
  );

  test(
    'castling normalizes king destination and never captures its own rook',
    () {
      for (final entry in {
        '5k2/8/8/8/8/8/8/4K2R w K - 0 1': (
          'e1g1',
          Square.g1,
          Square.h1,
          Square.f1,
        ),
        '3k4/8/8/8/8/8/8/R3K3 w Q - 0 1': (
          'e1c1',
          Square.c1,
          Square.a1,
          Square.d1,
        ),
        '4k2r/8/8/8/8/8/8/5K2 b k - 0 1': (
          'e8g8',
          Square.g8,
          Square.h8,
          Square.f8,
        ),
        'r3k3/8/8/8/8/8/8/3K4 b q - 0 1': (
          'e8c8',
          Square.c8,
          Square.a8,
          Square.d8,
        ),
      }.entries) {
        final before = _position(entry.key);
        final source = before.board.kingOf(before.turn)!;
        final selected = NeonLiveAction.selection(
          position: before,
          source: source,
        )!;
        expect(selected.castling, isNull);
        expect(selected.threats.single.possibleCheck, isTrue);
        expect(selected.threats.single.destinations, contains(entry.value.$2));
        final moved = _played(before, entry.value.$1);
        expect(moved.actor, Piece(color: before.turn, role: Role.king));
        expect(moved.target, entry.value.$2);
        expect(moved.captured, isNull);
        expect(moved.captureSquare, isNull);
        expect(
          moved.castling!.rook,
          Piece(color: before.turn, role: Role.rook),
        );
        expect(moved.castling!.source, entry.value.$3);
        expect(moved.castling!.target, entry.value.$4);
        expect(moved.castling!.kingside, entry.value.$2.file == File.g);
        expect(moved.threats.single.isCheck, isTrue);
        expect(moved.threats.single.destinations, isEmpty);
      }
    },
  );

  test('ordinary king and rook moves never invent a castling companion', () {
    final before = _position('k7/8/8/8/8/8/8/4K2R w K - 0 1');
    expect(_played(before, 'e1f1').castling, isNull);
    expect(_played(before, 'h1h2').castling, isNull);
    expect(_played(Chess.initial, 'e2e4').castling, isNull);
  });

  test('promotion changes actor role and capture retains actual victim', () {
    final replay = CinematicReplay.fromMoves(
      moves: [
        'a2a4',
        'h7h5',
        'a4a5',
        'h5h4',
        'a5a6',
        'h4h3',
        'a6b7',
        'h3g2',
        'b7a8q',
      ],
    );
    final scene = replay.scenes.last;
    final action = NeonLiveAction.move(
      before: scene.before,
      after: scene.after,
      resolution: scene.resolution,
      viewerSide: Side.white,
    )!;
    expect(action.actor, Piece.whiteQueen);
    expect(action.source, Square.b7);
    expect(action.target, Square.a8);
    expect(action.captured, Piece.blackRook);
    expect(action.captureSquare, Square.a8);
    expect(action.threats.any((t) => t.square == Square.a8), isFalse);
    expect(
      action.threats.any(
        (t) => t.square == Square.b8 && t.piece == Piece.blackKnight,
      ),
      isTrue,
    );
  });

  test(
    'en passant commit removes off-target victim and threatens from landing',
    () {
      final replay = CinematicReplay.fromMoves(
        moves: ['e2e4', 'a7a6', 'e4e5', 'd7d5', 'e5d6'],
      );
      final scene = replay.scenes.last;
      final action = NeonLiveAction.move(
        before: scene.before,
        after: scene.after,
        resolution: scene.resolution,
        viewerSide: Side.white,
      )!;
      expect(action.actor, Piece.whitePawn);
      expect(action.target, Square.d6);
      expect(action.captured, Piece.blackPawn);
      expect(action.captureSquare, Square.d5);
      expect(action.threats.map((t) => t.square), [Square.c7, Square.e7]);
      expect(action.threats.any((t) => t.square == Square.a6), isFalse);
      expect(action.threats.any((t) => t.square == Square.d5), isFalse);
    },
  );

  test(
    'mate action survives terminal after position with true check bubble',
    () {
      final replay = CinematicReplay.fromMoves(
        moves: ['f2f3', 'e7e5', 'g2g4', 'd8h4'],
      );
      final scene = replay.scenes.last;
      expect(scene.after.isCheckmate, isTrue);
      final action = NeonLiveAction.move(
        before: scene.before,
        after: scene.after,
        resolution: scene.resolution,
        viewerSide: Side.white,
      )!;
      expect(action.actor, Piece.blackQueen);
      expect(action.actorOnLeft, isFalse);
      expect(action.threats.first.piece, Piece.whiteKing);
      expect(action.threats.first.isCheck, isTrue);
      expect(action.threats.first.destinations, isEmpty);
    },
  );

  test(
    'invalid transitions or invented resolution metadata return no action',
    () {
      final game = GameSession();
      final before = game.position;
      final move = game.playUci('e2e4')!;
      expect(
        NeonLiveAction.move(
          before: before,
          after: before,
          resolution: move,
          viewerSide: Side.white,
        ),
        isNull,
      );
      expect(
        NeonLiveAction.move(
          before: before,
          after: game.position.copyWith(halfmoves: 99),
          resolution: move,
          viewerSide: Side.white,
        ),
        isNull,
      );
      for (final invalid in [
        MoveResolution(move: move.move, san: 'e3', attacker: move.attacker),
        MoveResolution(
          move: move.move,
          san: move.san,
          attacker: Piece.blackPawn,
        ),
        MoveResolution(
          move: move.move,
          san: move.san,
          attacker: move.attacker,
          defender: Piece.blackQueen,
        ),
        const MoveResolution(
          move: NormalMove(from: Square.e2, to: Square.e5),
          san: 'e5',
          attacker: Piece.whitePawn,
        ),
      ]) {
        expect(
          NeonLiveAction.move(
            before: before,
            after: game.position,
            resolution: invalid,
            viewerSide: Side.white,
          ),
          isNull,
        );
      }
    },
  );

  test(
    'snapshots and threat destinations remain immutable and deterministic',
    () {
      final position = _position('k3r3/8/8/8/8/8/4R1q1/4K3 w - - 0 1');
      final fen = position.fen;
      final first = NeonLiveAction.selection(
        position: position,
        source: Square.e2,
      )!;
      final second = NeonLiveAction.selection(
        position: position,
        source: Square.e2,
      )!;
      expect(
        first.threats.map((t) => t.square),
        second.threats.map((t) => t.square),
      );
      expect(position.fen, fen);
      expect(() => first.threats.clear(), throwsUnsupportedError);
      expect(
        () => first.threats.first.destinations.clear(),
        throwsUnsupportedError,
      );
      final scene = CinematicReplay.fromMoves(moves: ['e2e4']).scenes.single;
      final beforeFen = scene.before.fen;
      final afterFen = scene.after.fen;
      NeonLiveAction.move(
        before: scene.before,
        after: scene.after,
        resolution: scene.resolution,
        viewerSide: Side.white,
      );
      expect(scene.before.fen, beforeFen);
      expect(scene.after.fen, afterFen);
    },
  );
}
