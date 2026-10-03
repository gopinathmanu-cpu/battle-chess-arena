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

void main() {
  for (final online in [false, true]) {
    for (final (width, scale) in [(390.0, 1.0), (320.0, 1.0), (320.0, 1.5)]) {
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
            channel.seat(state: stateJson());
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
          // Opponent identity stays before the board; assists remain reachable
          // immediately below it on compact portrait screens.
          await tester.scrollUntilVisible(
            suggest,
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
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
          expect(
            find.descendant(of: suggest, matching: find.byType(FittedBox)),
            findsNothing,
          );
          expect(tester.getSize(suggest).height, tester.getSize(threat).height);
          expect(
            tester
                .getTopLeft(
                  find.byKey(
                    ValueKey(
                      online
                          ? 'online-computer-lifelines'
                          : 'computer-lifelines',
                    ),
                  ),
                )
                .dy,
            lessThan(tester.getTopLeft(find.byType(CapturedPiecesPanel)).dy),
          );
          // A lazily built ListView can recycle the board after scrolling on
          // very small/high-text layouts. Where both are mounted, enforce the
          // board-before-assists visual order as well.
          if (find.byType(ChessBoard).evaluate().isNotEmpty) {
            expect(
              tester.getBottomLeft(find.byType(ChessBoard)).dy,
              lessThan(
                tester
                    .getTopLeft(
                      find.byKey(
                        ValueKey(
                          online
                              ? 'online-computer-lifelines'
                              : 'computer-lifelines',
                        ),
                      ),
                    )
                    .dy,
              ),
            );
          }
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
            tester.getRect(suggest).right,
            lessThan(tester.getRect(threat).left),
          );
          if (width == 390 && scale == 1) {
            expect(tester.getRect(suggest).bottom, lessThanOrEqualTo(844));
            expect(tester.getRect(threat).bottom, lessThanOrEqualTo(844));
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          client?.dispose();
        },
      );
    }
  }
}
