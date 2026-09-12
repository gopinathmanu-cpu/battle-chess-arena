// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for authoritative client state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  test(
    'two real Flutter clients play against Node, resume, draw, rematch and checkmate',
    () async {
      final server = await Process.start(
        'node',
        ['src/index.js'],
        workingDirectory: 'server',
        environment: {'PORT': '0'},
      );
      addTearDown(() async {
        server.kill();
        await server.exitCode;
      });
      final output = server.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      final port = int.parse(
        (await output.first.timeout(
          const Duration(seconds: 5),
        )).split(':').last,
      );
      final stderr = server.stderr
          .transform(utf8.decoder)
          .listen((line) => fail('Server error: $line'));
      addTearDown(stderr.cancel);
      final uri = Uri.parse('ws://127.0.0.1:$port');
      final white = OnlineMatchClient();
      final black = OnlineMatchClient();
      addTearDown(white.dispose);
      addTearDown(black.dispose);
      await white.connect(uri);
      await black.connect(uri);
      white.createGame();
      await waitFor(() => white.gameId != null);
      black.joinGame(white.gameId!);
      await waitFor(
        () =>
            white.state?.status == 'active' && black.state?.status == 'active',
      );
      var captures = 0;
      var lastCapture = -1;
      black.addListener(() {
        if (black.session.captureSequence != lastCapture &&
            black.session.committedCapture != null) {
          lastCapture = black.session.captureSequence;
          captures++;
        }
      });
      for (final entry in [
        (white, Square.e2, Square.e4),
        (black, Square.d7, Square.d5),
        (white, Square.e4, Square.d5),
      ]) {
        final ply = white.state!.san.length;
        entry.$1.requestMove(from: entry.$2, to: entry.$3);
        await waitFor(
          () =>
              white.state!.san.length == ply + 1 &&
              black.state!.san.length == ply + 1 &&
              !entry.$1.busy,
        );
        expect(white.state!.fen, black.state!.fen);
      }
      expect(captures, 1);
      final previousSequence = white.state!.sequence;
      await white.disconnect();
      await white.reconnect();
      await waitFor(
        () => white.connected && white.state!.sequence > previousSequence,
      );
      expect(white.state!.san, ['e4', 'd5', 'exd5']);
      white.offerDraw();
      await waitFor(() => black.state!.drawOfferId != null && !white.busy);
      black.respondDraw(true);
      await waitFor(
        () =>
            white.state!.status == 'complete' &&
            black.state!.status == 'complete' &&
            !black.busy,
      );
      expect(white.state!.resultReason, 'agreement');
      white.requestRematch();
      await waitFor(() => !white.busy);
      black.requestRematch();
      await waitFor(
        () => white.state!.round == 2 && black.state!.round == 2 && !black.busy,
      );
      for (final entry in [
        (white, Square.f2, Square.f3),
        (black, Square.e7, Square.e5),
        (white, Square.g2, Square.g4),
        (black, Square.d8, Square.h4),
      ]) {
        final ply = white.state!.san.length;
        entry.$1.requestMove(from: entry.$2, to: entry.$3);
        await waitFor(
          () =>
              white.state!.san.length == ply + 1 &&
              black.state!.san.length == ply + 1 &&
              !entry.$1.busy,
        );
      }
      expect(white.state!.resultReason, 'checkmate');
      expect(black.state!.winner, 'b');
      expect(white.state!.fen, black.state!.fen);
    },
  );
}
