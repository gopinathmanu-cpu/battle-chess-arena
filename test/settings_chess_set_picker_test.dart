import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/settings/game_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'settings has exactly four Classic styles and four Animated armies',
    (tester) async {
      final choices = <ChessSetSelection>[];
      final neon = availablePiecePacks.singleWhere(
        (pack) => pack.id == PiecePackId.futuristic,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SettingsChessSetPicker(
                animatedArena: true,
                pack: neon,
                classicStyle: ClassicPieceStyle.wood,
                onSelected: choices.add,
              ),
            ),
          ),
        ),
      );
      for (final style in ClassicPieceStyle.values) {
        final card = find.byKey(ValueKey('settings-classic-${style.name}'));
        expect(card, findsOneWidget);
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pump();
        expect(choices.last.animatedArena, isFalse);
        expect(choices.last.classicStyle, style);
        expect(choices.last.pack.id, neon.id);
      }
      for (final pack in availablePiecePacks) {
        final card = find.byKey(ValueKey('settings-animated-${pack.id.name}'));
        expect(card, findsOneWidget);
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pump();
        expect(choices.last.animatedArena, isTrue);
        expect(choices.last.classicStyle, ClassicPieceStyle.wood);
        expect(choices.last.pack.id, pack.id);
      }
      expect(choices.length, 8);
      expect(find.byType(CharacterPiece), findsNWidgets(16));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Animated family remains selected when its board uses Classic icons',
    (tester) async {
      final neon = availablePiecePacks.singleWhere(
        (pack) => pack.id == PiecePackId.futuristic,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SettingsChessSetPicker(
                animatedArena: true,
                pack: neon,
                classicStyle: ClassicPieceStyle.wood,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      final selected = tester.widgetList<Semantics>(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.selected == true,
        ),
      );
      expect(selected.length, 1);
      expect(
        selected.single.properties.label,
        contains('Animated set, Neon Dominion'),
      );
      final classic = find.ancestor(
        of: find.byKey(const ValueKey('settings-classic-wood')),
        matching: find.byType(Semantics),
      );
      expect(
        tester
            .widgetList<Semantics>(classic)
            .any((widget) => widget.properties.selected == true),
        isFalse,
      );
    },
  );

  testWidgets(
    'changing a family refreshes selection without changing callback data',
    (tester) async {
      var animated = true;
      var pack = availablePiecePacks.last;
      var style = ClassicPieceStyle.magneticTeaching;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => SingleChildScrollView(
                child: SettingsChessSetPicker(
                  animatedArena: animated,
                  pack: pack,
                  classicStyle: style,
                  onSelected: (choice) => update(() {
                    animated = choice.animatedArena;
                    pack = choice.pack;
                    style = choice.classicStyle;
                  }),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('settings-classic-metal')));
      await tester.pump();
      expect(animated, isFalse);
      expect(style, ClassicPieceStyle.metal);
      final greek = find.byKey(const ValueKey('settings-animated-greek'));
      await tester.ensureVisible(greek);
      await tester.tap(greek);
      await tester.pump();
      expect(animated, isTrue);
      expect(pack.id, PiecePackId.greek);
      expect(style, ClassicPieceStyle.metal);
    },
  );

  testWidgets(
    'all eight choices fit a narrow scrolling sheet with large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SettingsChessSetPicker(
                animatedArena: false,
                pack: availablePiecePacks.first,
                classicStyle: ClassicPieceStyle.wood,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      for (final pack in availablePiecePacks) {
        await tester.ensureVisible(
          find.byKey(ValueKey('settings-animated-${pack.id.name}')),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    },
  );
}
