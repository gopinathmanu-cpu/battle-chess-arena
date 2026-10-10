// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/online/online_avatar_image.dart';
import 'package:battle_chess_arena/src/features/online/online_game_screen.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/match_opponent_panel.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_arena.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_game_layout.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/online_fixtures.dart';

void main() {
  Future<OnlineMatchClient> open(
    WidgetTester tester,
    FakeChannel channel, {
    required bool animated,
    String seat = 'w',
    PiecePack? pack,
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = OnlineMatchClient(channelFactory: (_) => channel);
    await client.connect(Uri.parse('ws://localhost:8080'));
    channel.seat(
      seat: seat,
      state: stateJson(
        whiteName: 'White Rival',
        blackName: 'Black Rival',
        whiteAvatar: 'avatar-03',
        blackAvatar: 'avatar-12',
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: OnlineGameScreen(
          client: client,
          pack: pack ?? availablePiecePacks.first,
          initialAnimatedArena: animated,
          initialClassicPieces: !animated,
        ),
      ),
    );
    await tester.pump();
    return client;
  }

  Future<void> close(WidgetTester tester, OnlineMatchClient client) async {
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
    await tester.pump(const Duration(milliseconds: 30));
  }

  void expectOpponent(WidgetTester tester, String name, String avatar) {
    expect(find.byType(MatchOpponentPanel), findsOneWidget);
    expect(
      find.byKey(const ValueKey('online-opponent-profile')),
      findsOneWidget,
    );
    expect(find.byType(NeonLiveArena), findsNothing);
    expect(find.text(name), findsOneWidget);
    final portrait = tester.widget<OnlineAvatarImage>(
      find.descendant(
        of: find.byType(MatchOpponentPanel),
        matching: find.byType(OnlineAvatarImage),
      ),
    );
    expect(portrait.avatarId, avatar);
    expect(portrait.size, greaterThanOrEqualTo(48));
  }

  for (final pack in availablePiecePacks) {
    testWidgets(
      '${pack.name} shows the real opponent above the portrait board',
      (tester) async {
        final seat = pack == availablePiecePacks.first ? 'b' : 'w';
        final client = await open(
          tester,
          FakeChannel(),
          animated: true,
          pack: pack,
          seat: seat,
        );
        expectOpponent(
          tester,
          seat == 'w' ? 'Black Rival' : 'White Rival',
          seat == 'w' ? 'avatar-12' : 'avatar-03',
        );
        final profile = tester.getRect(find.byType(MatchOpponentPanel));
        final board = tester.getRect(find.byType(ChessBoard));
        expect(profile.bottom, lessThan(board.top));
        expect(profile.height, lessThan(120));
        expect(board.bottom, lessThanOrEqualTo(844));
        expect(
          tester
              .widget<ChessBoard>(find.byType(ChessBoard))
              .appearance!
              .white
              .id,
          pack.id,
        );
        expect(tester.takeException(), isNull);
        await close(tester, client);
      },
    );
  }

  for (final animated in [false, true]) {
    for (final size in [const Size(320, 568), const Size(650, 360)]) {
      final landscape = size.width > size.height;
      testWidgets(
        '${animated ? 'Animated' : 'Classic'} opponent and full board fit ${landscape ? 'landscape' : 'small portrait'} with enlarged text',
        (tester) async {
          final channel = FakeChannel();
          final client = await open(
            tester,
            channel,
            animated: animated,
            size: size,
            textScale: 2,
          );
          expectOpponent(tester, 'Black Rival', 'avatar-12');
          final profile = tester.getRect(find.byType(MatchOpponentPanel));
          final board = tester.getRect(find.byType(ChessBoard));
          expect(board.width, closeTo(board.height, .1));
          expect(board.right, lessThanOrEqualTo(size.width));
          expect(board.bottom, lessThanOrEqualTo(size.height));
          if (landscape) {
            expect(profile.right, lessThan(board.left));
            await tester.tap(
              find.byKey(const ValueKey('neon-live-swap-panels')),
            );
            await tester.pump();
            expect(
              tester.getRect(find.byType(ChessBoard)).right,
              lessThan(tester.getRect(find.byType(MatchOpponentPanel)).left),
            );
          } else {
            expect(profile.bottom, lessThan(board.top));
          }
          expect(
            tester
                .widget<NeonLiveGameLayout>(find.byType(NeonLiveGameLayout))
                .compactPortraitArena,
            isTrue,
          );
          expect(
            channel.sent.where((frame) => frame['type'] == 'move'),
            isEmpty,
          );
          expect(tester.takeException(), isNull);
          await close(tester, client);
        },
      );
    }
  }

  testWidgets('opponent header refreshes authoritative profile metadata', (
    tester,
  ) async {
    final channel = FakeChannel();
    final client = await open(tester, channel, animated: true);
    final state = stateJson(
      sequence: 2,
      blackName: 'Elena',
      blackAvatar: 'bot_elena',
    );
    (state['players'] as Map)['b'] = {
      'name': 'Elena',
      'avatarId': 'bot_elena',
      'level': 'advanced',
      'computer': true,
      'botLevel': 18,
    };
    channel.receive({'type': 'game_state', 'state': state});
    await tester.pump();
    await tester.pump();
    expect(client.state!.blackPlayer.name, 'Elena');
    expectOpponent(tester, 'Elena', 'bot_elena');
    expect(
      find.text('Advanced · Level 18 · Computer · Timed game'),
      findsOneWidget,
    );
    expect(find.text('Black Rival'), findsNothing);
    expect(tester.takeException(), isNull);
    await close(tester, client);
  });
}
