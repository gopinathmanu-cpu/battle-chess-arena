import 'dart:async';

import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockfish/stockfish.dart';

class FakeEngine implements Stockfish {
  final commands = <String>[];
  final output = StreamController<String>.broadcast();
  @override
  final state = ValueNotifier(StockfishState.ready);
  @override
  Completer<Stockfish>? get completer => null;
  @override
  Stream<String> get stdout => output.stream;
  @override
  set stdin(String command) => commands.add(command);
  @override
  void dispose() => commands.add('quit');
}

void main() {
  testWidgets('waits for native readiness before starting search', (
    tester,
  ) async {
    final engine = FakeEngine();
    final player = StockfishComputerPlayer(engineFactory: () async => engine);
    String? result;
    final move = player.bestMove('test-fen').then((value) => result = value);
    await tester.pump();
    expect(engine.commands, ['isready']);
    // Simulate network initialization exceeding the previous search timeout.
    await tester.pump(const Duration(seconds: 8));
    expect(engine.commands, ['isready']);
    engine.output.add('readyok');
    await tester.pump();
    expect(engine.commands, [
      'isready',
      'setoption name Skill Level value 10',
      'position fen test-fen',
      'go movetime 650',
    ]);
    engine.output.add('bestmove e7e5 ponder g1f3');
    await tester.pump();
    await move;
    expect(result, 'e7e5');
    player.dispose();
    await engine.output.close();
  });

  testWidgets('hard difficulty configures a stronger, longer search', (
    tester,
  ) async {
    final engine = FakeEngine();
    final player = StockfishComputerPlayer(engineFactory: () async => engine);
    final move = player.bestMove(
      'test-fen',
      difficulty: ComputerDifficulty.hard,
    );
    await tester.pump();
    engine.output.add('readyok');
    await tester.pump();
    expect(engine.commands, [
      'isready',
      'setoption name Skill Level value 20',
      'position fen test-fen',
      'go movetime 2500',
    ]);
    engine.output.add('bestmove e7e5');
    await tester.pump();
    expect(await move, 'e7e5');
    player.dispose();
    await engine.output.close();
  });

  testWidgets('easy difficulty configures Stockfish skill level 5', (
    tester,
  ) async {
    final engine = FakeEngine();
    final player = StockfishComputerPlayer(engineFactory: () async => engine);
    final move = player.bestMove(
      'test-fen',
      difficulty: ComputerDifficulty.easy,
    );
    await tester.pump();
    engine.output.add('readyok');
    await tester.pump();
    expect(engine.commands, [
      'isready',
      'setoption name Skill Level value 5',
      'position fen test-fen',
      'go movetime 250',
    ]);
    engine.output.add('bestmove e7e5');
    await tester.pump();
    expect(await move, 'e7e5');
    player.dispose();
    await engine.output.close();
  });

  testWidgets('readiness timeout sends no search command', (tester) async {
    final engine = FakeEngine();
    final player = StockfishComputerPlayer(engineFactory: () async => engine);
    final check = expectLater(
      player.bestMove('test-fen'),
      throwsA(isA<TimeoutException>()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 31));
    await check;
    expect(engine.commands, ['isready']);
    player.dispose();
    await engine.output.close();
  });
}
