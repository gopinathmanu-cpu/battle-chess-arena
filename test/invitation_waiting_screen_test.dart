import 'package:battle_chess_arena/src/domain/online_social.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/online/invitation_waiting_screen.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/online_fixtures.dart';

void main() {
  final pending = OnlineInvitation(
    inviteId: 'invite-one',
    senderName: 'Me',
    senderAvatarId: 'sun',
    recipientName: 'Friend',
    recipientAvatarId: 'moon',
    status: 'pending',
    createdAt: DateTime.now(),
    awaitingResponseFromName: 'Friend',
    timed: false,
    baseMs: 600000,
  );
  testWidgets(
    'waiting board cannot move, announces arrival and delays opening',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      await client.connect(Uri.parse('ws://localhost:8080'));
      final sounds = <MethodCall>[];
      const bridge = MethodChannel('battle_chess_arena/mobile_notifications');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(bridge, (
        call,
      ) async {
        sounds.add(call);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          bridge,
          null,
        ),
      );
      OnlineInviteGame? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: InvitationWaitingScreen(
            client: client,
            invitation: pending,
            pack: piecePacks.first,
            onReady: (game) async {
              opened = game;
            },
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Waiting for Friend'), findsOneWidget);
      expect(find.byType(ChessBoard), findsOneWidget);
      final board = tester.widget<ChessBoard>(find.byType(ChessBoard));
      expect(board.legalTargets, isEmpty);
      expect(board.appearance!.standardPieces, isTrue);
      channel.receive({
        'type': 'invite_updated',
        'invite': {
          'inviteId': 'invite-one',
          'sender': {'name': 'Me', 'avatarId': 'sun'},
          'recipient': {'name': 'Friend', 'avatarId': 'moon'},
          'status': 'accepted',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'game': {
            'gameId': 'room',
            'seat': 'w',
            'seatToken': 'secret',
            'state': stateJson(),
          },
        },
      });
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Friend joined!'), findsOneWidget);
      expect(opened, isNull);
      expect(sounds.where((call) => call.method == 'playAlert').length, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(opened?.gameId, 'room');
      await tester.pumpWidget(const SizedBox());
      client.dispose();
      await tester.pump();
    },
  );
}
