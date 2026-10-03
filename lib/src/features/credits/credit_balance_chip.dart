// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import 'gold_credit_coin.dart';

/// A small, non-blocking price marker for actions that consume credits.
class CreditCostBadge extends StatelessWidget {
  const CreditCostBadge({
    required this.cost,
    this.label,
    this.compact = false,
    super.key,
  }) : assert(cost >= 0);

  final int cost;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final prefix = label?.trim();
    final semanticLabel = [
      if (prefix != null && prefix.isNotEmpty) prefix,
      'Costs $cost credit${cost == 1 ? '' : 's'}',
    ].join('. ');
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0x2639D7B2), Color(0x26FFD166)],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x66FFD166)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 5 : 7,
            vertical: compact ? 2 : 4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GoldCreditCoin(size: compact ? 13 : 16),
              SizedBox(width: compact ? 2 : 4),
              Text(
                '${prefix == null || prefix.isEmpty ? '' : '$prefix · '}$cost',
                maxLines: 1,
                style: TextStyle(
                  color: const Color(0xFFFFE3A1),
                  fontSize: compact ? 9 : 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
