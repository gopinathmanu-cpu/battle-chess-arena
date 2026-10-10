// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The match's existing opponent identity takes the place of its action stage.
/// The avatar builder preserves human, computer and regional portrait sources.
class MatchOpponentPanel extends StatelessWidget {
  const MatchOpponentPanel({
    required this.name,
    required this.details,
    required this.avatarBuilder,
    super.key,
  });

  final String name;
  final String details;
  final Widget Function(double size) avatarBuilder;

  Widget _name({bool centered = false}) => Text(
    name,
    key: const ValueKey('match-opponent-name'),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    textAlign: centered ? TextAlign.center : TextAlign.start,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
  );

  Widget _details({bool centered = false}) => Text(
    details,
    key: const ValueKey('match-opponent-details'),
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
    textAlign: centered ? TextAlign.center : TextAlign.start,
    style: const TextStyle(fontSize: 12, height: 1.2),
  );

  Widget _avatar(double size) => SizedBox.square(
    key: const ValueKey('match-opponent-avatar'),
    dimension: size,
    child: avatarBuilder(size),
  );

  Widget _horizontal(double avatarSize, {bool scrollable = false}) {
    final row = Row(
      crossAxisAlignment: scrollable
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        _avatar(avatarSize),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_name(), const SizedBox(height: 4), _details()],
          ),
        ),
      ],
    );
    return scrollable ? SingleChildScrollView(primary: false, child: row) : row;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scaler = MediaQuery.textScalerOf(context);
      // Reserve the full line budgets before choosing the larger portrait.
      // Short lanes and enlarged text use the same readable horizontal card.
      final avatarBudget =
          constraints.maxHeight -
          32 -
          scaler.scale(16) * 2 * 1.2 -
          scaler.scale(12) * 3 * 1.2 -
          12;
      final stacked =
          constraints.hasBoundedHeight &&
          constraints.maxWidth >= 200 &&
          avatarBudget >= 48;
      final avatarSize = stacked
          ? math.min(96.0, avatarBudget)
          : constraints.hasBoundedHeight
          ? math.min(64.0, math.max(32.0, constraints.maxHeight - 32))
          : 64.0;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: stacked
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _avatar(avatarSize),
                    const SizedBox(height: 8),
                    _name(centered: true),
                    const SizedBox(height: 4),
                    _details(centered: true),
                  ],
                )
              : _horizontal(
                  avatarSize,
                  scrollable: constraints.hasBoundedHeight,
                ),
        ),
      );
    },
  );
}
