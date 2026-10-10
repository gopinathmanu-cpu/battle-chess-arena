// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';

import 'animated_army_theme.dart';
import 'cinematic_replay.dart';
import 'cinematic_tactics.dart';
import 'cinematic_threats.dart';

/// One film beat. The duration is the visual minimum; narration can hold it.
class NeonStoryBeat {
  const NeonStoryBeat({
    required this.title,
    required this.narration,
    required this.visualDuration,
  });

  final String title;
  final String narration;
  final Duration visualDuration;
}

/// Plain chess commentary derived from the actual moves and legal board facts.
/// It describes immediate possibilities, without an engine's evaluation.
class NeonCinematicStory {
  const NeonCinematicStory(
    this.replay, {
    this.playerSide,
    this.winnerSide,
    this.theme = AnimatedArmyTheme.neon,
  });

  final CinematicReplay replay;
  final Side? playerSide;
  final Side? winnerSide;
  final AnimatedArmyTheme theme;

  NeonStoryBeat intro() => NeonStoryBeat(
    title: theme.displayName,
    narration: switch (theme) {
      AnimatedArmyTheme.neon =>
        "White's Aurora army faces Black's Void army. "
            "Let's review the moves and their threats.",
      AnimatedArmyTheme.manga =>
        "White's Star Vanguard faces Black's Eclipse Vanguard beneath a comet sky. "
            'Follow each move, capture and turning point in this sword-lit arena.',
      AnimatedArmyTheme.epic =>
        "White's Sun Guardians face Black's Moon Guardians in the radiant citadel. "
            'Their astras light the battle; the recorded chess moves tell its story.',
      AnimatedArmyTheme.olympian =>
        "White's Dawn Legion faces Black's Dusk Legion in the marble arena. "
            'Bronze shields meet the storm. Follow the moves and their threats.',
    },
    visualDuration: const Duration(seconds: 5),
  );

  NeonStoryBeat move(int sceneIndex) {
    final scene = replay.scenes[sceneIndex];
    final side = _side(scene.side);
    final enemy = _side(scene.side.opposite);
    final role = scene.resolution.attacker.role.name;
    final route = '${scene.source.name} to ${scene.target.name}';
    final defender = scene.resolution.defender;
    final promotion = scene.resolution.move.promotion;
    late String title;
    late String action;
    var duration = const Duration(milliseconds: 2200);

    if (scene.isCastling) {
      final kingside = scene.target.file == File.g;
      final rank = scene.source.rank.name;
      final rookRoute =
          '${kingside ? 'h' : 'a'}$rank to '
          '${kingside ? 'f' : 'd'}$rank';
      title = '$side castles ${kingside ? 'kingside' : 'queenside'}';
      action = '$title. The king moves $route; the rook moves $rookRoute.';
      duration = const Duration(seconds: 4);
    } else if (promotion != null) {
      title = '$side promotes to a ${promotion.name}';
      final capture = defender == null
          ? ''
          : ", capturing $enemy's ${defender.role.name} on ${scene.captureSquare!.name}";
      action =
          "$side's pawn moves $route$capture, "
          'and promotes to a ${promotion.name}.';
      duration = const Duration(seconds: 5);
    } else if (scene.isEnPassant) {
      title = '$side captures en passant';
      action =
          "$side's pawn moves $route. "
          "En passant captures $enemy's pawn on ${scene.captureSquare!.name}.";
      duration = const Duration(seconds: 4);
    } else if (defender != null) {
      title = '$side captures a ${defender.role.name}';
      action =
          "$side's $role moves $route, "
          "capturing $enemy's ${defender.role.name} on ${scene.captureSquare!.name}.";
      duration = const Duration(seconds: 4);
    } else {
      title = '$side moves the $role';
      action = '$side moves its $role $route.';
    }

    // Occasional faction names frame the film without obscuring chess facts.
    // A seven-ply interval alternates White and Black references.
    if (theme != AnimatedArmyTheme.neon && sceneIndex % 7 == 0) {
      final faction = scene.side == Side.white
          ? theme.whiteFaction
          : theme.blackFaction;
      action = action.startsWith("$side's ")
          ? action.replaceFirst("$side's ", "$side's $faction ")
          : action.replaceFirst('$side ', "$side's $faction ");
    }

    if (scene.isCheckmate) {
      return NeonStoryBeat(
        title: '$side wins by checkmate',
        narration: '$action Checkmate. $enemy has no legal reply; $side wins.',
        visualDuration: const Duration(seconds: 6),
      );
    }
    if (scene.isCheck) {
      title = '$side gives check';
      action += ' Check. $enemy must respond.';
      duration = const Duration(seconds: 5);
    }

    final facts = CinematicTactics.after(scene);
    final reported = <Square>{};
    if (scene.isCheck) {
      reported.addAll(
        facts.opponentThreats.where((t) => t.isCheck).map((t) => t.square),
      );
    }
    if (facts.newForks.isNotEmpty) {
      final fork = facts.newForks.first;
      if (!scene.isCheck) {
        title = '$side creates a ${fork.attacker.role.name} fork';
      }
      final victims = fork.targets.take(3).toList();
      reported.addAll(victims.map((victim) => victim.square));
      action +=
          " $side's ${fork.attacker.role.name} on ${fork.source.name} "
          "forks $enemy's ${_targets(victims)}.";
      if (duration.inSeconds < 4) duration = const Duration(seconds: 4);
    }
    final remaining = facts.opponentThreats
        .where((t) => !reported.contains(t.square))
        .toList();
    final available = (3 - reported.length).clamp(0, 3);
    if (remaining.isNotEmpty) {
      final shown = remaining.take(available).toList();
      final more = remaining.length - shown.length;
      if (shown.isNotEmpty) {
        action +=
            ' $side ${reported.isEmpty ? 'threatens' : 'also threatens'} '
            "$enemy's ${_targets(shown, more: more)}.";
      } else {
        action +=
            ' $side also threatens $more other ${more == 1 ? 'piece' : 'pieces'}.';
      }
    }
    if (facts.materialGain >= 3) {
      final balance = facts.materialAfter;
      action += balance > 0
          ? ' $side now leads by $balance ${balance == 1 ? 'point' : 'points'} in material.'
          : balance == 0
          ? ' Material is now level.'
          : ' $side now trails by ${-balance} ${balance == -1 ? 'point' : 'points'} in material.';
    }
    if (facts.ownPiecesAtRisk.isNotEmpty) {
      final risks = facts.ownPiecesAtRisk;
      final shown = risks.take(3).toList();
      action +=
          ' $enemy can reply by capturing '
          "$side's ${_targets(shown, conjunction: 'or', more: risks.length - shown.length, mentionEnPassant: true)}.";
    }
    return NeonStoryBeat(
      title: title,
      narration: action,
      visualDuration: duration,
    );
  }

