import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/services/move_commentary.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('move commentary text', () {
    test('describes the real side, role and route for both players', () {
      final game = GameSession();
      expect(
        moveCommentaryText(game.playUci('g1f3')!),
        'White knight moves from g1 to f3.',
      );
      expect(
        moveCommentaryText(game.playUci('e7e5')!),
        'Black pawn moves from e7 to e5.',
      );
    });

    test('announces the actual captured roles and colors', () {
      final game = GameSession.fromMoves(moves: ['e2e4', 'd7d5']);
      expect(
        moveCommentaryText(game.playUci('e4d5')!),
        'White pawn moves from e4 to d5, capturing a black pawn.',
      );
      expect(
        moveCommentaryText(game.playUci('d8d5')!),
        'Black queen moves from d8 to d5, capturing a white pawn.',
      );
    });

    test('en passant describes the committed pawn capture', () {
      final game = GameSession.fromMoves(
        moves: ['e2e4', 'a7a6', 'e4e5', 'd7d5'],
      );
      expect(
        moveCommentaryText(game.playUci('e5d6')!),
        'White pawn moves from e5 to d6, capturing a black pawn.',
      );
    });

    test(
      'castling uses the king and rook destinations rather than engine UCI',
      () {
        final white = GameSession(
          position: Chess.fromSetup(
            Setup.parseFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1'),
          ),
        );
        final black = GameSession(
          position: Chess.fromSetup(
            Setup.parseFen('r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 0 1'),
          ),
        );
        expect(
          moveCommentaryText(white.playUci('e1g1')!),
          'White castles kingside, moving the king from e1 to g1 '
          'and the rook from h1 to f1.',
        );
        expect(
          moveCommentaryText(black.playUci('e8c8')!),
          'Black castles queenside, moving the king from e8 to c8 '
          'and the rook from a8 to d8.',
        );
      },
    );

    test('underpromotion announces the chosen role and the captured piece', () {
      final game = GameSession(
        position: Chess.fromSetup(
          Setup.parseFen('k6r/6P1/8/8/8/8/8/K7 w - - 0 1'),
        ),
      );
      expect(
        moveCommentaryText(game.playUci('g7h8n')!),
        'White pawn moves from g7 to h8, capturing a black rook '
        'and promotes to a knight.',
      );
    });

    test('check is distinct from checkmate and the winner is accurate', () {
      final checked = GameSession.fromMoves(moves: ['e2e4', 'f7f6']);
      expect(
        moveCommentaryText(checked.playUci('d1h5')!),
        'White queen moves from d1 to h5. Check.',
      );
      final mated = GameSession.fromMoves(moves: ['f2f3', 'e7e5', 'g2g4']);
      expect(
        moveCommentaryText(mated.playUci('d8h4')!),
        'Black queen moves from d8 to h4. Checkmate. Black wins.',
      );
    });
  });

  group('native move commentary', () {
    const channel = MethodChannel('test/move_commentary');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test(
      'forwards narration, stop, and disposal without speaking after disposal',
      () async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
        final commentary = NativeMoveCommentary(
          channel: channel,
          platform: TargetPlatform.android,
        );
        expect(commentary.isSupported, isTrue);
        await commentary.speak('  White pawn moves from e2 to e4.  ');
        await commentary.stop();
        await commentary.speak(' ');
        await commentary.dispose();
        await commentary.speak('Black pawn moves from e7 to e5.');
        await commentary.stop();
        await commentary.dispose();

        expect(calls.map((call) => call.method), ['speak', 'stop', 'dispose']);
        expect(calls.first.arguments, {
          'text': 'White pawn moves from e2 to e4.',
        });
      },
    );

    test('unsupported platforms do not call a native speech bridge', () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        return null;
      });
      for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
        final commentary = NativeMoveCommentary(
          channel: channel,
          platform: platform,
        );
        expect(commentary.isSupported, isFalse);
        await commentary.speak('White knight moves from g1 to f3.');
        await commentary.stop();
        await commentary.dispose();
      }
      expect(calls, 0);
    });

    test(
      'missing plugins and speech errors do not interrupt the game',
      () async {
        for (final missingPlugin in [false, true]) {
          messenger.setMockMethodCallHandler(channel, (call) async {
            if (missingPlugin) throw MissingPluginException();
            throw PlatformException(code: 'commentary_unavailable');
          });
          final commentary = NativeMoveCommentary(
            channel: channel,
            platform: TargetPlatform.android,
          );
          await expectLater(commentary.speak('White pawn moves.'), completes);
          await expectLater(commentary.stop(), completes);
          await expectLater(commentary.dispose(), completes);
        }
      },
    );
  });
}
