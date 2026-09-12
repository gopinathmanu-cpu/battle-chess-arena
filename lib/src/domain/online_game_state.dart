// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';

class OnlineGameState {
  OnlineGameState.fromJson(Map<String, dynamic> json)
    : gameId = json['gameId'] as String,
      sequence = json['sequence'] as int,
      round = json['round'] as int,
      status = json['status'] as String,
      timed = json['timed'] as bool? ?? true,
      fen = json['fen'] as String,
      turn = json['turn'] as String,
      whiteMs = ((json['clocks'] as Map)['w'] as num).round(),
      blackMs = ((json['clocks'] as Map)['b'] as num).round(),
      san = List<String>.unmodifiable(json['san'] as List),
      resultReason = (json['result'] as Map?)?['reason'] as String?,
      winner = (json['result'] as Map?)?['winner'] as String?,
      drawOfferSide = (json['drawOffer'] as Map?)?['side'] as String?,
      drawOfferId = (json['drawOffer'] as Map?)?['offerId'] as String?,
      rematchOffers = List<String>.unmodifiable(
        json['rematchOffers'] as List? ?? [],
      ),
      whitePlayer = OnlinePlayerSummary.fromJson(
        ((json['players'] as Map?)?['w'] as Map?)?.cast<String, dynamic>(),
        fallbackName: 'White player',
      ),
      blackPlayer = OnlinePlayerSummary.fromJson(
        ((json['players'] as Map?)?['b'] as Map?)?.cast<String, dynamic>(),
        fallbackName: 'Waiting opponent',
      ) {
    position = Chess.fromSetup(Setup.parseFen(fen));
    if (gameId.isEmpty ||
        sequence < 0 ||
        round < 1 ||
        whiteMs < 0 ||
        blackMs < 0 ||
        !['waiting', 'active', 'complete'].contains(status) ||
        !['w', 'b'].contains(turn) ||
        (position.turn == Side.white ? 'w' : 'b') != turn ||
        (status == 'complete' && resultReason == null) ||
        (status != 'complete' && resultReason != null) ||
        (winner != null && !['w', 'b'].contains(winner)) ||
        (drawOfferSide != null &&
            (!['w', 'b'].contains(drawOfferSide) || drawOfferId == null)) ||
        rematchOffers.any((side) => !['w', 'b'].contains(side))) {
      throw const FormatException('Invalid authoritative state');
    }
  }

  final String gameId;
  final int sequence;
  final int round;
  final String status;
  final bool timed;
  final String fen;
  final String turn;
  final int whiteMs;
  final int blackMs;
  final List<String> san;
  final String? resultReason;
  final String? winner;
  final String? drawOfferSide;
  final String? drawOfferId;
  final List<String> rematchOffers;
  final OnlinePlayerSummary whitePlayer;
  final OnlinePlayerSummary blackPlayer;
  late final Position position;

  OnlinePlayerSummary opponentFor(String seat) =>
      seat == 'w' ? blackPlayer : whitePlayer;

  String get statusLabel {
    if (status == 'waiting') return 'Waiting for an opponent';
    if (status == 'complete') {
      final reason = switch (resultReason) {
        'checkmate' => 'Checkmate',
        'timeout' => 'Time expired',
        'resignation' => 'Resignation',
        'agreement' => 'Draw by agreement',
        'stalemate' => 'Draw by stalemate',
        'insufficient_material' => 'Draw · insufficient material',
        'repetition' => 'Draw by repetition',
        'fifty_move' => 'Draw by fifty-move rule',
        _ => 'Game complete',
      };
      return winner == null
          ? reason
          : '$reason · ${winner == 'w' ? 'White' : 'Black'} wins';
    }
    return '${turn == 'w' ? 'White' : 'Black'} to move${position.isCheck ? ' · CHECK' : ''}';
  }
}

class OnlinePlayerSummary {
  const OnlinePlayerSummary({
    required this.name,
    required this.avatarId,
    this.level = 'intermediate',
  });

  factory OnlinePlayerSummary.fromJson(
    Map<String, dynamic>? json, {
    required String fallbackName,
  }) => OnlinePlayerSummary(
    name: json?['name'] as String? ?? fallbackName,
    avatarId: json?['avatarId'] as String? ?? 'crown',
    level: json?['level'] as String? ?? 'intermediate',
  );

  final String name;
  final String avatarId;
  final String level;
}