  NeonStoryBeat finale() {
    final result = replay.resultTitle;
    final reason = result.toLowerCase();
    final position = replay.finalPosition;
    final winner = cinematicWinner(
      resultTitle: result,
      finalPosition: position,
      winnerSide: winnerSide,
    );
    late String ending;
    if (reason.contains('cancel') || reason.contains('abort')) {
      ending = replay.scenes.isEmpty
          ? 'No moves were played.'
          : 'The recording ends here.';
    } else if (reason.contains('unfinished') || reason.contains('incomplete')) {
      ending = 'Review the moves played so far.';
    } else if (reason.contains('resign')) {
      ending = 'The game ended by resignation.';
    } else if (reason.contains('time') || reason.contains('clock')) {
      ending = 'The clock decided the result.';
    } else if (reason.contains('draw')) {
      ending = 'Neither side won.';
    } else if (position.isStalemate) {
      ending =
          'No legal move remains, but the king is not in check. Neither side won.';
    } else if (position.isCheckmate && winner != null) {
      ending = '${_side(position.turn)} has no legal response to check.';
    } else {
      ending = replay.scenes.isEmpty
          ? 'No moves were played.'
          : 'The recording ends here.';
    }
    if (winner != null && theme != AnimatedArmyTheme.neon) {
      final faction = winner == Side.white
          ? theme.whiteFaction
          : theme.blackFaction;
      ending += switch (theme) {
        AnimatedArmyTheme.neon => '',
        AnimatedArmyTheme.manga => ' $faction wins beneath the comet sky.',
        AnimatedArmyTheme.epic => ' $faction wins the battle of the citadel.',
        AnimatedArmyTheme.olympian => ' $faction wins in the marble arena.',
      };
    }
    if (playerSide != null && winner != null && winner != playerSide) {
      ending += ' Learn from this game and fight another day.';
    }
    return NeonStoryBeat(
      title: result,
      narration: '$result. $ending',
      visualDuration: const Duration(seconds: 6),
    );
  }
}

String _side(Side side) => side == Side.white ? 'White' : 'Black';

String _targets(
  List<CinematicThreat> threats, {
  String conjunction = 'and',
  int more = 0,
  bool mentionEnPassant = false,
}) {
  final parts = [
    for (final threat in threats)
      '${threat.piece.role.name} on ${threat.square.name}'
          '${mentionEnPassant && threat.attacks.any((a) => a.enPassant) ? ' en passant' : ''}',
  ];
  if (more > 0) parts.add('$more more ${more == 1 ? 'piece' : 'pieces'}');
  if (parts.length == 1) return parts.single;
  return '${parts.take(parts.length - 1).join(', ')} $conjunction ${parts.last}';
}
