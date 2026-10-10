// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import '../domain/online_player_profile.dart';
import 'game_invite_links.dart';
import 'online_game_history.dart';
import 'online_match_client.dart';

/// Reserve or update a public name before writing the local profile cache.
Future<OnlinePlayerProfile> saveOnlineProfileConfirmed(
  OnlinePlayerProfile desired, {
  OnlinePlayerProfile? previous,
  OnlineMatchClient? client,
  Uri? endpoint,
}) async {
  final connection = client ?? OnlineMatchClient(profile: previous ?? desired);
  final ready = Completer<void>();
  void check() {
    if (ready.isCompleted) return;
    if (connection.error != null) {
      ready.completeError(StateError(connection.error!));
    } else if (connection.connected &&
        connection.profile?.playerToken != null) {
      ready.complete();
    }
  }

  connection.addListener(check);
  try {
    if (!connection.connected) {
      unawaited(connection.connect(endpoint ?? Uri.parse(onlineServerUrl)));
    }
    check();
    await ready.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw StateError(
        'Connect to the internet to verify and save your Avatar Name.',
      ),
    );
    final registered = connection.profile!;
    final accepted =
        registered.name == desired.name &&
            registered.avatarId == desired.avatarId &&
            registered.level == desired.level
        ? registered
        : await connection.updateProfileConfirmed(
            name: desired.name,
            avatarId: desired.avatarId,
            level: desired.level,
          );
    await OnlineGameHistory.saveProfile(accepted);
    return accepted;
  } finally {
    connection.removeListener(check);
    if (client == null) connection.dispose();
  }
}
