// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

class PlayerSideSelector extends StatelessWidget {
  const PlayerSideSelector({
    super.key,
    required this.side,
    required this.onChanged,
  });
  final Side side;
  final ValueChanged<Side> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('Choose your colour'),
      const SizedBox(height: 8),
      SegmentedButton<Side>(
        segments: const [
          ButtonSegment(
            value: Side.white,
            label: Text('White'),
            icon: Icon(Icons.circle_outlined),
          ),
          ButtonSegment(
            value: Side.black,
            label: Text('Black'),
            icon: Icon(Icons.circle),
          ),
        ],
        selected: {side},
        onSelectionChanged: (values) => onChanged(values.single),
      ),
      const SizedBox(height: 8),
      const Text('White moves first.'),
    ],
  );
}
