import 'dart:async';
import 'dart:math';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class StubPlayer implements ComputerPlayer {
  StubPlayer(this.answer);
  final Future<String?> Function() answer;
  int calls = 0;
  bool disposed = false;
  ComputerDifficulty? lastDifficulty;
  @override
  Future<String?> bestMove(
    String fen, {
    ComputerDifficulty difficulty = ComputerDifficulty.medium,
  }) {
    calls++;
    lastDifficulty = difficulty;
    return answer();
  }

  @override
  void dispose() {
    disposed = true;
  }
}

void main() {
  const fen = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';
  test('preserves a legal native reply', () async {
    final primary = StubPlayer(() async => 'e7e5');
    final player = ReliableComputerPlayer(primary: primary);
    expect(
      await player.bestMove(fen, difficulty: ComputerDifficulty.hard),
      'e7e5',
    );
    expect(primary.lastDifficulty, ComputerDifficulty.hard);
    expect(player.reducedStrength, false);
    player.dispose();
  });
  test('difficulty settings increase engine and backup strength', () {
    expect(ComputerDifficulty.easy.stockfishSkill, 0);
    expect(ComputerDifficulty.medium.stockfishSkill, 5);
    expect(ComputerDifficulty.hard.stockfishSkill, 20);
    expect(ComputerDifficulty.easy.fallbackDepth, 1);
    expect(ComputerDifficulty.medium.fallbackDepth, 1);
    expect(ComputerDifficulty.hard.fallbackDepth, 3);
    expect(
      ComputerDifficulty.easy.thinkTime < ComputerDifficulty.hard.thinkTime,
      true,
    );
  });
  test(
    'browser medium immediately uses the controlled Dart opponent',
    () async {
      if (!kIsWeb) return;
      final player = ReliableComputerPlayer();
      final move = await player.bestMove(fen);
      expect(move, isNotNull);
      expect(
        Chess.fromSetup(Setup.parseFen(fen)).isLegal(Move.parse(move!)!),
        true,
      );
      expect(player.reducedStrength, false);
      player.dispose();
    },
  );
  test('easy and medium deliberately bypass the full native engine', () async {
    final primary = StubPlayer(() async => 'e7e5');
    final player = ReliableComputerPlayer(primary: primary);
    final easy = await player.bestMove(
      fen,
      difficulty: ComputerDifficulty.easy,
    );
    final medium = await player.bestMove(
      fen,
      difficulty: ComputerDifficulty.medium,
    );
    expect(
      Chess.fromSetup(Setup.parseFen(fen)).isLegal(Move.parse(easy!)!),
      true,
    );
    expect(
      Chess.fromSetup(Setup.parseFen(fen)).isLegal(Move.parse(medium!)!),
      true,
    );
    expect(primary.calls, 0);
    player.dispose();
  });
  test('easy mixes safe standard opening replies', () async {
    const standardReplies = {
      'e7e5',
      'c7c5',
      'e7e6',
      'c7c6',
      'd7d5',
      'g8f6',
      'b8c6',
    };
    final replies = <String>{};
    for (var seed = 0; seed < 12; seed++) {
      final primary = StubPlayer(() async => 'e7e5');
      final player = ReliableComputerPlayer(
        primary: primary,
        random: Random(seed),
      );
      final move = await player.bestMove(
        fen,
        difficulty: ComputerDifficulty.easy,
      );
      expect(standardReplies, contains(move));
      expect(primary.calls, 0);
      replies.add(move!);
      player.dispose();
    }
    expect(replies.length, greaterThan(1));
  });
  testWidgets('stalled native engine falls back and is never retried', (
    tester,
  ) async {
    final pending = Completer<String?>();
    final primary = StubPlayer(() => pending.future);
    final player = ReliableComputerPlayer(primary: primary);
    String? move;
    final result = player
        .bestMove(fen, difficulty: ComputerDifficulty.hard)
        .then((value) => move = value);
    await tester.pump(const Duration(seconds: 13));
    await result;
    expect(
      Chess.fromSetup(Setup.parseFen(fen)).isLegal(Move.parse(move!)!),
      true,
    );
    expect(player.reducedStrength, true);
    expect(primary.disposed, true);
    pending.complete('e7e5');
    await tester.pump();
    final again = await player.bestMove(
      fen,
      difficulty: ComputerDifficulty.hard,
    );
    expect(again, isNotNull);
    expect(primary.calls, 1);
    player.dispose();
  });
  for (final reply in <String?>[null, 'e7e1']) {
    test('missing or illegal native reply falls back: $reply', () async {
      final player = ReliableComputerPlayer(
        primary: StubPlayer(() async => reply),
      );
      final move = await player.bestMove(
        fen,
        difficulty: ComputerDifficulty.hard,
      );
      expect(
        Chess.fromSetup(Setup.parseFen(fen)).isLegal(Move.parse(move!)!),
        true,
      );
      expect(player.reducedStrength, true);
      player.dispose();
    });
  }
  test('backup handles promotion and terminal positions', () async {
    final player = ReliableComputerPlayer(
      primary: StubPlayer(() async => null),
    );
    const promotion = '7k/P7/8/8/8/8/8/7K w - - 0 1';
    final move = await player.bestMove(promotion);
    expect(move, 'a7a8q');
    expect(await player.bestMove('7k/6Q1/5K2/8/8/8/8/8 b - - 0 1'), isNull);
    player.dispose();
  });
}
