// SPDX-License-Identifier: GPL-3.0-or-later

const gameInviteScheme = 'battlechessarena';
const gameInviteHost = 'join';
const onlineServerUrl = String.fromEnvironment(
  'ONLINE_SERVER_URL',
  defaultValue: 'wss://battle-chess-arena-firebase-jdth6ggixa-el.a.run.app',
);

Uri sharedInviteUri(String inviteId, {Uri? server}) {
  if (!_gameIdPattern.hasMatch(inviteId)) {
    throw ArgumentError.value(inviteId, 'inviteId');
  }
  final endpoint = server ?? Uri.parse(onlineServerUrl);
  return Uri(
    scheme: endpoint.scheme == 'ws' ? 'http' : 'https',
    host: endpoint.host,
    port: endpoint.hasPort ? endpoint.port : null,
    path: '/invite/$inviteId',
  );
}

String? sharedInviteIdFromUri(Uri uri) {
  String? id;
  if (uri.scheme.toLowerCase() == gameInviteScheme && uri.host == 'invite') {
    id = uri.queryParameters['invite'];
  } else if (uri.scheme == 'https' &&
      uri.host == Uri.parse(onlineServerUrl).host &&
      uri.pathSegments.length == 2 &&
      uri.pathSegments.first == 'invite') {
    id = uri.pathSegments.last;
  }
  return id != null && _gameIdPattern.hasMatch(id) ? id : null;
}

final _gameIdPattern = RegExp(r'^[A-Za-z0-9_-]{4,80}$');

Uri gameInviteUri(String gameId) {
  if (!_gameIdPattern.hasMatch(gameId)) {
    throw ArgumentError.value(gameId, 'gameId', 'Invalid game ID');
  }
  return Uri(
    scheme: gameInviteScheme,
    host: gameInviteHost,
    queryParameters: {'game': gameId},
  );
}

String? gameIdFromInviteUri(Uri uri) {
  if (uri.scheme.toLowerCase() != gameInviteScheme ||
      uri.host.toLowerCase() != gameInviteHost) {
    return null;
  }
  final gameId = uri.queryParameters['game']?.trim();
  return gameId != null && _gameIdPattern.hasMatch(gameId) ? gameId : null;
}

String gameInviteMessage({required String avatarName, Uri? inviteLink}) {
  return '$avatarName has invited you to a chess game in Battle Chess Arena!\n\n'
      'My Avatar name: $avatarName\n\n'
      '${inviteLink == null ? '' : 'Tap to play: $inviteLink\nThis link expires 24 hours after creation.\n\nIf the link does not open, '}'
      'Open Battle Chess Arena → Play Online, search for my Avatar name '
      '"$avatarName", and send me an invite to play!';
}

Uri whatsAppInviteUri({required String avatarName, Uri? inviteLink}) =>
    Uri.https('wa.me', '/', {
      'text': gameInviteMessage(avatarName: avatarName, inviteLink: inviteLink),
    });
