// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import 'board_appearance.dart';

class CapturedPiecesPanel extends StatelessWidget {
  const CapturedPiecesPanel({
    required this.pieces,
    required this.appearance,
    this.playerSide,
    super.key,
  });

  final List<Piece>? pieces;
  final BoardAppearance appearance;

  /// Null for shared-device play, where neither player owns the screen.
  final Side? playerSide;

  Widget _row(Side captor) {
    final victims = pieces!.where((p) => p.color != captor).toList();
    final label = playerSide == null
        ? 'Taken by ${captor == Side.white ? 'White' : 'Black'}'
        : captor == playerSide
        ? 'You captured'
        : 'Opponent captured';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label · ${victims.length}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        if (victims.isEmpty)
          const Text('None yet', style: TextStyle(fontSize: 12))
        else
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 0; i < victims.length; i++)
                Semantics(
                  label:
                      '$label: ${victims[i].color.name} ${victims[i].role.name}',
                  image: true,
                  child: Tooltip(
                    message: '${victims[i].color.name} ${victims[i].role.name}',
                    excludeFromSemantics: true,
                    child: SizedBox.square(
                      key: ValueKey('captured-${captor.name}-$i'),
                      dimension: 34,
                      child: CharacterPiece(
                        piece: victims[i],
                        pack: appearance.army(victims[i].color),
                        standard: appearance.standardPieces,
                        classicStyle: appearance.classicStyle,
                        customSet: appearance.customSet,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('captured-pieces-panel'),
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Captured pieces',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (pieces == null)
            const Text('Capture history unavailable for this position.')
          else if (MediaQuery.textScalerOf(context).scale(14) > 21) ...[
            _row(playerSide ?? Side.white),
            const Divider(height: 16),
            _row((playerSide ?? Side.white).opposite),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _row(playerSide ?? Side.white)),
                const SizedBox(width: 12),
                Expanded(child: _row((playerSide ?? Side.white).opposite)),
              ],
            ),
        ],
      ),
    ),
  );
}
