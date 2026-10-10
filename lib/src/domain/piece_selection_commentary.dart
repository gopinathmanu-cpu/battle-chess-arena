// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';

import 'animated_army_theme.dart';
import 'neon_live_action.dart';

/// Short avatar replies from facts about the selected piece. These describe
/// legal options, without claiming that a move is safe or strategically best.
List<String> pieceSelectionCommentary({
  required Position position,
  required NeonLiveAction action,
  required AnimatedArmyTheme theme,
}) {
  if (!action.isSelection ||
      position.board.pieceAt(action.source) != action.actor ||
      position.turn != action.actor.color) {
    return const [];
  }
  // Re-read this position rather than trusting a selection restored from a
  // different board. In particular, pinned pieces cannot advertise captures.
  final selected = NeonLiveAction.selection(
    position: position,
    source: action.source,
  );
  if (selected == null) return const [];
  final destinations = position.legalMovesOf(action.source).squares;
  if (destinations.isEmpty) {
    return position.isCheck
        ? const [
            'Our king is in check.',
            'Choose a piece that can answer check.',
          ]
        : const [
            'I have no legal move yet.',
            'Another piece must lead this turn.',
          ];
  }
  if (position.isCheck) {
    return action.actor.role == Role.king
        ? const [
            'Guide me to safety.',
            'Let\'s get out of check.',
            'Choose my escape.',
          ]
        : const [
            'Let\'s answer this check.',
            'Our king needs cover.',
            'I can help answer check.',
          ];
  }
  final captures = selected.threats.where((threat) => !threat.isKingThreat);
  if (captures.isNotEmpty) {
    final victim = captures.first;
    final role = victim.piece.role.name;
    final square = victim.square.name.toUpperCase();
    return [
      'The $role on $square is in reach.',
      'I can take the $role on $square.',
      'That $role on $square is a legal target.',
    ];
  }
  if (action.actor.role == Role.pawn &&
      destinations.any(
        (square) => square.rank == Rank.first || square.rank == Rank.eighth,
      )) {
    return const [
      'One step from promotion.',
      'Choose what I become.',
      'The last rank is within reach.',
    ];
  }
  if (selected.threats.any((threat) => threat.possibleCheck)) {
    return const [
      'I have a move that gives check.',
      'I can challenge their king.',
      'A checking move is available.',
    ];
  }
  return [
    'At your command.',
    'Let\'s win this battle.',
    ...switch (action.actor.role) {
      Role.king => const [
        'Lead wisely; I am ready.',
        'Keep our army together.',
      ],
      Role.queen => const ['Choose my next path.', 'Ready to lead the charge.'],
      Role.rook => const [
        'Give me a clear lane.',
        'Straight ahead, commander.',
      ],
      Role.bishop => const ['Show me the diagonal.', 'My diagonal awaits.'],
      Role.knight => const [
        'Ready for the leap.',
        'Point me toward my next leap.',
      ],
      Role.pawn => const ['One step at a time.', 'Even small steps matter.'],
    },
    switch (theme) {
      AnimatedArmyTheme.neon => 'Systems ready, commander.',
      AnimatedArmyTheme.manga => 'Let\'s make our next move count.',
      AnimatedArmyTheme.epic => 'Ready to guard our ranks.',
      AnimatedArmyTheme.olympian => 'The legion awaits your command.',
    },
  ];
}
