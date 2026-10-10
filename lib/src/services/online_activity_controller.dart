// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/online_social.dart';
import 'game_invite_links.dart';
import 'online_game_history.dart';
import 'online_match_client.dart';
import 'mobile_notifications.dart';
import 'game_push_notifications.dart';

class OnlineActivityAlert {
  const OnlineActivityAlert(this.game, this.message);
  final OnlineInviteGame game;
  final String message;
}

/// Account connection independent of whichever board or lobby is on screen.
class OnlineActivityController extends ChangeNotifier {
  OnlineActivityController({
    OnlineMatchClient? client,
    MobileNotificationService? notifications,
  }) : client = client ?? OnlineMatchClient(),
       notifications = notifications ?? MobileNotificationService();
  final OnlineMatchClient client;
  final MobileNotificationService notifications;
  final alerts = <OnlineActivityAlert>[];
  final _seen = <String, OnlineInviteGame>{};
  bool _baseline = false;
  bool _disposed = false;
  final _push = GamePushNotifications();
  bool _active = true;
  bool get active => _active;
  set active(bool value) {
    _active = value;
    _syncPush();
    if (value && client.connected) client.loadActiveGames();
  }

  void _syncPush() {
    final id = _push.deviceId;
    final token = _push.token;
    if (id == null || token == null) return;
    client.setPushDevice(
      deviceId: id,
      token: token,
      enabled: notificationsEnabled,
      active: active,
    );
  }

  Future<void> initializePush(void Function(String) openGame) =>
      _push.start(onToken: _syncPush, openGame: openGame);

  bool notificationsEnabled = false;
  String? visibleGameId;
  String? visibleInviteId;
  String? visibleSharedInviteId;
  String? _token;

  Future<void> start() async {
    client.addListener(_refresh);
    OnlineGameHistory.profileChanges.addListener(_profileChanged);
    OnlineGameHistory.notificationChanges.addListener(_preferenceChanged);
    notificationsEnabled =
        await OnlineGameHistory.loadMobileNotificationsEnabled();
    _syncPush();
    final profile = await OnlineGameHistory.loadProfile();
    if (_disposed) return;
    if (profile != null) OnlineGameHistory.profileChanges.value = profile;
    _profileChanged();
  }

  void _preferenceChanged() {
    notificationsEnabled = OnlineGameHistory.notificationChanges.value ?? false;
    _syncPush();
    notifyListeners();
  }

  void _profileChanged() {
    final profile = OnlineGameHistory.profileChanges.value;
    if (_disposed ||
        profile?.playerToken == null ||
        profile!.playerToken == _token) {
      return;
    }
    _token = profile.playerToken;
    _baseline = false;
    _seen.clear();
    alerts.clear();
    client.setProfile(profile);
    final endpoint = Uri.tryParse(onlineServerUrl);
    if (endpoint != null && endpoint.host.isNotEmpty) {
      unawaited(client.connect(endpoint));
    }
  }

  void _refresh() {
    if (_disposed || !client.activeGamesLoaded) return;
    for (final game in client.activeGames) {
      final previous = _seen[game.gameId];
      _seen[game.gameId] = game;
      if (!_baseline) continue;
      final opponent = game.state.opponentFor(game.seat).name;
      String? message;
      if ((previous == null || previous.state.status == 'waiting') &&
          game.state.status == 'active') {
        message = '$opponent joined. Your game is ready.';
      } else if (previous != null &&
          previous.state.round == game.state.round &&
          game.state.san.length > previous.state.san.length) {
        final mover = game.state.san.length.isOdd ? 'w' : 'b';
        if (mover != game.seat) {
          message =
              '$opponent played ${game.state.san.last}.${game.state.status == 'complete' ? ' Game complete.' : ' It’s your turn.'}';
        }
      }
      if (message == null) continue;
      final onWaitingBoard =
          visibleInviteId != null &&
          client.invitations.any(
            (invite) =>
                invite.inviteId == visibleInviteId &&
                invite.game?.gameId == game.gameId,
          );
      final onSharedWaitingBoard =
          visibleSharedInviteId != null &&
          client.sharedInvitations.any(
            (invite) =>
                invite.inviteId == visibleSharedInviteId &&
                invite.gameId == game.gameId,
          );
      if (active &&
          (visibleGameId == game.gameId ||
              onWaitingBoard ||
              onSharedWaitingBoard)) {
        continue;
      }
      alerts.removeWhere((alert) => alert.game.gameId == game.gameId);
      alerts.insert(0, OnlineActivityAlert(game, message));
      if (alerts.length > 50) alerts.removeLast();
      if (!active &&
          notificationsEnabled &&
          !(_push.ready && _push.token != null && client.supportsGamePush)) {
        unawaited(
          notifications.show(
            id: 'game:${game.gameId}',
            title: 'Battle Chess Arena',
            body: message,
          ),
        );
      } else if (active) {
        unawaited(notifications.playAlert());
      }
    }
    _baseline = true;
    notifyListeners();
  }

  void viewGame(String? id) {
    visibleGameId = id;
    if (id != null) alerts.removeWhere((alert) => alert.game.gameId == id);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    OnlineGameHistory.profileChanges.removeListener(_profileChanged);
    OnlineGameHistory.notificationChanges.removeListener(_preferenceChanged);
    client.removeListener(_refresh);
    _push.dispose();
    client.dispose();
    super.dispose();
  }
}

class OnlineActivityNavigation extends NavigatorObserver {
  OnlineActivityNavigation(this.controller);
  final OnlineActivityController controller;
  void _show(Route<dynamic>? route) {
    final name = route?.settings.name ?? '';
    controller.visibleInviteId = name.startsWith('/waiting-invite:')
        ? name.substring(16)
        : null;
    controller.visibleSharedInviteId = name.startsWith('/waiting-shared:')
        ? name.substring(16)
        : null;
    final id = name.startsWith('/online-game:') ? name.substring(13) : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller._disposed) controller.viewGame(id);
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _show(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _show(previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _show(newRoute);
}
