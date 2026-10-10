// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../domain/piece_pack.dart';
import '../play/board_appearance.dart';

/// Artwork-led family selection; uses the same sprites as the board preview.
class ChessSetFamilySelector extends StatelessWidget {
  const ChessSetFamilySelector({
    required this.pack,
    required this.classic,
    required this.style,
    required this.onChanged,
    this.customActive = false,
    super.key,
  });

  final PiecePack pack;
  final bool classic;
  final ClassicPieceStyle style;
  final ValueChanged<bool> onChanged;
  final bool customActive;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final isClassic in [true, false]) ...[
          if (!isClassic) const SizedBox(width: 10),
          Expanded(
            child: _FamilyCard(
              pack: pack,
              classic: isClassic,
              style: style,
              selected: !customActive && classic == isClassic,
              onTap: () => onChanged(isClassic),
            ),
          ),
        ],
      ],
    ),
  );
}

class _FamilyCard extends StatelessWidget {
  const _FamilyCard({
    required this.pack,
    required this.classic,
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final PiecePack pack;
  final bool classic;
  final ClassicPieceStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Family selection is application chrome, so both choices follow the
    // active app palette. Chess-set accents belong to the board artwork.
    final accent = colors.primary;
    final surface = colors.surfaceContainer;
    final title = classic ? 'Classic' : 'Animated';
    final count = classic
        ? ClassicPieceStyle.values.length
        : availablePiecePacks.length;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '$title chess sets, $count variations',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: accent.withValues(alpha: .14),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Material(
          color: selected ? colors.primaryContainer : surface,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: selected ? .24 : .07),
                  selected ? colors.primaryContainer : surface,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? accent : colors.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: InkWell(
              key: ValueKey(classic ? 'choose-classic' : 'choose-themed'),
              onTap: onTap,
              child: Stack(
                children: [
                  Padding(
                    // Give the Animated cast more of the existing card without
                    // moving its label or increasing the normal card height.
                    padding: EdgeInsets.fromLTRB(
                      classic ? 8 : 0,
                      classic ? 14 : 10,
                      8,
                      classic ? 14 : 10,
                    ),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: Container(
                            width: classic ? 52 : 64,
                            height: classic ? 56 : 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: RadialGradient(
                                colors: [
                                  accent.withValues(alpha: .3),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: CharacterPiece(
                              piece: const Piece(
                                color: Side.white,
                                role: Role.knight,
                              ),
                              pack: pack,
                              showRole: false,
                              standard: classic,
                              classicStyle: style,
                            ),
                          ),
                        ),
                        SizedBox(width: classic ? 5 : 1),
                        Expanded(
                          child: ExcludeSemantics(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$count sets',
                                  style: TextStyle(fontSize: 11, color: accent),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    Positioned(
                      right: 7,
                      top: 6,
                      child: ExcludeSemantics(
                        child: Icon(
                          Icons.check_circle,
                          color: accent,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
