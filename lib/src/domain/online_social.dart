// SPDX-License-Identifier: GPL-3.0-or-later
import 'online_game_state.dart';

class OnlineInvitation {
  const OnlineInvitation({
    required this.inviteId,
    required this.senderName,
    required this.senderAvatarId,
    required this.recipientName,
    required this.recipientAvatarId,
    required this.status,
    required this.createdAt,
    this.scheduledAt,
    this.game,
  });

  factory OnlineInvitation.fromJson(Map<String, dynamic> json) {
    final sender = (json['sender'] as Map).cast<String, dynamic>();
    final recipient = (json['recipient'] as Map).cast<String, dynamic>();
    final game = json['game'] as Map?;
    return OnlineInvitation(
      inviteId: json['inviteId'] as String,
      senderName: sender['name'] as String,
      senderAvatarId: sender['avatarId'] as String,
      recipientName: recipient['name'] as String,
      recipientAvatarId: recipient['avatarId'] as String,
      status: json['status'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      scheduledAt: json['scheduledAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(json['scheduledAt'] as int),
      game: game == null
          ? null
          : OnlineInviteGame.fromJson(game.cast<String, dynamic>()),
    );
  }

  final String inviteId;
  final String senderName;
  final String senderAvatarId;
  final String recipientName;
  final String recipientAvatarId;
  final String status;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  final OnlineInviteGame? game;

  bool receivedBy(String playerName) =>
      recipientName.toLowerCase() == playerName.toLowerCase();
}

class OnlineInviteGame {
  const OnlineInviteGame({
    required this.gameId,
    required this.seat,
    required this.seatToken,
    required this.state,
  });

  factory OnlineInviteGame.fromJson(Map<String, dynamic> json) =>
      OnlineInviteGame(
        gameId: json['gameId'] as String,
        seat: json['seat'] as String,
        seatToken: json['seatToken'] as String,
        state: OnlineGameState.fromJson(
          (json['state'] as Map).cast<String, dynamic>(),
        ),
      );

  final String gameId;
  final String seat;
  final String seatToken;
  final OnlineGameState state;
}
