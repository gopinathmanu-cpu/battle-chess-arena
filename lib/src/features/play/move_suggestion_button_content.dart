// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import 'play_assist_style.dart';

/// Keep the action icon centred independently of its price and loading state.
class MoveSuggestionActionIcon extends StatelessWidget {
  const MoveSuggestionActionIcon({this.loading = false, super.key});

  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 28,
    child: loading
        ? const Center(
            child: SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : const MoveSuggestionIcon(size: 18),
  );
}

/// The price belongs to the action's text, leaving its icon aligned with Scan.
class MoveSuggestionLabel extends StatelessWidget {
  const MoveSuggestionLabel({required this.cost, this.priceKey, super.key})
    : assert(cost >= 0);

  final int cost;
  final Key? priceKey;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Suggest move',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(height: 1.05),
      ),
      const SizedBox(height: 2),
      Semantics(
        label: 'Costs $cost credit${cost == 1 ? '' : 's'}',
        excludeSemantics: true,
        child: Text(
          '$cost credit${cost == 1 ? '' : 's'}',
          key: priceKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      ),
    ],
  );
}
