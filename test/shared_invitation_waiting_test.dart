import 'package:battle_chess_arena/src/domain/online_social.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/online/invitation_waiting_screen.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/online_fixtures.dart';

void main() {
  testWidgets(
    'shared invitation waiting opens the owner seat after friend claims link',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      const bridge = MethodChannel('battle_chess_arena/mobile_notifications');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        bridge,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          bridge,
          null,
        ),
      );
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      await client.connect(Uri.parse('ws://localhost:8080'));
      client.sharedInvitations = [
        const SharedInvitation(
          inviteId: 'shared-one',
          avatarName: 'Host',
          status: 'pending',
        ),
      ];
      final placeholder = OnlineInvitation(
        inviteId: 'shared-one',
        senderName: 'Host',
        senderAvatarId: 'sun',
        recipientName: 'your friend',
        recipientAvatarId: 'crown',
        status: 'pending',
        createdAt: DateTime.now(),
        awaitingResponseFromName: 'your friend',
        timed: true,
        baseMs: 600000,
      );
      OnlineInviteGame? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: InvitationWaitingScreen(
            client: client,
            invitation: placeholder,
            sharedInviteId: 'shared-one',
            pack: piecePacks.first,
            onReady: (game) async {
              opened = game;
            },
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Waiting for your friend'), findsOneWidget);
      channel.receive({
        'type': 'shared_invite_updated',
        'invite': {
          'inviteId': 'shared-one',
          'avatarName': 'Host',
          'status': 'accepted',
          'gameId': 'room',
        },
      });
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Loading your game'), findsOneWidget);
      expect(opened, isNull);
      channel.receive({
        'type': 'game_activity',
        'game': {
          'gameId': 'room',
          'seat': 'b',
          'seatToken': 'owner-secret',
          'state': stateJson(whiteName: 'Guest', blackName: 'Host'),
        },
      });
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Guest joined!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(opened?.seat, 'b');
      expect(opened?.seatToken, 'owner-secret');
      await tester.pumpWidget(const SizedBox());
      client.dispose();
      await tester.pump();
    },
  );
}
