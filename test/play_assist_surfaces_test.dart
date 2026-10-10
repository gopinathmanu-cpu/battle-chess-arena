// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:battle_chess_arena/src/domain/capture_threat.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/play/captured_pieces_panel.dart';
import 'package:battle_chess_arena/src/features/play/play_assist_style.dart';
import 'package:battle_chess_arena/src/features/play/threat_scan.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return first > second
      ? (first + .05) / (second + .05)
      : (second + .05) / (first + .05);
}

Color _buttonSurface(WidgetTester tester, Finder button) => tester
    .widgetList<Material>(
      find.descendant(of: button, matching: find.byType(Material)),
    )
    .singleWhere((material) => material.type == MaterialType.button)
    .color!;

Color _labelInk(WidgetTester tester, String label) => tester
    .renderObject<RenderParagraph>(
      find.descendant(of: find.text(label), matching: find.byType(RichText)),
    )
    .text
    .style!
    .color!;

final _victims = [
  for (final side in Side.values)
    for (final role in Role.values.where((role) => role != Role.king))
      Piece(color: side, role: role),
];

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      '$brightness assist surfaces retain contrast during loading and scan stop',
      (tester) async {
        final scan = ThreatScanController();
        var loading = false;
        var suggestions = 0;
        late StateSetter rebuild;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: brightness,
              colorSchemeSeed: Colors.yellow,
            ),
            home: Scaffold(
              body: Center(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    rebuild = setState;
                    return SizedBox(
                      width: 320,
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              key: const ValueKey('suggest'),
                              style: playAssistButtonStyle,
                              onPressed: loading ? null : () => suggestions++,
                              icon: loading
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const MoveSuggestionIcon(size: 18),
                              label: const Text('Suggest move'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ListenableBuilder(
                              listenable: scan,
                              builder: (context, _) => ThreatScanButton(
                                scan: scan,
                                enabled: !loading,
                                onScan: () => scan.start(
                                  immediateCaptureThreats(
                                    Chess.fromSetup(
                                      Setup.parseFen(
                                        'r6k/8/2b5/3P4/Q7/8/8/6K1 w - - 0 1',
                                      ),
                                    ),
                                    defender: Side.white,
                                  ),
                                  reducedMotion: true,
                                ),
                              ),
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
        );
        final suggest = find.byKey(const ValueKey('suggest'));
        final threat = find.byKey(const ValueKey('analyse-threats'));
        for (final (button, label) in [
          (suggest, 'Suggest move'),
          (threat, 'Threat scan'),
        ]) {
          expect(
            _contrast(_labelInk(tester, label), _buttonSurface(tester, button)),
            greaterThanOrEqualTo(4.5),
          );
        }
        await tester.tap(suggest);
        expect(suggestions, 1);
        await tester.tap(threat);
        await tester.pump();
        expect(scan.active, isTrue);
        expect(find.text('Stop scan'), findsOneWidget);
        expect(
          _contrast(
            _labelInk(tester, 'Stop scan'),
            _buttonSurface(tester, threat),
          ),
          greaterThanOrEqualTo(4.5),
        );
        rebuild(() => loading = true);
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.widget<FilledButton>(suggest).onPressed, isNull);
        final spinnerContext = tester.element(
          find.byType(CircularProgressIndicator),
        );
        expect(
          _contrast(
            ProgressIndicatorTheme.of(spinnerContext).color!,
            _buttonSurface(tester, suggest),
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(
            _labelInk(tester, 'Suggest move'),
            _buttonSurface(tester, suggest),
          ),
          greaterThanOrEqualTo(4.5),
        );
        // A running scan stays stoppable while other input is disabled.
        await tester.tap(threat);
        await tester.pump();
        expect(scan.active, isFalse);
        expect(tester.widget<FilledButton>(threat).onPressed, isNull);
        expect(suggestions, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        scan.dispose();
      },
    );
  }

  for (final pack in availablePiecePacks) {
    for (final standard in [false, true]) {
      testWidgets(
        '${pack.name} captured figures retain both sides on neutral tiles (${standard ? 'Classic' : 'Animated'})',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 568));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final appearance = BoardAppearance(
            white: pack,
            black: pack,
            board: pack,
            standardPieces: standard,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: CapturedPiecesPanel(
                    pieces: _victims,
                    appearance: appearance,
                    playerSide: Side.black,
                  ),
                ),
              ),
            ),
          );
          final figures = tester.widgetList<CharacterPiece>(
            find.byType(CharacterPiece),
          );
          expect(
            figures.map((figure) => figure.piece).toSet(),
            _victims.toSet(),
          );
          expect(
            figures.every(
              (figure) =>
                  figure.standard == standard && figure.pack.id == pack.id,
            ),
            isTrue,
          );
          expect(find.text('You captured · 5'), findsOneWidget);
          expect(find.text('Opponent captured · 5'), findsOneWidget);
          for (final side in Side.values) {
            for (var index = 0; index < 5; index++) {
              final tile = tester.widget<DecoratedBox>(
                find.byKey(ValueKey('captured-tile-${side.name}-$index')),
              );
              final decoration = tile.decoration as BoxDecoration;
              expect(
                _contrast(Colors.white, decoration.color!),
                greaterThanOrEqualTo(3),
              );
              expect(
                _contrast(const Color(0xFF101018), decoration.color!),
                greaterThanOrEqualTo(4.5),
              );
              expect(decoration.color!.b, greaterThan(decoration.color!.r));
              expect(decoration.border, isNotNull);
              if (side == Side.black) expect(decoration.boxShadow, isNotEmpty);
            }
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
