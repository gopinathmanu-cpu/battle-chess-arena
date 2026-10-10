import 'package:battle_chess_arena/src/domain/online_credits.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/credits/arena_credit_header.dart';
import 'package:battle_chess_arena/src/services/arena_credit_controller.dart';
import 'package:battle_chess_arena/src/services/theme_music.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('header always renders and fits a compact scaled layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final controller = ArenaCreditController();

    await tester.pumpWidget(
      _AppHarness(
        controller: controller,
        textScaler: const TextScaler.linear(2),
      ),
    );

    expect(find.byKey(const ValueKey('arena-credit-header')), findsOneWidget);
    expect(find.text('Credits'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Credits, 300\\.')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('arena-credit-header'))).width,
      lessThanOrEqualTo(100),
    );
    semantics.dispose();
    expect(find.text('300'), findsOneWidget);
    expect(tester.takeException(), isNull);

    controller.dispose();
  });

  testWidgets('route header keeps the cached balance on pushed screens', (
    tester,
  ) async {
    final controller = ArenaCreditController();
    controller.acceptServerAccount(
      profileToken: 'header-player',
      account: _account(300),
      policy: defaultOnlineCreditPolicy,
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _AppHarness(controller: controller, navigatorKey: navigatorKey),
    );

    expect(find.byKey(const ValueKey('arena-credit-header')), findsOneWidget);
    expect(find.text('300'), findsOneWidget);

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(
          body: Column(children: [ArenaCreditHeader(), Text('Second route')]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Second route'), findsOneWidget);
    expect(find.byKey(const ValueKey('arena-credit-header')), findsOneWidget);
    expect(find.text('300'), findsOneWidget);

    controller.markDisconnected(profileToken: 'header-player');
    await tester.pump();
    expect(find.text('300'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('arena-credit-header-cached')),
      findsOneWidget,
    );

    controller.dispose();
  });

  testWidgets('deductions count down and additions receive celebration', (
    tester,
  ) async {
    final controller = ArenaCreditController();
    controller.acceptServerAccount(
      profileToken: 'animated-player',
      account: _account(300),
      policy: defaultOnlineCreditPolicy,
    );
    await tester.pumpWidget(_AppHarness(controller: controller));

    controller.acceptServerAccount(
      profileToken: 'animated-player',
      account: _account(298, transactionId: 'charge', delta: -2),
      policy: defaultOnlineCreditPolicy,
    );
    await tester.pump();
    expect(find.text('-2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.byKey(const ValueKey('arena-credit-deduction-pulse')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('298'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsNothing);

    controller.acceptServerAccount(
      profileToken: 'animated-player',
      account: _account(301, transactionId: 'daily', delta: 3),
      policy: defaultOnlineCreditPolicy,
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('+3'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsNWidgets(2));
    await tester.pumpAndSettle();
    expect(find.text('301'), findsOneWidget);

    final sequence = controller.lastChange?.sequence;
    controller.acceptServerAccount(
      profileToken: 'animated-player',
      account: _account(301, transactionId: 'daily', delta: 3),
      policy: defaultOnlineCreditPolicy,
    );
    await tester.pump();
    expect(controller.lastChange?.sequence, sequence);
    expect(find.byIcon(Icons.auto_awesome), findsNothing);

    controller.dispose();
  });

  testWidgets('reduced motion updates immediately without celebration', (
    tester,
  ) async {
    final controller = ArenaCreditController();
    controller.acceptServerAccount(
      profileToken: 'reduced-player',
      account: _account(300),
      policy: defaultOnlineCreditPolicy,
    );
    await tester.pumpWidget(
      _AppHarness(controller: controller, disableAnimations: true),
    );

    controller.acceptServerAccount(
      profileToken: 'reduced-player',
      account: _account(303, transactionId: 'allowance', delta: 3),
      policy: defaultOnlineCreditPolicy,
    );
    await tester.pump();

    expect(find.text('303'), findsOneWidget);
    expect(find.text('+3'), findsNothing);
    expect(find.byIcon(Icons.auto_awesome), findsNothing);

    controller.dispose();
  });

  testWidgets('only credit additions play the coin sound', (tester) async {
    final controller = ArenaCreditController();
    controller.acceptServerAccount(
      profileToken: 'sound-player',
      account: _account(300),
      policy: defaultOnlineCreditPolicy,
    );
    final output = _CreditSoundOutput();
    final music = ThemeMusic(output: output, saveMuted: (_) async {});
    await tester.pumpWidget(_AppHarness(controller: controller, music: music));

    controller.acceptServerAccount(
      profileToken: 'sound-player',
      account: _account(298, transactionId: 'spend', delta: -2),
      policy: defaultOnlineCreditPolicy,
    );
    await tester.pump();
    controller.acceptServerAccount(
      profileToken: 'sound-player',
      account: _account(301, transactionId: 'earn', delta: 3),
      policy: defaultOnlineCreditPolicy,
    );
    await tester.pump();

    expect(output.effects, [CinematicSound.creditCoin]);
    controller.dispose();
    music.dispose();
  });

  for (final width in [320.0, 390.0]) {
    for (final compact in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'compact credit counter stays fixed width=$width compact=$compact scale=$scale',
          (tester) async {
            tester.view.physicalSize = Size(width, 640);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final semantics = tester.ensureSemantics();
            final controller = ArenaCreditController();
            controller.acceptServerAccount(
              profileToken: 'stable-player',
              account: _account(100),
              policy: defaultOnlineCreditPolicy,
            );
            await tester.pumpWidget(
              _AppHarness(
                controller: controller,
                compact: compact,
                neighbour: true,
                textScaler: TextScaler.linear(scale),
              ),
            );
            final keys = [
              'arena-credit-header',
              'arena-credit-header-balance',
              'arena-credit-header-amount-slot',
              'arena-credit-header-neighbour',
              'arena-credit-delta-slot',
            ];
            final before = {
              for (final key in keys)
                key: tester.getRect(find.byKey(ValueKey(key))),
            };
            expect(
              before['arena-credit-header']!.width,
              lessThanOrEqualTo(100),
            );
            expect(
              before['arena-credit-header']!.right,
              lessThanOrEqualTo(width),
            );
            void expectStable() {
              for (final key in keys) {
                expect(
                  tester.getRect(find.byKey(ValueKey(key))),
                  before[key],
                  reason: '$key must stay fixed throughout the credit change',
                );
              }
              expect(tester.takeException(), isNull);
            }

            for (final change in [(99, -1), (9, -90), (999999, 999990)]) {
              controller.acceptServerAccount(
                profileToken: 'stable-player',
                account: _account(
                  change.$1,
                  transactionId: 'change-${change.$1}',
                  delta: change.$2,
                ),
                policy: defaultOnlineCreditPolicy,
              );
              await tester.pump();
              expectStable();
              await tester.pump(const Duration(milliseconds: 250));
              expectStable();
              await tester.pumpAndSettle();
              expectStable();
              expect(find.text('${change.$1}'), findsOneWidget);
              expect(
                find.bySemanticsLabel(RegExp('Credits, ${change.$1}\\.')),
                findsOneWidget,
              );
            }
            controller.markDisconnected(profileToken: 'stable-player');
            await tester.pump();
            expectStable();
            expect(
              find.byKey(const ValueKey('arena-credit-header-cached')),
              findsOneWidget,
            );
            await tester.pumpWidget(const SizedBox());
            controller.dispose();
            semantics.dispose();
          },
        );
      }
    }
  }
}

class _AppHarness extends StatelessWidget {
  const _AppHarness({
    required this.controller,
    this.navigatorKey,
    this.disableAnimations = false,
    this.textScaler,
    this.music,
    this.compact = false,
    this.neighbour = false,
  });

  final ArenaCreditController controller;
  final GlobalKey<NavigatorState>? navigatorKey;
  final bool disableAnimations;
  final TextScaler? textScaler;
  final ThemeMusic? music;
  final bool compact;
  final bool neighbour;

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigatorKey,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: disableAnimations, textScaler: textScaler),
      child: _withMusic(
        ArenaCreditScope(controller: controller, child: child!),
      ),
    ),
    home: Scaffold(
      body: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ArenaCreditHeader(compact: compact),
              if (neighbour)
                const Icon(
                  Icons.settings,
                  key: ValueKey('arena-credit-header-neighbour'),
                ),
            ],
          ),
          const Text('Home route'),
        ],
      ),
    ),
  );

  Widget _withMusic(Widget child) {
    final controller = music;
    return controller == null
        ? child
        : MusicScope(controller: controller, child: child);
  }
}

class _CreditSoundOutput implements MusicOutput {
  final effects = <CinematicSound>[];

  @override
  Future<void> play(
    PiecePackId theme, {
    BackgroundMusic selection = BackgroundMusic.theme,
  }) async {}

  @override
  Future<void> playEffect(CinematicSound effect) async => effects.add(effect);

  @override
  Future<void> pause() async {}

  @override
  Future<void> dispose() async {}
}

OnlineCreditAccount _account(
  int credits, {
  String? transactionId,
  int? delta,
}) => OnlineCreditAccount(
  credits: credits,
  bonusCredits: credits,
  purchasedCredits: 0,
  recentTransactions: transactionId == null
      ? const []
      : [
          OnlineCreditTransaction(
            transactionId: transactionId,
            delta: delta!,
            type: delta > 0 ? 'reward' : 'round_fee',
            reason: delta > 0
                ? 'meaningful_round_completed'
                : 'live_human_round',
            createdAt: DateTime.utc(2026, 9, 26, 9),
          ),
        ],
);
