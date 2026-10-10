import 'dart:async';

import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockfish/stockfish.dart';

class FakeEngine implements Stockfish {
  FakeEngine({this.eloRange = (1320, 3190)});
  final (int, int)? eloRange;
  final commands = <String>[];
  final output = StreamController<String>.broadcast();
  @override
  final state = ValueNotifier(StockfishState.ready);
  @override
  Completer<Stockfish>? get completer => null;
  @override
  Stream<String> get stdout => output.stream;
  @override
  set stdin(String command) {
    commands.add(command);
    if (command == 'uci') {
      if (eloRange case final range?) {
        output.add('option name UCI_LimitStrength type check default false');
        output.add(
          'option name UCI_Elo type spin default ${range.$1} '
          'min ${range.$1} max ${range.$2}',
        );
      }
      output.add('uciok');
    }
  }

  @override
  void dispose() => commands.add('quit');
}

void main() {
  testWidgets(
    'assistance removes a prior Elo cap and requests full strongest search',
    (tester) async {
      final engine = FakeEngine();
      final player = StockfishComputerPlayer(engineFactory: () async => engine);
      final medium = player.bestMove('test-fen');
      await tester.pump();
      engine.output.add('readyok');
      await tester.pump();
      expect(engine.commands, contains('setoption name UCI_Elo value 1400'));
      engine.output.add('bestmove e7e5');
      await tester.pump();
      expect(await medium, 'e7e5');

      final start = engine.commands.length;
      final assisted = player.bestAssistanceMove('assisted-fen');
      await tester.pump();
      engine.output.add('readyok');
      await tester.pump();
      expect(engine.commands.skip(start).toList(), [
        'isready',
        'setoption name UCI_LimitStrength value false',
        'setoption name Skill Level value 20',
        'ucinewgame',
        'position fen assisted-fen',
        'go depth 18 movetime 2625',
      ]);
      engine.output.add('bestmove g1f3');
      await tester.pump();
      expect(await assisted, 'g1f3');

      // Assistance must not leave the ordinary opponent at maximum strength.
      final next = engine.commands.length;
      final easy = player.bestMove(
        'opponent-fen',
        difficulty: ComputerDifficulty.easy,
      );
      await tester.pump();
      engine.output.add('readyok');
      await tester.pump();
      expect(engine.commands.skip(next).toList(), [
        'isready',
        'setoption name UCI_LimitStrength value false',
        'setoption name Skill Level value 0',
        'ucinewgame',
        'position fen opponent-fen',
        'go depth 2 movetime 250',
      ]);
      engine.output.add('bestmove e7e5');
      await tester.pump();
      expect(await easy, 'e7e5');
      player.dispose();
      await engine.output.close();
    },
  );

  testWidgets(
    'all fixed bot levels override user difficulty and disable Elo caps',
    (tester) async {
      final engine = FakeEngine();
      final player = StockfishComputerPlayer(engineFactory: () async => engine);
      for (var level = 1; level <= 20; level++) {
        List<String>? expected;
        for (final difficulty in ComputerDifficulty.values) {
          final start = engine.commands.length;
          final move = player.bestMove(
            'test-fen',
            difficulty: difficulty,
            botLevel: level,
          );
          await tester.pump();
          engine.output.add('readyok');
          await tester.pump();
          final searchCommands = engine.commands
              .skip(start)
              .where((c) => c != 'uci' && c != 'isready')
              .toList();
          expected ??= searchCommands;
          expect(searchCommands, expected);
          expect(
            searchCommands,
            contains('setoption name UCI_LimitStrength value false'),
          );
          expect(
            searchCommands,
            contains(
              'setoption name Skill Level value ${BotStrength(level).stockfishSkill}',
            ),
          );
          expect(
            searchCommands.last,
            'go depth ${BotStrength(level).depth} movetime ${BotStrength(level).thinkTime.inMilliseconds}',
          );
          engine.output.add('bestmove e7e5');
          await tester.pump();
          expect(await move, 'e7e5');
        }
      }
      player.dispose();
      await engine.output.close();
    },
  );

  testWidgets('waits for native readiness before starting search', (
    tester,
  ) async {
    final engine = FakeEngine();
    final player = StockfishComputerPlayer(engineFactory: () async => engine);
    String? result;
    final move = player.bestMove('test-fen').then((value) => result = value);
    await tester.pump();
    expect(engine.commands, ['uci', 'isready']);
    // Simulate network initialization exceeding the previous search timeout.
    await tester.pump(const Duration(seconds: 8));
    expect(engine.commands, ['uci', 'isready']);
    engine.output.add('readyok');
    await tester.pump();
    expect(engine.commands, [
      'uci',
      'isready',
      'setoption name UCI_LimitStrength value true',
      'setoption name UCI_Elo value 1400',
      'setoption name Skill Level value 6',
      'ucinewgame',
      'position fen test-fen',
      'go depth 7 movetime 650',
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
      'uci',
      'isready',
      'setoption name UCI_LimitStrength value true',
      'setoption name UCI_Elo value 2500',
      'setoption name Skill Level value 20',
      'ucinewgame',
      'position fen test-fen',
      'go depth 18 movetime 2500',
    ]);
    engine.output.add('bestmove e7e5');
    await tester.pump();
    expect(await move, 'e7e5');
    player.dispose();
    await engine.output.close();
  });

  testWidgets('unsupported Easy Elo uses skill 0 without clamping upwards', (
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
      'uci',
      'isready',
      'setoption name UCI_LimitStrength value false',
      'setoption name Skill Level value 0',
      'ucinewgame',
      'position fen test-fen',
      'go depth 2 movetime 250',
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
    expect(engine.commands, ['uci', 'isready']);
    player.dispose();
    await engine.output.close();
  });

  testWidgets('changing Hard to Easy disables Elo and clears search history', (
    tester,
  ) async {
    final engine = FakeEngine();
    final player = StockfishComputerPlayer(engineFactory: () async => engine);
    for (final difficulty in [
      ComputerDifficulty.hard,
      ComputerDifficulty.easy,
    ]) {
      final move = player.bestMove('test-fen', difficulty: difficulty);
      await tester.pump();
      engine.output.add('readyok');
      await tester.pump();
      engine.output.add('bestmove e7e5');
      await tester.pump();
      expect(await move, 'e7e5');
    }
    expect(engine.commands.where((c) => c == 'uci'), hasLength(1));
    expect(engine.commands.sublist(engine.commands.length - 6), [
      'isready',
      'setoption name UCI_LimitStrength value false',
      'setoption name Skill Level value 0',
      'ucinewgame',
      'position fen test-fen',
      'go depth 2 movetime 250',
    ]);
    player.dispose();
    await engine.output.close();
  });

  for (final eloRange in <(int, int)?>[null, (1500, 2800), (600, 3000)]) {
    testWidgets('negotiates advertised Elo support $eloRange', (tester) async {
      final engine = FakeEngine(eloRange: eloRange);
      final player = StockfishComputerPlayer(engineFactory: () async => engine);
      final move = player.bestMove(
        'test-fen',
        difficulty: ComputerDifficulty.easy,
      );
      await tester.pump();
      engine.output.add('readyok');
      await tester.pump();
      final canLimitEasy = eloRange != null && eloRange.$1 <= 800;
      expect(
        engine.commands.contains('setoption name UCI_Elo value 800'),
        canLimitEasy,
      );
      expect(
        engine.commands.contains('setoption name Skill Level value 0'),
        true,
      );
      if (eloRange == null) {
        expect(
          engine.commands.where((c) => c.contains('UCI_LimitStrength')),
          isEmpty,
        );
      }
      engine.output.add('bestmove e7e5');
      await tester.pump();
      expect(await move, 'e7e5');
      player.dispose();
      await engine.output.close();
    });
  }
}
