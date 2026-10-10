// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import '../../domain/online_social.dart';
import '../../domain/piece_pack.dart';
import '../../services/online_match_client.dart';
import '../../services/mobile_notifications.dart';
import '../play/board_appearance.dart';
import '../play/chess_widgets.dart';
import 'online_avatar_image.dart';

class InvitationWaitingScreen extends StatefulWidget {
  const InvitationWaitingScreen({
    required this.client,
    required this.invitation,
    required this.pack,
    required this.onReady,
    this.sharedInviteId,
    super.key,
  });
  final OnlineMatchClient client;
  final OnlineInvitation invitation;
  final PiecePack pack;
  final String? sharedInviteId;
  final Future<void> Function(OnlineInviteGame game) onReady;
  @override
  State<InvitationWaitingScreen> createState() =>
      _InvitationWaitingScreenState();
}

class _InvitationWaitingScreenState extends State<InvitationWaitingScreen> {
  bool _joining = false;
  bool _arrived = false;
  Timer? _arrivalTimer;
  Timer? _expiryTimer;
  OnlineInvitation get _invitation {
    if (widget.sharedInviteId != null) {
      final shared = widget.client.sharedInvitations
          .where((item) => item.inviteId == widget.sharedInviteId)
          .firstOrNull;
      final game = shared?.gameId == null
          ? null
          : widget.client.activeGames
                .where((game) => game.gameId == shared!.gameId)
                .firstOrNull;
      return OnlineInvitation(
        inviteId: widget.invitation.inviteId,
        senderName: widget.invitation.senderName,
        senderAvatarId: widget.invitation.senderAvatarId,
        recipientName: game?.state.opponentFor(game.seat).name ?? 'your friend',
        recipientAvatarId:
            game?.state.opponentFor(game.seat).avatarId ?? 'crown',
        status: shared?.status ?? widget.invitation.status,
        expiresAt: shared?.expiresAt ?? widget.invitation.expiresAt,
        createdAt: widget.invitation.createdAt,
        awaitingResponseFromName: 'your friend',
        timed: widget.invitation.timed,
        baseMs: widget.invitation.baseMs,
        game: game,
      );
    }
    return widget.client.invitations
            .where((item) => item.inviteId == widget.invitation.inviteId)
            .firstOrNull ??
        widget.invitation;
  }

  @override
  void initState() {
    super.initState();
    widget.client.addListener(_refresh);
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _invitation.isExpired) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
    final game = _invitation.game;
    if (_joining || game == null || _invitation.status != 'accepted') return;
    _joining = true;
    _arrived = true;
    unawaited(MobileNotificationService().playAlert());
    _arrivalTimer = Timer(const Duration(seconds: 2), () async {
      if (mounted) await widget.onReady(game);
    });
  }

  @override
  void dispose() {
    widget.client.removeListener(_refresh);
    _arrivalTimer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invite = _invitation;
    final opponent = invite.recipientName;
    final appearance = BoardAppearance.forPack(widget.pack);
    final message = _arrived
        ? '$opponent joined! Opening your game…'
        : invite.isExpired
        ? 'Invitation expired. Return to Online Play to send another invitation.'
        : invite.status == 'declined'
        ? '$opponent declined the invitation.'
        : invite.status == 'deleted'
        ? 'This invitation has been cancelled.'
        : widget.sharedInviteId != null &&
              invite.game == null &&
              invite.status == 'accepted'
        ? 'Your friend joined. Loading your game…'
        : invite.status == 'accepted' && invite.game == null
        ? '$opponent accepted. Waiting for the scheduled game to start.'
        : invite.awaitingResponseFromName == invite.senderName
        ? '$opponent proposed a new time. Return to Online Play to respond.'
        : !widget.client.connected
        ? 'Reconnecting… Waiting for $opponent to join.'
        : 'Waiting for $opponent to accept and join…';
    return Scaffold(
      appBar: AppBar(title: const Text('Invited game')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              leading: OnlineAvatarImage(avatarId: invite.recipientAvatarId),
              title: Text(opponent),
              subtitle: const Text('Your invited opponent'),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _arrived ? Icons.check_circle : Icons.hourglass_top,
                      color: _arrived ? Colors.tealAccent : Colors.white70,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        key: const ValueKey('invitation-waiting-message'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ChessBoard(
              position: Chess.initial,
              selected: null,
              legalTargets: const {},
              accent: appearance.board.accent,
              appearance: BoardAppearance(
                white: appearance.white,
                black: appearance.black,
                board: appearance.board,
                standardPieces: true,
              ),
              showCoordinates: true,
              onSquareTap: (_) {},
            ),
            const SizedBox(height: 12),
            const Text(
              'The clock starts when the game begins. You can leave this screen and open the game later.',
              textAlign: TextAlign.center,
            ),
            if (widget.client.error != null)
              Text(widget.client.error!, textAlign: TextAlign.center),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Online Play'),
            ),
          ],
        ),
      ),
    );
  }
}
