// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:battle_chess_arena/src/domain/animated_army_theme.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/neon_live_action.dart';
import 'package:battle_chess_arena/src/features/play/animated_castling_presentation.dart';
import 'package:battle_chess_arena/src/features/play/animated_move_timing.dart';
import 'package:battle_chess_arena/src/features/play/neon_illustrated_stage.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Position _before(Side side) => Chess.fromSetup(
  Setup.parseFen(
    side == Side.white
        ? '4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1'
        : 'r3k2r/8/8/8/8/8/8/4K3 b kq - 0 1',
  ),
);

NeonLiveAction _castle(Side side, bool kingside, {Side viewer = Side.white}) {
  final before = _before(side);
  final game = GameSession(position: before);
  final rank = side == Side.white ? '1' : '8';
  final move = game.playUci('e$rank${kingside ? 'g' : 'c'}$rank')!;
  return NeonLiveAction.move(
    before: before,
    after: game.position,
    resolution: move,
    viewerSide: viewer,
  )!;
}

Future<void> _show(
  WidgetTester tester, {
  required NeonLiveAction action,
  required AnimatedArmyTheme theme,
  double progress = 0,
  bool reduced = false,
  Size size = const Size(390, 210),
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: AnimatedCastlingPresentation(
              action: action,
              theme: theme,
              progress: progress,
              reducedMotion: reduced,
              figureBodyHeight: 180,
              actorCenter: action.actorOnLeft ? .25 : .75,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _motion(bool king) => find.byKey(
  ValueKey(
    king ? 'animated-castling-king-motion' : 'animated-castling-rook-motion',
  ),
);

void main() {
  for (final theme in AnimatedArmyTheme.values) {
    for (final side in Side.values) {
      for (final kingside in [true, false]) {
        testWidgets(
          '${theme.name} ${side.name} ${kingside ? 'short' : 'long'} castle moves both allies together',
          (tester) async {
            final action = _castle(side, kingside);
            await _show(tester, action: action, theme: theme);
            final sprites = tester
                .widgetList<NeonFigureSprite>(find.byType(NeonFigureSprite))
                .toList();
            expect(sprites, hasLength(2));
            expect(sprites.map((sprite) => sprite.piece), [
              Piece(color: side, role: Role.rook),
              Piece(color: side, role: Role.king),
            ]);
            expect(sprites.every((sprite) => sprite.theme == theme), isTrue);
            expect(
              sprites.every((sprite) => sprite.faceRight == action.actorOnLeft),
              isTrue,
            );
            expect(sprites.first.bodyHeight, sprites.last.bodyHeight);
            expect(sprites.first.bodyHeight, greaterThan(0));
            final label = tester.widget<Semantics>(
              find.byKey(const ValueKey('animated-live-castling')),
            );
            expect(label.properties.label, contains('castling'));
            expect(
              label.properties.label,
              contains(
                'rook ${action.castling!.source.name} to ${action.castling!.target.name}',
              ),
            );
            expect(find.textContaining('DEFEATED'), findsNothing);
            expect(find.textContaining('WINNER'), findsNothing);
            final kingStart = tester.getCenter(_motion(true));
            final rookStart = tester.getCenter(_motion(false));
            await _show(tester, action: action, theme: theme, progress: .2);
            final kingTravel = tester.getCenter(_motion(true));
            final rookTravel = tester.getCenter(_motion(false));
            expect(kingTravel.dx, isNot(kingStart.dx));
            expect(rookTravel.dx, isNot(rookStart.dx));
            expect(
              (kingTravel.dx - kingStart.dx) * (rookTravel.dx - rookStart.dx),
              lessThan(0),
              reason:
                  'The rook crosses behind the king to guard its new flank.',
            );
            await _show(
              tester,
              action: action,
              theme: theme,
              progress: animatedMoveImpactFraction,
            );
            final kingLanded = tester.getCenter(_motion(true));
            final rookLanded = tester.getCenter(_motion(false));
            await _show(tester, action: action, theme: theme, progress: 1);
            expect(tester.getCenter(_motion(true)), kingLanded);
            expect(tester.getCenter(_motion(false)), rookLanded);
            expect(
              find.text('ROOK · ${action.castling!.target.name.toUpperCase()}'),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }

    testWidgets(
      '${theme.name} reduced short pane retains equal static allies',
      (tester) async {
        final action = _castle(Side.black, true, viewer: Side.black);
        const size = Size(320, 70);
        await _show(
          tester,
          action: action,
          theme: theme,
          reduced: true,
          size: size,
          textScale: 2,
        );
        final sprites = tester
            .widgetList<NeonFigureSprite>(find.byType(NeonFigureSprite))
            .toList();
        expect(sprites.every((sprite) => sprite.faceRight == true), isTrue);
        expect(sprites.first.bodyHeight, sprites.last.bodyHeight);
        expect(sprites.first.bodyHeight, greaterThan(0));
        final king = tester.getCenter(_motion(true));
        final rook = tester.getCenter(_motion(false));
        await _show(
          tester,
          action: action,
          theme: theme,
          progress: .2,
          reduced: true,
          size: size,
          textScale: 2,
        );
        expect(tester.getCenter(_motion(true)), king);
        expect(tester.getCenter(_motion(false)), rook);
        final paint = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('animated-castling-protection')),
        );
        final protection = paint.painter! as AnimatedCastlingPainter;
        expect(protection.theme, theme);
        expect(protection.reducedMotion, isTrue);
        expect(protection.progress, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('selected king never adds or animates a companion rook', (
    tester,
  ) async {
    final selected = NeonLiveAction.selection(
      position: _before(Side.white),
      source: Square.e1,
    )!;
    await _show(tester, action: selected, theme: AnimatedArmyTheme.neon);
    expect(find.byType(NeonFigureSprite), findsNothing);
    expect(find.byKey(const ValueKey('animated-live-castling')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
