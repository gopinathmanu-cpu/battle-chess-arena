// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../credits/arena_credit_header.dart';

const gameHeaderIconSize = 48.0;
const gameHeaderGap = 12.0;

Widget _iconSlot(Widget icon) => SizedBox.square(
  dimension: gameHeaderIconSize,
  child: Center(child: icon),
);

/// A scrollable action row with a fixed, separately spaced credit counter.
class GameHeaderRibbon extends StatelessWidget {
  const GameHeaderRibbon({
    required this.icons,
    this.hasTitle = false,
    this.scrollKey,
    super.key,
  });
  final List<Widget> icons;
  final bool hasTitle;
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final leading = Navigator.of(context).canPop() ? 56.0 : 0.0;
    final available =
        media.size.width - media.padding.horizontal - leading - 24;
    final titleWidth = hasTitle
        ? math.min(80.0, math.max(0.0, available - 152))
        : 0.0;
    final contentWidth =
        icons.length * (gameHeaderIconSize + gameHeaderGap) + 92;
    return Flexible(
      child: SizedBox(
        width: math.min(contentWidth, math.max(152, available - titleWidth)),
        height: gameHeaderIconSize,
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                key: scrollKey,
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: gameHeaderGap,
                  children: icons.map(_iconSlot).toList(),
                ),
              ),
            ),
            const SizedBox(width: gameHeaderGap),
            const ArenaCreditHeader(compact: true),
          ],
        ),
      ),
    );
  }
}

/// The same spacing when controls are restored within the game content.
class GameHeaderWrap extends StatelessWidget {
  const GameHeaderWrap({required this.icons, super.key});
  final List<Widget> icons;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.end,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: gameHeaderGap,
    runSpacing: gameHeaderGap,
    children: [...icons.map(_iconSlot), const ArenaCreditHeader(compact: true)],
  );
}
