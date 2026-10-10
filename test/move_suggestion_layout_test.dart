// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/game_time_control.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/credits/credit_balance_chip.dart';
import 'package:battle_chess_arena/src/features/online/online_game_screen.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/move_suggestion_button_content.dart';
import 'package:battle_chess_arena/src/features/play/play_assist_style.dart';
import 'package:battle_chess_arena/src/features/play/threat_scan.dart';
import 'package:battle_chess_arena/src/services/game_history_storage.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auto_play_test.dart' show PendingAutoPlayer, TestMoveCommentary;
import 'support/online_fixtures.dart';

bool _fontLoaded = false;

Future<void> _loadFont(WidgetTester tester) async {
  if (_fontLoaded) return;
  await tester.runAsync(() async {
    final config = File('.dart_tool/package_config.json').absolute;
    final packages =
        jsonDecode(await config.readAsString()) as Map<String, dynamic>;
    final flutter = (packages['packages'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((package) => package['name'] == 'flutter');
    final root = config.uri.resolve('${flutter['rootUri']}/');
    final fonts = root.resolve('../../bin/cache/artifacts/material_fonts/');
    final loader = FontLoader('SuggestReviewRoboto');
    for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
      loader.addFont(
        File.fromUri(
          fonts.resolve(name),
        ).readAsBytes().then(ByteData.sublistView),
      );
    }
    await loader.load();
  });
  _fontLoaded = true;
}

RenderParagraph _paragraph(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)),
    );

Future<void> _shippingFont(WidgetTester tester) async {
  // Unspecified families use Android's Roboto in production and the test
  // runner's deliberately wide Ahem face here. Keep all shipping text styles
  // and their scale, replacing only that platform fallback for fit assertions.
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final span = paragraph.text;
    if (span is TextSpan && span.style?.fontFamily == null) {
      paragraph.text = TextSpan(
        text: span.text,
        children: span.children,
        style: (span.style ?? const TextStyle()).copyWith(
          fontFamily: 'SuggestReviewRoboto',
        ),
      );
    }
  }
  await tester.pump();
}

Future<void> _close(WidgetTester tester, OnlineMatchClient? client) async {
  await tester.pumpWidget(const SizedBox());
  client?.dispose();
  await tester.pump();
  var drained = false;
  GameHistoryStorage().loadSnapshot().then((_) => drained = true);
  for (var attempt = 0; !drained && attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(drained, isTrue);
}

void main() {
  final pack = piecePacks.singleWhere(
    (pack) => pack.id == PiecePackId.futuristic,
  );
  for (final online in [false, true]) {
    for (final size in [const Size(320, 568), const Size(650, 360)]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '${online ? 'Online' : 'Offline'} suggestion price sits beside aligned icons at $size / $scale',
          (tester) async {
            SharedPreferences.setMockInitialValues({});
            await tester.binding.setSurfaceSize(size);
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await _loadFont(tester);
            OnlineMatchClient? client;
            if (online) {
              final channel = FakeChannel();
              client = OnlineMatchClient(channelFactory: (_) => channel);
              await client.connect(Uri.parse('ws://localhost:8080'));
              channel.seat(state: stateJson(blackComputer: true, timed: false));
              await tester.pump();
            }
            try {
              await tester.pumpWidget(
                MaterialApp(
                  theme: ThemeData(fontFamily: 'SuggestReviewRoboto'),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: online
                      ? OnlineGameScreen(client: client!, pack: pack)
                      : AnimationLabScreen(
                          pack: pack,
                          mode: PlayerMode.computer,
                          timeControl: GameTimeControl.practice,
                          computerPlayer: PendingAutoPlayer(),
                          moveCommentary: TestMoveCommentary(),
                        ),
                ),
              );
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 150));
              await _shippingFont(tester);
              final suggest = find.byKey(
                ValueKey(
                  online
                      ? 'use-online-computer-lifeline'
                      : 'use-computer-lifeline',
                ),
              );
              final threat = find.byKey(const ValueKey('analyse-threats'));
              final icon = find.byType(MoveSuggestionActionIcon);
              final radar = find.byType(ThreatActionIcon);
              final price = find.byKey(
                ValueKey(
                  online
                      ? 'online-suggestion-credit-cost'
                      : 'computer-suggestion-credit-cost',
                ),
              );
              final name = find.text('Suggest move');
              expect(suggest.hitTestable(), findsOneWidget);
              expect(threat.hitTestable(), findsOneWidget);
              expect(tester.widget<Text>(price).data, '1 credit');
              expect(tester.getSize(icon), const Size(28, 28));
              expect(tester.getSize(icon), tester.getSize(radar));
              expect(
                tester.getCenter(icon).dy,
                closeTo(tester.getCenter(radar).dy, .01),
              );
              expect(
                tester.getRect(price).left,
                greaterThan(tester.getRect(icon).right),
              );
              expect(
                tester.getRect(price).left,
                closeTo(tester.getRect(name).left, .01),
              );
              expect(
                tester.getRect(price).top,
                greaterThan(tester.getRect(name).bottom),
              );
              expect(
                _paragraph(tester, name).didExceedMaxLines,
                isFalse,
                reason: 'The action name should wrap at the chosen text size.',
              );
              expect(
                _paragraph(tester, price).didExceedMaxLines,
                isFalse,
                reason: 'The complete price must fit without shrinking.',
              );
              expect(
                find.descendant(
                  of: suggest,
                  matching: find.byType(CreditCostBadge),
                ),
                findsNothing,
              );
              expect(
                find.descendant(of: suggest, matching: find.byType(FittedBox)),
                findsNothing,
              );
              final viewport = Offset.zero & size;
              expect(
                viewport.contains(tester.getRect(suggest).topLeft),
                isTrue,
              );
              expect(
                viewport.contains(tester.getRect(suggest).bottomRight),
                isTrue,
              );
              expect(
                viewport.contains(tester.getRect(threat).bottomRight),
                isTrue,
              );
              expect(
                viewport.contains(
                  tester.getRect(find.byType(ChessBoard)).bottomRight,
                ),
                isTrue,
              );
              expect(tester.takeException(), isNull);
            } finally {
              await _close(tester, client);
            }
          },
        );
      }
    }
  }

  testWidgets(
    'loading and changing prices leave action icons fixed and expose the cost',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final scan = ThreatScanController();
        addTearDown(scan.dispose);
        var loading = false;
        var cost = 1;
        late StateSetter rebuild;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 390,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      rebuild = setState;
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                style: playAssistButtonStyle,
                                onPressed: loading ? null : () {},
                                icon: MoveSuggestionActionIcon(
                                  loading: loading,
                                ),
                                label: MoveSuggestionLabel(cost: cost),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ThreatScanButton(
                                scan: scan,
                                enabled: !loading,
                                onScan: () {},
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        final initialIcon = tester.getRect(
          find.byType(MoveSuggestionActionIcon),
        );
        final initialRadar = tester.getRect(find.byType(ThreatActionIcon));
        expect(find.bySemanticsLabel(RegExp('Costs 1 credit')), findsOneWidget);
        rebuild(() {
          loading = true;
          cost = 2;
        });
        await tester.pump();
        expect(find.text('2 credits'), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('Costs 2 credits')),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          tester.getRect(find.byType(MoveSuggestionActionIcon)),
          initialIcon,
        );
        expect(tester.getRect(find.byType(ThreatActionIcon)), initialRadar);
        expect(
          tester
              .widget<FilledButton>(find.byType(FilledButton).first)
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        semantics.dispose();
      }
    },
  );
}
