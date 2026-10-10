// SPDX-License-Identifier: GPL-3.0-or-later
import 'online_game_state.dart';

class SharedInvitation {
  const SharedInvitation({
    required this.inviteId,
    required this.avatarName,
    required this.status,
    this.expiresAt,
    this.gameId,
  });
  factory SharedInvitation.fromJson(Map<String, dynamic> json) =>
      SharedInvitation(
        inviteId: json['inviteId'] as String,
        avatarName: json['avatarName'] as String,
        status: json['status'] as String,
        gameId: json['gameId'] as String?,
        expiresAt: json['expiresAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(json['expiresAt'] as int),
      );
  final String inviteId;
  final String avatarName;
  final String status;
  final String? gameId;
  final DateTime? expiresAt;
  bool get isExpired =>
      status == 'expired' ||
      (expiresAt != null && !DateTime.now().isBefore(expiresAt!));
}

class OnlineInvitation {
  const OnlineInvitation({
    required this.inviteId,
    required this.senderName,
    required this.senderAvatarId,
    required this.recipientName,
    required this.recipientAvatarId,
    required this.status,
    required this.createdAt,
    required this.awaitingResponseFromName,
    required this.timed,
    required this.baseMs,
    this.incrementMs = 0,
    this.clockMode = 'live',
    this.scheduledAt,
    this.game,
    this.tossForColors = false,
    this.expiresAt,
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
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(json['expiresAt'] as int),
      awaitingResponseFromName:
          json['awaitingResponseFromName'] as String? ??
          (json['status'] == 'pending' ? recipient['name'] as String : null),
      timed: json['timed'] as bool? ?? true,
      tossForColors: json['tossForColors'] as bool? ?? false,
      baseMs: json['baseMs'] as int? ?? 600000,
      incrementMs: json['incrementMs'] as int? ?? 0,
      clockMode: json['clockMode'] as String? ?? 'live',
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
  final DateTime? expiresAt;
  final String? awaitingResponseFromName;
  final bool timed;
  final bool tossForColors;
  final int baseMs;
  final int incrementMs;
  final String clockMode;
  final DateTime? scheduledAt;
  final OnlineInviteGame? game;

  bool receivedBy(String playerName) =>
      recipientName.toLowerCase() == playerName.toLowerCase();

  bool get isExpired =>
      status == 'expired' ||
      (game == null &&
          ['pending', 'accepted'].contains(status) &&
          expiresAt != null &&
          !DateTime.now().isBefore(expiresAt!));

  bool canRespondBy(String playerName) =>
      !isExpired &&
      status == 'pending' &&
      awaitingResponseFromName?.toLowerCase() == playerName.toLowerCase();
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
