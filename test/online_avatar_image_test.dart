import 'package:battle_chess_arena/src/domain/online_player_profile.dart';
import 'package:battle_chess_arena/src/features/online/online_avatar_image.dart';
import 'package:battle_chess_arena/src/features/online/avatar_portrait_regions.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('face avatars use measured isolated portrait regions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            OnlineAvatarImage(avatarId: 'avatar-01'),
            OnlineAvatarImage(avatarId: 'avatar-50'),
            OnlineAvatarImage(avatarId: 'bot_amina'),
          ],
        ),
      ),
    );

    final images = tester.widgetList<AvatarPortrait>(
      find.byType(AvatarPortrait),
    );
    expect(images, hasLength(3));
    expect(
      images.take(2).every((image) => image.asset == OnlineAvatarImage.atlas),
      isTrue,
    );
    expect(images.last.asset, OnlineAvatarImage.botAtlas);
    expect(images.first.source, humanPortraitRegions.first);
    expect(images.elementAt(1).source, humanPortraitRegions.last);
    expect(images.last.source, botPortraitRegions.first);
    expect(find.byType(OverflowBox), findsNothing);
  });

  test('all portrait bounds are disjoint and stay inside the atlas', () {
    for (final (regions, width, height, count) in [
      (humanPortraitRegions, 1800.0, 900.0, 50),
      (botPortraitRegions, 1280.0, 1024.0, 20),
    ]) {
      expect(regions.length, count);
      for (var i = 0; i < regions.length; i++) {
        final rect = regions[i];
        expect(
          rect.left >= 0 &&
              rect.top >= 0 &&
              rect.right <= width &&
              rect.bottom <= height,
          true,
        );
        for (var j = i + 1; j < regions.length; j++) {
          expect(
            rect.overlaps(regions[j]),
            false,
            reason: 'Portraits $i and $j overlap',
          );
        }
      }
    }
  });

  testWidgets('renders every actual portrait for crop review', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 840));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final boundaryKey = GlobalKey();
    final ids = [
      ...onlineAvatarChoices.map((a) => a.id),
      ...builtInComputerOpponents.map((b) => b.avatarId),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: Colors.white,
              child: Wrap(
                children: [
                  for (var i = 0; i < ids.length; i++)
                    SizedBox(
                      width: 100,
                      height: 120,
                      child: Column(
                        children: [
                          OnlineAvatarImage(avatarId: ids[i], size: 96),
                          Text(
                            '${i < 50 ? 'Human' : 'Bot'} ${i < 50 ? i + 1 : i - 49}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final context = tester.element(find.byType(Wrap));
      await precacheImage(const AssetImage(OnlineAvatarImage.atlas), context);
      if (context.mounted) {
        await precacheImage(
          const AssetImage(OnlineAvatarImage.botAtlas),
          context,
        );
      }
    });
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is AvatarPortraitPainter,
      ),
      findsNWidgets(70),
    );
    expect(tester.takeException(), isNull);
    if (Platform.environment['AVATAR_REVIEW'] == '1') {
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/avatar-review/all-portraits.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });

  test('all twenty bots map uniquely to their dedicated portrait cells', () {
    final indexes = builtInComputerOpponents
        .map((bot) => OnlineAvatarImage(avatarId: bot.avatarId).botAvatarIndex)
        .toList();

    expect(indexes, List<int>.generate(20, (index) => index));
    expect(indexes.toSet(), hasLength(20));
  });

  testWidgets('avatar picker exposes all fifty selectable portraits', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => OnlineAvatarPicker(
              selectedId: selected ?? 'avatar-01',
              onSelected: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('human-avatar-picker')), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('selected-avatar-preview')))
          .width,
      120,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('avatar-avatar-01'))).width,
      greaterThanOrEqualTo(96),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('avatar-avatar-50')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('avatar-avatar-50')));
    expect(selected, 'avatar-50');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OnlineAvatarImage>(
            find.byKey(const ValueKey('selected-avatar-preview')),
          )
          .avatarId,
      'avatar-50',
    );
  });
}
