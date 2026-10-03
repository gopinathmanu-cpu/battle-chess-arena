import 'dart:convert';
import 'dart:ui';

import 'package:battle_chess_arena/src/services/app_diagnostics.dart';
import 'package:battle_chess_arena/src/services/beta_app_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'diagnostics persist source, mode and safe frames but no error content',
    () async {
      final diagnostics = AppDiagnostics();
      await diagnostics.initialize();
      diagnostics.mode = DiagnosticMode.online;
      diagnostics.record(
        DiagnosticSource.asynchronous,
        StateError(
          'seatToken=private-token playerToken=private-player alice@example.com',
        ),
        StackTrace.fromString(
          '#0 example (package:battle_chess_arena/src/app.dart:12:4)\n#1 (https://host/?token=private-token)\n#2 /Users/private/person/file.dart:99:1',
        ),
      );
      await diagnostics.flush();
      final prefs = await SharedPreferences.getInstance();
      final serialized = prefs.getString(AppDiagnostics.storageKey)!;
      expect(serialized, contains('StateError'));
      expect(serialized, contains('online'));
      expect(serialized, contains('app.dart:12:4'));
      for (final secret in [
        'private-token',
        'private-player',
        'alice@',
        '/Users/',
        'https://',
      ]) {
        expect(serialized, isNot(contains(secret)));
      }
      final reloaded = AppDiagnostics();
      await reloaded.initialize();
      expect(reloaded.export(), diagnostics.export());
      expect(reloaded.eventCount, 1);
    },
  );

  test(
    'bounded records, disable, clear and restart leave game data alone',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bot_tournament_beginner-cup-v1', 'saved-points');
      final diagnostics = AppDiagnostics();
      await diagnostics.initialize();
      for (var i = 0; i < 45; i++) {
        diagnostics.record(
          DiagnosticSource.engineFallback,
          StateError('private $i'),
        );
      }
      await diagnostics.flush();
      expect(diagnostics.eventCount, 30);
      expect(
        jsonDecode(prefs.getString(AppDiagnostics.storageKey)!) as List,
        hasLength(30),
      );
      await diagnostics.clear();
      expect(diagnostics.eventCount, 0);
      expect(prefs.containsKey(AppDiagnostics.storageKey), isFalse);
      diagnostics.record(DiagnosticSource.startup, StateError('private'));
      await diagnostics.setEnabled(false);
      diagnostics.record(DiagnosticSource.startup, StateError('still private'));
      await diagnostics.flush();
      final reloaded = AppDiagnostics();
      await reloaded.initialize();
      expect(reloaded.enabled, isFalse);
      expect(reloaded.eventCount, 0);
      expect(prefs.containsKey(AppDiagnostics.storageKey), isFalse);
      expect(prefs.getString('bot_tournament_beginner-cup-v1'), 'saved-points');
      await reloaded.setEnabled(true);
      reloaded.record(DiagnosticSource.startup, StateError('new'));
      await reloaded.flush();
      expect(reloaded.eventCount, 1);
    },
  );

  test('malformed diagnostics do not block startup or touch saves', () async {
    SharedPreferences.setMockInitialValues({
      AppDiagnostics.storageKey: 'broken',
      'saved_game': 'keep',
    });
    final diagnostics = AppDiagnostics();
    await diagnostics.initialize();
    expect(diagnostics.eventCount, 0);
    expect(diagnostics.storageAvailable, isTrue);
    expect(
      (await SharedPreferences.getInstance()).getString('saved_game'),
      'keep',
    );
  });

  test(
    'framework and asynchronous hooks record and restore their predecessors',
    () async {
      final diagnostics = AppDiagnostics();
      await diagnostics.initialize();
      final originalFlutter = FlutterError.onError;
      final originalAsync = PlatformDispatcher.instance.onError;
      var forwarded = 0;
      FlutterError.onError = (_) => forwarded++;
      PlatformDispatcher.instance.onError = (_, __) {
        forwarded++;
        return true;
      };
      final restore = diagnostics.installErrorHandlers();
      try {
        FlutterError.onError!(
          FlutterErrorDetails(exception: StateError('private')),
        );
        expect(
          PlatformDispatcher.instance.onError!(
            StateError('private'),
            StackTrace.current,
          ),
          isTrue,
        );
        await diagnostics.flush();
        expect(diagnostics.eventCount, 2);
        expect(forwarded, 2);
        restore();
        FlutterError.onError!(
          FlutterErrorDetails(exception: StateError('not captured')),
        );
        expect(diagnostics.eventCount, 2);
        expect(forwarded, 3);
      } finally {
        restore();
        FlutterError.onError = originalFlutter;
        PlatformDispatcher.instance.onError = originalAsync;
      }
    },
  );

  test(
    'native metadata uses installed values and handles unavailable channels',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(BetaAppInfo.channel, (call) async {
        expect(call.method, 'getAppInfo');
        return {
          'version': '0.9.0-beta.2',
          'build': '2017',
          'platform': 'Android 16',
          'device': 'Test phone',
          'architecture': 'arm64-v8a',
        };
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(BetaAppInfo.channel, null),
      );
      expect(
        (await BetaAppInfo.load()).summary,
        contains('0.9.0-beta.2 (2017)'),
      );
      messenger.setMockMethodCallHandler(
        BetaAppInfo.channel,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      expect((await BetaAppInfo.load()).version, 'Unavailable');
    },
  );

  testWidgets('navigation diagnostics restore game mode after pop', (
    tester,
  ) async {
    final diagnostics = AppDiagnostics();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [DiagnosticNavigationObserver(diagnostics)],
        home: const SizedBox(),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(
          name: '/online',
          arguments: 'private token',
        ),
        builder: (_) => const SizedBox(),
      ),
    );
    await tester.pumpAndSettle();
    expect(diagnostics.mode, DiagnosticMode.online);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(diagnostics.mode, DiagnosticMode.home);
    expect(diagnostics.export(), isNot(contains('private')));
    await tester.pumpWidget(const SizedBox());
  });
}
