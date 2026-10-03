import 'dart:async';

import 'package:battle_chess_arena/src/app.dart';
import 'package:battle_chess_arena/src/features/online/online_lobby_screen.dart';
import 'package:battle_chess_arena/src/services/game_invite_links.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_music_test.dart' show FakeMusicOutput;

void main() {
  test('HTTPS invite includes direct link and Avatar-name fallback', () {
    final link = sharedInviteUri('invite_1234');
    expect(link.scheme, 'https');
    expect(sharedInviteIdFromUri(link), 'invite_1234');
    expect(
      sharedInviteIdFromUri(
        Uri.parse('battlechessarena://invite?invite=invite_1234'),
      ),
      'invite_1234',
    );
    expect(
      sharedInviteIdFromUri(
        Uri.parse('https://attacker.example/invite/invite_1234'),
      ),
      isNull,
    );
    expect(sharedInviteIdFromUri(link.replace(path: '/invite/a/b')), isNull);
    final message = whatsAppInviteUri(
      avatarName: 'Nova Knight',
      inviteLink: link,
    ).queryParameters['text']!;
    expect(message, contains('Tap to play: $link'));
    expect(message, contains('If the link does not open'));
    expect(message, contains('search for my Avatar name "Nova Knight"'));
    expect(message, contains('send me an invite to play'));
    expect(message, isNot(contains('game code')));
  });

  testWidgets('HTTPS invitation opens the revocable invitation flow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final links = StreamController<Uri>();
    addTearDown(links.close);
    await tester.pumpWidget(
      BattleChessArenaApp(
        musicOutput: FakeMusicOutput(),
        incomingLinks: links.stream,
      ),
    );
    links.add(sharedInviteUri('invite_1234'));
    await tester.pumpAndSettle();
    final lobby = tester.widget<OnlineLobbyScreen>(
      find.byType(OnlineLobbyScreen),
    );
    expect(lobby.initialSharedInviteId, 'invite_1234');
    expect(lobby.initialGameId, isNull);
  });
  test(
    'legacy links still parse; WhatsApp shares only Avatar instructions',
    () {
      final link = gameInviteUri('room_1234');
      expect(link.toString(), 'battlechessarena://join?game=room_1234');
      expect(gameIdFromInviteUri(link), 'room_1234');
      expect(gameIdFromInviteUri(Uri.parse('https://example.com')), isNull);

      final whatsapp = whatsAppInviteUri(avatarName: 'Knight Friend');
      expect(whatsapp.host, 'wa.me');
      expect(whatsapp.queryParameters['text'], contains('Knight Friend'));
      expect(
        whatsapp.queryParameters['text'],
        contains('search for my Avatar name'),
      );
      expect(whatsapp.queryParameters['text'], contains('send me an invite'));
      expect(whatsapp.queryParameters['text'], isNot(contains('room_1234')));
      expect(
        whatsapp.queryParameters['text'],
        isNot(contains('battlechessarena://')),
      );
    },
  );

  testWidgets('incoming invite opens online play with the shared game ID', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final links = StreamController<Uri>();
    addTearDown(links.close);
    await tester.pumpWidget(
      BattleChessArenaApp(
        musicOutput: FakeMusicOutput(),
        incomingLinks: links.stream,
      ),
    );
    links.add(Uri.parse('battlechessarena://join?game=room_5678'));
    await tester.pumpAndSettle();

    final lobby = tester.widget<OnlineLobbyScreen>(
      find.byType(OnlineLobbyScreen),
    );
    expect(lobby.initialGameId, 'room_5678');
    expect(find.text('Create your online Avatar ID'), findsOneWidget);
  });
}
