import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/online/online_game_screen.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/captured_pieces_panel.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/play_assist_style.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/online_fixtures.dart';

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return first > second
      ? (first + .05) / (second + .05)
      : (second + .05) / (first + .05);
}

void main() {
  for (final online in [false, true]) {
    for (final (width, scale) in [
      (390.0, 1.0),
      (320.0, 1.0),
      (320.0, 1.5),
      (320.0, 2.0),
    ]) {
      testWidgets(
        '${online ? 'Online' : 'Computer'} assist fonts match at $width / $scale',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          await tester.binding.setSurfaceSize(Size(width, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          OnlineMatchClient? client;
          if (online) {
            final channel = FakeChannel();
            client = OnlineMatchClient(channelFactory: (_) => channel);
            await client.connect(Uri.parse('ws://localhost:8080'));
            channel.seat(state: stateJson(blackComputer: true));
            await tester.pump();
          }
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: online
                  ? OnlineGameScreen(client: client!, pack: piecePacks.first)
                  : AnimationLabScreen(
                      pack: piecePacks.first,
                      mode: PlayerMode.computer,
                    ),
            ),
          );
          await tester.pump();
          final suggest = find.byKey(
            ValueKey(
              online ? 'use-online-computer-lifeline' : 'use-computer-lifeline',
            ),
          );
          final threat = find.byKey(const ValueKey('analyse-threats'));
          expect(suggest.hitTestable(), findsOneWidget);
          expect(threat.hitTestable(), findsOneWidget);
          RenderParagraph paragraph(String text) =>
              tester.renderObject<RenderParagraph>(
                find.descendant(
                  of: find.text(text),
                  matching: find.byType(RichText),
                ),
              );
          final suggestText = paragraph('Suggest move');
          final threatText = paragraph('Threat scan');
          expect(suggestText.text.style?.fontSize, 14);
          expect(
            threatText.text.style?.fontSize,
            suggestText.text.style?.fontSize,
          );
          expect(
            threatText.text.style?.fontWeight,
            suggestText.text.style?.fontWeight,
          );
          expect(suggestText.textScaler.scale(14), 14 * scale);
          expect(threatText.textScaler.scale(14), 14 * scale);
          for (final (button, label) in [
            (suggest, suggestText),
            (threat, threatText),
          ]) {
            final surface = tester
                .widgetList<Material>(
                  find.descendant(of: button, matching: find.byType(Material)),
                )
                .singleWhere(
                  (material) => material.type == MaterialType.button,
                );
            expect(
              _contrast(label.text.style!.color!, surface.color!),
              greaterThanOrEqualTo(4.5),
            );
            expect(surface.color!.b, greaterThan(surface.color!.r));
          }
          final price = find.byKey(
            ValueKey(
              online
                  ? 'online-suggestion-credit-cost'
                  : 'computer-suggestion-credit-cost',
            ),
          );
          expect(price, findsOneWidget);
          expect(tester.widget<Text>(price).data, '1 credit');
          final priceText = tester.renderObject<RenderParagraph>(
            find.descendant(of: price, matching: find.byType(RichText)),
          );
          final buttonSurface = tester
              .widgetList<Material>(
                find.descendant(of: suggest, matching: find.byType(Material)),
              )
              .singleWhere((material) => material.type == MaterialType.button);
          expect(
            _contrast(priceText.text.style!.color!, buttonSurface.color!),
            greaterThanOrEqualTo(4.5),
            reason:
                'The complete suggestion price must remain readable beside its icon.',
          );
          expect(
            find.ancestor(of: price, matching: find.byType(FittedBox)),
            findsNothing,
          );
          expect(
            find.ancestor(
              of: find.text('Suggest move'),
              matching: find.byType(FittedBox),
            ),
            findsNothing,
          );
          expect(tester.getSize(suggest).height, tester.getSize(threat).height);
          final initialAssistBottom = tester.getRect(suggest).bottom;
          expect(
            tester.getRect(find.byType(ChessBoard)).bottom,
            lessThanOrEqualTo(tester.getRect(suggest).top),
          );
          expect(
            tester.getRect(find.byType(ChessBoard)).bottom,
            lessThanOrEqualTo(tester.getRect(threat).top),
          );
          final suggestIcon = tester.widget<Icon>(
            find.descendant(
              of: suggest,
              matching: find.byKey(const ValueKey('move-suggestion-icon')),
            ),
          );
          final threatIcon = tester.widget<Icon>(
            find.descendant(of: threat, matching: find.byType(Icon)).first,
          );
          expect(suggestIcon.icon, Icons.lightbulb_rounded);
          expect(suggestIcon.color, moveSuggestionIconColor);
          expect(threatIcon.color, threatIconColor);
          expect(
            tester
                .getCenter(find.byKey(const ValueKey('move-suggestion-icon')))
                .dy,
            tester.getCenter(find.byKey(const ValueKey('threat-action-icon'))).dy,
            reason:
                'The price belongs to the label and must not shift the suggestion icon.',
          );
          for (final (badgeType, ink) in [
            (MoveSuggestionIcon, suggestIcon.color!),
            (ThreatActionIcon, threatIcon.color!),
          ]) {
            final badge = tester.widget<Container>(
              find.descendant(
                of: find.byType(badgeType),
                matching: find.byType(Container),
              ),
            );
            final surface = (badge.decoration! as BoxDecoration).color!;
            expect(_contrast(ink, surface), greaterThanOrEqualTo(3));
            expect(surface.b, greaterThan(surface.r));
          }
          expect(
            tester.getRect(suggest).right,
            lessThan(tester.getRect(threat).left),
          );
          expect(tester.getRect(suggest).bottom, lessThanOrEqualTo(844));
          expect(tester.getRect(threat).bottom, lessThanOrEqualTo(844));
          // Lower match details may be built lazily. Check their document
          // order only after the initial visible-button assertions above.
          final matchList = find.byKey(
            ValueKey(
              online ? 'portrait-online-match-scroll' : 'portrait-match-scroll',
            ),
          );
          final captures = find.byType(CapturedPiecesPanel);
          for (var i = 0; captures.evaluate().isEmpty && i < 12; i++) {
            await tester.drag(matchList, const Offset(0, -160));
            await tester.pump();
          }
          expect(captures, findsOneWidget);
          final offset = tester.widget<ListView>(matchList).controller!.offset;
          expect(
            tester.getRect(captures).top + offset,
            greaterThan(initialAssistBottom),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          client?.dispose();
        },
      );
    }
  }
}
