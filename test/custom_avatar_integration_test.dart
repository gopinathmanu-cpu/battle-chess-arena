import 'package:battle_chess_arena/src/domain/custom_avatar.dart';
import 'package:battle_chess_arena/src/domain/online_player_profile.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/online/custom_avatar_builder_screen.dart';
import 'package:battle_chess_arena/src/features/online/custom_avatar_portrait.dart';
import 'package:battle_chess_arena/src/features/online/online_avatar_image.dart';
import 'package:battle_chess_arena/src/features/online/online_lobby_screen.dart';
import 'package:battle_chess_arena/src/services/online_game_history.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/online_fixtures.dart';

void main() {
  testWidgets(
    'profile dialog commits custom avatar only after Save and acknowledgement',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      await client.connect(Uri.parse('ws://localhost:8080'));
      client.setProfile(
        const OnlinePlayerProfile(
          name: 'Avatar Tester',
          avatarId: 'avatar-02',
          playerToken: 'identity-token',
        ),
      );
      client.supportsCustomAvatars = true;
      client.activeGamesLoaded = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: OnlineLobbyScreen(client: client, pack: piecePacks.first),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      for (final commit in [false, true]) {
        await tester.tap(find.byTooltip('Edit Avatar ID and image'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('create-custom-avatar')),
        );
        await tester.tap(find.byKey(const ValueKey('create-custom-avatar')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('avatar-starter-girl')),
        );
        await tester.tap(find.byKey(const ValueKey('avatar-starter-girl')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('use-custom-avatar')));
        await tester.pumpAndSettle();
        final selected = tester
            .widget<OnlineAvatarImage>(
              find.byKey(const ValueKey('selected-avatar-preview')),
            )
            .avatarId;
        expect(CustomAvatarDesign.tryParse(selected)!.age, 0);
        expect(client.profile!.avatarId, 'avatar-02');
        expect(
          channel.sent.where((frame) => frame['type'] == 'update_player'),
          isEmpty,
        );
        await tester.tap(find.text(commit ? 'Save' : 'Cancel'));
        await tester.pumpAndSettle();
        if (!commit) {
          expect(client.profile!.avatarId, 'avatar-02');
          expect(
            channel.sent.where((frame) => frame['type'] == 'update_player'),
            isEmpty,
          );
        } else {
          final request = channel.sent.last;
          expect(request['type'], 'update_player');
          expect(request['avatarId'], selected);
          expect(client.profile!.avatarId, 'avatar-02');
          channel.receive({
            'type': 'player_updated',
            'commandId': request['commandId'],
            'name': request['name'],
            'avatarId': request['avatarId'],
            'level': request['level'],
            'playerToken': 'identity-token',
          });
          await tester.pumpAndSettle();
          expect(client.profile!.avatarId, selected);
          expect((await OnlineGameHistory.loadProfile())!.avatarId, selected);
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      client.dispose();
    },
  );

  testWidgets('custom avatars share the renderer used throughout online play', (
    tester,
  ) async {
    const design = CustomAvatarDesign(
      presentation: 1,
      age: 3,
      skinTone: 6,
      hairStyle: 9,
      eyewear: 2,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              OnlineAvatarImage(avatarId: design.avatarId, size: 44),
              const OnlineAvatarImage(avatarId: 'avatar-50'),
              const OnlineAvatarImage(avatarId: 'bot_amina'),
              const OnlineAvatarImage(avatarId: 'custom-v1-malformed'),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(CustomAvatarPortrait), findsOneWidget);
    final portrait = tester.widget<CustomAvatarPortrait>(
      find.byType(CustomAvatarPortrait),
    );
    expect(portrait.design, design);
    expect(portrait.size, 44);
    expect(find.byType(AvatarPortrait), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker creates, reopens and cancels custom avatar drafts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var selectedId = 'avatar-02';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: OnlineAvatarPicker(
                selectedId: selectedId,
                onSelected: (value) => setState(() => selectedId = value),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('create-custom-avatar')));
    await tester.pumpAndSettle();
    expect(find.byType(CustomAvatarBuilderScreen), findsOneWidget);
    expect(
      tester
          .widget<CustomAvatarBuilderScreen>(
            find.byType(CustomAvatarBuilderScreen),
          )
          .initialDesign,
      isNull,
    );
    const design = CustomAvatarDesign(age: 0, hairStyle: 4, skinTone: 7);
    Navigator.of(
      tester.element(find.byType(CustomAvatarBuilderScreen)),
    ).pop(design.avatarId);
    await tester.pumpAndSettle();
    expect(selectedId, design.avatarId);
    expect(find.text('Your custom avatar'), findsOneWidget);
    expect(find.text('Edit your avatar'), findsOneWidget);
    expect(
      tester
          .widget<OnlineAvatarImage>(
            find.byKey(const ValueKey('selected-avatar-preview')),
          )
          .avatarId,
      design.avatarId,
    );
    await tester.tap(find.byKey(const ValueKey('create-custom-avatar')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CustomAvatarBuilderScreen>(
            find.byType(CustomAvatarBuilderScreen),
          )
          .initialDesign,
      design,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(selectedId, design.avatarId);
    expect(find.byType(CustomAvatarBuilderScreen), findsNothing);
    await tester.tap(find.byKey(const ValueKey('avatar-avatar-01')));
    await tester.pumpAndSettle();
    expect(selectedId, 'avatar-01');
    expect(find.text('Create your avatar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
