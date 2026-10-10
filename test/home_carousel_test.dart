import 'dart:io';
import 'dart:ui' as ui;

import 'package:battle_chess_arena/src/app.dart';
import 'package:battle_chess_arena/src/domain/online_player_profile.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/game_time_control.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/home/chess_set_carousel.dart';
import 'package:battle_chess_arena/src/features/home/chess_set_family_selector.dart';
import 'package:battle_chess_arena/src/features/online/online_avatar_image.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/neon_illustrated_stage.dart';
import 'package:battle_chess_arena/src/services/home_chess_set.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/game_history_storage.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:battle_chess_arena/src/services/online_game_history.dart';
import 'package:dartchess/dartchess.dart' show Chess, Side;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_music_test.dart' show FakeMusicOutput;
import 'support/piece_choice.dart';

// Optional screenshots: --dart-define=HOME_VISUALS=true and
// --dart-define=HOME_FONT_DIR=<flutter>/bin/cache/artifacts/material_fonts
const captureVisuals = bool.fromEnvironment('HOME_VISUALS');

void main() {
  final boardPieces = find.descendant(
    of: find.byType(ChessBoard),
    matching: find.byType(CharacterPiece),
  );
  final boundaryKey = GlobalKey();
  setUpAll(() async {
    const fontDirectory = String.fromEnvironment('HOME_FONT_DIR');
    if (!captureVisuals || fontDirectory.isEmpty) return;
    for (final entry in {
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final bytes = await File('$fontDirectory/${entry.value}').readAsBytes();
      await (FontLoader(
        entry.key,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });

  Future<void> openHome(WidgetTester tester) async {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: BattleChessArenaApp(
          musicOutput: FakeMusicOutput(),
          incomingLinks: const Stream.empty(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (captureVisuals) {
      await tester.runAsync(() async {
        final context = tester.element(find.byType(ChessSetCarousel));
        for (final path in [
          CharacterPiece.atlas,
          'assets/characters/classic-piece-variations-atlas.png',
        ]) {
          if (context.mounted) await precacheImage(AssetImage(path), context);
        }
      });
      await tester.pumpAndSettle();
    }
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!captureVisuals) return;
    final context = tester.element(find.byType(ChessSetCarousel));
    final visibleAtlases = tester
        .widgetList<CharacterPiece>(find.byType(CharacterPiece))
        .map(
          (piece) => piece.standard
              ? 'assets/characters/classic-piece-variations-atlas.png'
              : piece.atlasAsset,
        )
        .toSet();
    visibleAtlases.addAll(
      tester
          .widgetList<NeonFigureSprite>(find.byType(NeonFigureSprite))
          .map((figure) => figure.theme.castAsset(figure.piece.color)),
    );
    await tester.runAsync(() async {
      for (final asset in visibleAtlases) {
        await precacheImage(
          AssetImage(asset),
          context,
          onError: (error, stack) => fail('Cannot capture $asset: $error'),
        );
      }
      // Allow the sprite alpha-bound worker to finish outside the fake clock.
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
    // The test engine forces family-less dropdown text to Ahem. Use the
    // loaded Android font for that captured label only; leave production
    // styles and normal widget-test font metrics unchanged.
    final filterText = find.descendant(
      of: find.byKey(const ValueKey('chess-set-group-filter')),
      matching: find.byType(RichText, skipOffstage: false),
      skipOffstage: false,
    );
    for (final paragraph in tester.renderObjectList<RenderParagraph>(
      filterText,
    )) {
      final family = paragraph.text.style?.fontFamily;
      if (family != null && family != 'Ahem') continue;
      paragraph.text = TextSpan(
        text: paragraph.text.toPlainText(),
        style: (paragraph.text.style ?? const TextStyle()).copyWith(
          fontFamily: 'Roboto',
        ),
      );
    }
    await tester.pump();
    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = await Directory(
        'build/home-visuals',
      ).create(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> next(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('next-chess-set'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> chooseFamily(WidgetTester tester, String key) async {
    final choice = find.byKey(ValueKey(key));
    await tester.ensureVisible(choice);
    await tester.pumpAndSettle();
    await tester.tap(choice);
    await tester.pumpAndSettle();
  }

  testWidgets('family cards show game artwork and selected semantics', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final semantics = tester.ensureSemantics();
    try {
      await openHome(tester);
      final welcome = find.byKey(const ValueKey('home-welcome-banner'));
      expect(welcome, findsOneWidget);
      expect(find.text('Guest'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('edit-home-guest-profile')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: welcome, matching: find.byType(Image)),
        findsNothing,
      );
      final artwork = tester
          .widgetList<CharacterPiece>(
            find.descendant(
              of: find.byType(ChessSetFamilySelector),
              matching: find.byType(CharacterPiece),
            ),
          )
          .toList();
      expect(artwork, hasLength(2));
      expect(artwork.first.standard, isTrue);
      expect(artwork.last.standard, isFalse);
      expect(artwork.every((piece) => !piece.showRole), isTrue);
      final themed = find.bySemanticsLabel('Animated chess sets, 4 variations');
      final classic = find.bySemanticsLabel('Classic chess sets, 4 variations');
      expect(
        tester.getTopLeft(classic).dx,
        lessThan(tester.getTopLeft(themed).dx),
      );
      expect(
        tester.getSemantics(classic),
        matchesSemantics(
          label: 'Classic chess sets, 4 variations',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      await chooseFamily(tester, 'choose-themed');
      expect(
        tester.getSemantics(themed),
        matchesSemantics(
          label: 'Animated chess sets, 4 variations',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      expect(find.text('Manga Vanguard'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Animated family artwork stays enlarged while browsing at $width / $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          SharedPreferences.setMockInitialValues({});
          await openHome(tester);
          await chooseFamily(tester, 'choose-themed');
          final animated = find.byKey(const ValueKey('choose-themed'));
          final classic = find.byKey(const ValueKey('choose-classic'));
          for (var index = 0; index < availablePiecePacks.length; index++) {
            await tester.ensureVisible(animated);
            await tester.pumpAndSettle();
            final artwork = find.descendant(
              of: animated,
              matching: find.byType(CharacterPiece),
            );
            final classicArtwork = find.descendant(
              of: classic,
              matching: find.byType(CharacterPiece),
            );
            expect(tester.getSize(artwork), const Size.square(64));
            expect(tester.getSize(classicArtwork), const Size(52, 56));
            expect(
              tester.widget<CharacterPiece>(artwork).pack.id,
              availablePiecePacks[index].id,
            );
            expect(tester.widget<CharacterPiece>(artwork).standard, isFalse);
            expect(
              tester.widget<CharacterPiece>(classicArtwork).standard,
              isTrue,
            );
            for (final (card, title) in [
              (animated, 'Animated'),
              (classic, 'Classic'),
            ]) {
              final cardRect = tester.getRect(card);
              final label = find.descendant(
                of: card,
                matching: find.text(title),
              );
              final labelRect = tester.getRect(label);
              expect(labelRect.left - cardRect.left, closeTo(65, .001));
              expect(labelRect.right, lessThanOrEqualTo(cardRect.right));
              expect(labelRect.top, greaterThanOrEqualTo(cardRect.top));
              expect(labelRect.bottom, lessThanOrEqualTo(cardRect.bottom));
              final icon = find.descendant(
                of: card,
                matching: find.byType(CharacterPiece),
              );
              final iconRect = tester.getRect(icon);
              expect(iconRect.left, greaterThanOrEqualTo(cardRect.left));
              expect(iconRect.right, lessThan(labelRect.left));
              expect(iconRect.top, greaterThanOrEqualTo(cardRect.top));
              expect(iconRect.bottom, lessThanOrEqualTo(cardRect.bottom));
            }
            expect(tester.takeException(), isNull);
            if (index + 1 < availablePiecePacks.length) {
              final carousel = find.byType(PageView);
              await tester.ensureVisible(carousel);
              await tester.pumpAndSettle();
              await tester.drag(carousel, Offset(-width * .65, 0));
              await tester.pumpAndSettle();
            }
          }
          await chooseFamily(tester, 'choose-classic');
          expect(
            tester
                .widget<ChessSetCarousel>(find.byType(ChessSetCarousel))
                .classic,
            isTrue,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }

  testWidgets(
    'old Home preference cannot introduce an unavailable new-game army',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      const old = HomeChessSet(pack: PiecePackId.japanese, classic: false);
      await old.save();
      await openHome(tester);
      final carousel = tester.widget<ChessSetCarousel>(
        find.byType(ChessSetCarousel),
      );
      expect(carousel.pack.id, PiecePackId.anime);
      expect(carousel.themedPacks, availablePiecePacks);
      expect(carousel.count, 4);
      expect(find.text('Manga Vanguard'), findsOneWidget);
      // Loading the picker does not rewrite the persisted old preference.
      expect((await HomeChessSet.load()).pack, PiecePackId.japanese);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resuming an old army keeps it on the match and leaves new choices curated',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await LastGameStorage.clear();
      await LastGameStorage.save(
        const SavedGame(
          mode: PlayerMode.local,
          humanSide: Side.white,
          homePack: PiecePackId.japanese,
          difficulty: ComputerDifficulty.medium,
          moves: ['e2e4', 'e7e5'],
          whiteMilliseconds: 600000,
          blackMilliseconds: 600000,
          fastBattles: true,
          whitePack: PiecePackId.japanese,
          blackPack: PiecePackId.japanese,
          boardPack: PiecePackId.japanese,
          updatedAtEpochMs: 1,
          timeControl: GameTimeControl.practice,
        ),
      );
      Future<void> until(Finder target) async {
        for (var frame = 0; target.evaluate().isEmpty && frame < 50; frame++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(target, findsOneWidget);
      }

      try {
        await openHome(tester);
        await tester.tap(find.byKey(const ValueKey('play-computer-button')));
        await until(find.text('Resume Last Game'));
        await tester.tap(find.text('Resume Last Game'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('piece-type-choice')), findsNothing);
        expect(
          tester
              .widget<AnimationLabScreen>(find.byType(AnimationLabScreen))
              .pack
              .id,
          PiecePackId.japanese,
        );
        expect(
          tester
              .widget<ChessBoard>(find.byType(ChessBoard))
              .appearance!
              .white
              .id,
          PiecePackId.japanese,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ChessSetCarousel>(find.byType(ChessSetCarousel))
              .pack
              .id,
          PiecePackId.anime,
        );
        await tester.tap(find.byKey(const ValueKey('play-computer-button')));
        await until(find.text('New Game'));
        await tester.tap(find.text('New Game'));
        await until(find.byKey(const ValueKey('computer-difficulty-easy')));
        await tester.tap(
          find.byKey(const ValueKey('computer-difficulty-easy')),
        );
        await tester.tap(find.byKey(const ValueKey('start-computer-game')));
        await chooseGamePieces(tester);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AnimationLabScreen>(find.byType(AnimationLabScreen))
              .pack
              .id,
          PiecePackId.anime,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        var drained = false;
        GameHistoryStorage().loadSnapshot().then((_) => drained = true);
        for (var frame = 0; !drained && frame < 40; frame++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(drained, isTrue);
        await LastGameStorage.clear();
      }
    },
  );

  testWidgets('guest edit action opens the name and avatar editor', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await openHome(tester);

    await tester.tap(find.byKey(const ValueKey('edit-home-guest-profile')));
    await tester.pumpAndSettle();

    expect(find.text('Create online avatar'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-online-avatar-name')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('save-online-profile-settings')),
      findsOneWidget,
    );
  });

  testWidgets('saved avatar and name replace the generic welcome banner', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await OnlineGameHistory.saveProfile(
      const OnlinePlayerProfile(name: 'Nova Knight', avatarId: 'avatar-07'),
    );

    await openHome(tester);

    final banner = find.byKey(const ValueKey('home-welcome-banner'));
    expect(
      find.descendant(of: banner, matching: find.text('WELCOME TO')),
      findsNothing,
    );
    expect(
      find.descendant(of: banner, matching: find.text('Battle Chess Arena')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('home-avatar-profile')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-avatar-name')), findsOneWidget);
    expect(find.text('YOUR AVATAR'), findsNothing);
    expect(find.text('Nova Knight'), findsOneWidget);
    expect(
      find.descendant(
        of: banner,
        matching: find.byKey(const ValueKey('arena-credit-header')),
      ),
      findsOneWidget,
    );
    final avatar = tester.widget<OnlineAvatarImage>(
      find.byKey(const ValueKey('home-avatar-image')),
    );
    expect(avatar.avatarId, 'avatar-07');
    expect(avatar.size, 60);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            RegExp(
              r'^(Experience|Exp) 0 XP  ·  Trophies 0$',
            ).hasMatch(widget.data ?? ''),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-avatar-details')), findsOneWidget);
    expect(find.byKey(const ValueKey('badge-subtitle')), findsOneWidget);
    expect(find.text('♙ Arena Rookie  ·  0 pts'), findsOneWidget);
    expect(find.byKey(const ValueKey('preferred-name-prompt')), findsNothing);
  });

  testWidgets('settings distinguish private nickname from public avatar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await openHome(tester);
    await tester.tap(find.byKey(const ValueKey('home-settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('Private in-app nickname'), findsOneWidget);
    expect(
      find.textContaining('online players will not see it'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('online-profile-settings')),
      findsOneWidget,
    );
    expect(
      find.text('Set the public name and image other online players will see'),
      findsOneWidget,
    );
    final nicknameCard = tester.getRect(
      find.byKey(const ValueKey('preferred-name-settings')),
    );
    final avatarCard = tester.getRect(
      find.byKey(const ValueKey('online-profile-settings')),
    );
    expect(nicknameCard.bottom, lessThanOrEqualTo(avatarCard.top));

    await tester.tap(find.byKey(const ValueKey('online-profile-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Create online avatar'), findsOneWidget);
    expect(find.textContaining('Other players will see them'), findsOneWidget);
    expect(
      find.textContaining('separate from your private in-app nickname'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('settings-online-avatar-name')),
      'ab',
    );
    final secondAvatar = find.byKey(const ValueKey('avatar-avatar-02'));
    tester.widget<InkWell>(secondAvatar).onTap!();
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('save-online-profile-settings')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Use 3–20 standard keyboard characters'), findsOneWidget);
    expect(await OnlineGameHistory.loadProfile(), isNull);
  });

  testWidgets('double tapping the board preview triggers Play Computer', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await openHome(tester);
    final preview = find.byKey(const ValueKey('home-board-double-tap-target'));
    final hint = find.byKey(const ValueKey('quick-computer-game-hint'));
    expect(hint, findsOneWidget);
    expect(
      find.text('Scroll left or right to select chess set'),
      findsOneWidget,
    );
    expect(
      find.text('Double click to start quick game with computer'),
      findsOneWidget,
    );
    expect(
      (tester.getCenter(hint) - tester.getCenter(preview)).distance,
      lessThan(1),
    );
    expect(
      tester
          .widget<Text>(
            find.text('Double click to start quick game with computer'),
          )
          .style
          ?.fontSize,
      10,
    );
    final scrollMessage = find.text('Scroll left or right to select chess set');
    final quickGameMessage = find.text(
      'Double click to start quick game with computer',
    );
    expect(
      tester.widget<Text>(scrollMessage).style?.fontSize,
      tester.widget<Text>(quickGameMessage).style?.fontSize,
    );
    expect(
      tester.getTopLeft(quickGameMessage).dy -
          tester.getBottomLeft(scrollMessage).dy,
      greaterThanOrEqualTo(5),
    );

    await tester.tap(preview);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('computer-difficulty-dialog')),
      findsNothing,
    );

    await tester.tap(preview);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(preview);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('computer-difficulty-dialog')),
      findsOneWidget,
    );
    expect(find.text('Choose computer difficulty'), findsOneWidget);
    expect(find.byKey(const ValueKey('start-computer-game')), findsOneWidget);
  });

  testWidgets('full board, swipe, arrows and family memory agree', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await openHome(tester);
    final board = tester.widget<ChessBoard>(find.byType(ChessBoard));
    expect(board.position.fen, Chess.initial.fen);
    expect(boardPieces, findsNWidgets(32));
    expect(board.appearance!.standardPieces, isTrue);
    await chooseFamily(tester, 'choose-themed');
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Epic Guardians'), findsOneWidget);
    await next(tester);
    expect(find.text('Olympian Legion'), findsOneWidget);
    await chooseFamily(tester, 'choose-classic');
    expect(find.text('Magnetic 3D'), findsOneWidget);
    await next(tester);
    expect(find.text('Wooden 3D'), findsOneWidget);
    expect(
      tester
          .widget<ChessBoard>(find.byType(ChessBoard))
          .appearance!
          .classicStyle,
      ClassicPieceStyle.wood,
    );
    await chooseFamily(tester, 'choose-themed');
    expect(find.text('Olympian Legion'), findsOneWidget);
    expect(
      tester.widget<ChessBoard>(find.byType(ChessBoard)).appearance!.board.id,
      PiecePackId.greek,
    );
    await chooseFamily(tester, 'choose-classic');
    expect(find.text('Wooden 3D'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtered carousel maps pages to real catalogue indices', (
    tester,
  ) async {
    var selected = piecePacks[1];
    final changes = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 240,
                child: ChessSetCarousel(
                  pack: selected,
                  classic: false,
                  style: ClassicPieceStyle.magneticTeaching,
                  themedPacks: [piecePacks[1], piecePacks[3]],
                  onChanged: (index) {
                    changes.add(index);
                    setState(() => selected = piecePacks[index]);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 / 2 · Swipe to choose'), findsOneWidget);
    await next(tester);
    expect(changes, [3]);
    expect(selected.id, PiecePackId.futuristic);
    expect(find.text('Neon Dominion'), findsOneWidget);
    expect(find.text('2 / 2 · Swipe to choose'), findsOneWidget);
    await next(tester);
    expect(changes, [3, 1]);
    expect(selected.id, PiecePackId.indianEpic);
    expect(find.text('Epic Guardians'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only available Fantasy filters browse the four Animated sets', (
    tester,
  ) async {
    if (captureVisuals) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);
    }
    SharedPreferences.setMockInitialValues({});
    await openHome(tester);
    await chooseFamily(tester, 'choose-themed');
    final filter = find.byKey(const ValueKey('chess-set-group-filter'));
    Future<void> chooseGroup(String label) async {
      await tester.ensureVisible(filter);
      await tester.pumpAndSettle();
      await tester.tap(filter);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    final dropdown = tester.widget<DropdownButton>(filter);
    expect(dropdown.items!.map((item) => (item.child as Text).data), [
      'All themes',
      'Fantasy',
    ]);
    expect(find.byKey(const ValueKey('create-custom-theme')), findsNothing);
    await chooseGroup('Fantasy');
    expect(find.text('Manga Vanguard'), findsOneWidget);
    expect(find.text('1 / 4 · Swipe to choose'), findsOneWidget);
    await next(tester);
    expect(find.text('Epic Guardians'), findsOneWidget);
    expect((await HomeChessSet.load()).pack, PiecePackId.indianEpic);
    await chooseGroup('All themes');
    expect(find.text('Epic Guardians'), findsOneWidget);
    expect(find.text('2 / 4 · Swipe to choose'), findsOneWidget);
    expect(find.text('Historical'), findsNothing);
    expect(find.text('Legendary'), findsNothing);

    await chooseFamily(tester, 'choose-classic');
    expect(filter, findsNothing);
    await next(tester);
    expect(find.text('Wooden 3D'), findsOneWidget);
    await chooseFamily(tester, 'choose-themed');
    expect(filter, findsOneWidget);
    expect(find.text('Epic Guardians'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await openHome(tester);
    expect(find.text('All themes'), findsOneWidget);
    expect(find.text('Epic Guardians'), findsOneWidget);
    expect((await HomeChessSet.load()).pack, PiecePackId.indianEpic);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all eight available previews use the correct complete game artwork',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await openHome(tester);
      for (final classic in [true, false]) {
        if (!classic) await chooseFamily(tester, 'choose-themed');
        final count = classic
            ? ClassicPieceStyle.values.length
            : availablePiecePacks.length;
        for (var index = 0; index < count; index++) {
          final board = tester.widget<ChessBoard>(find.byType(ChessBoard));
          final pieces = tester.widgetList<CharacterPiece>(boardPieces);
          expect(pieces, hasLength(32));
          expect(board.showPieceRoles, isFalse);
          expect(pieces.every((piece) => !piece.showRole), isTrue);
          expect(board.position.fen, Chess.initial.fen);
          expect(board.appearance!.standardPieces, classic);
          expect(board.appearance!.animatedArena, !classic);
          if (classic) {
            expect(
              pieces.every(
                (piece) =>
                    piece.standard &&
                    piece.classicStyle == ClassicPieceStyle.values[index],
              ),
              isTrue,
            );
          } else {
            expect(
              pieces.every(
                (piece) =>
                    !piece.standard &&
                    piece.pack.id == availablePiecePacks[index].id,
              ),
              isTrue,
            );
          }
          await next(tester);
        }
      }
    },
  );

  testWidgets('arrows wrap and selection survives relaunch into a new game', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await openHome(tester);
    await chooseFamily(tester, 'choose-themed');
    final previous = find.byKey(const ValueKey('previous-chess-set'));
    await tester.ensureVisible(previous);
    await tester.pumpAndSettle();
    await tester.tap(previous);
    await tester.pumpAndSettle();
    expect(find.text('Neon Dominion'), findsOneWidget);
    await next(tester);
    expect(find.text('Manga Vanguard'), findsOneWidget);
    await next(tester);
    await chooseFamily(tester, 'choose-classic');
    await next(tester);
    await next(tester);
    final saved = await HomeChessSet.load();
    expect(saved.pack, PiecePackId.indianEpic);
    expect(saved.classic, isTrue);
    expect(saved.style, ClassicPieceStyle.plastic);
    await tester.pumpWidget(const SizedBox.shrink());
    await openHome(tester);
    expect(find.text('Flat Club'), findsOneWidget);
    expect(
      tester
          .widget<ChessBoard>(find.byType(ChessBoard))
          .appearance!
          .classicStyle,
      ClassicPieceStyle.plastic,
    );
    await tester.tap(find.byKey(const ValueKey('play-computer-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('computer-difficulty-easy')));
    await tester.tap(find.byKey(const ValueKey('start-computer-game')));
    await chooseGamePieces(tester);
    await tester.pumpAndSettle();
    final game = tester.widget<AnimationLabScreen>(
      find.byType(AnimationLabScreen),
    );
    expect(game.pack.id, PiecePackId.indianEpic);
    expect(game.initialClassicPieces, isTrue);
    expect(game.initialAnimatedArena, isFalse);
    expect(game.initialClassicStyle, ClassicPieceStyle.plastic);
    expect(game.timeControl.timed, isFalse);
    expect(
      tester.widget<ChessBoard>(find.byType(ChessBoard)).showPieceRoles,
      isTrue,
    );
    expect(
      tester
          .widgetList<CharacterPiece>(boardPieces)
          .every((piece) => piece.showRole),
      isTrue,
    );
  });

  testWidgets(
    'Home Settings offers all eight sets and launches the selected family',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await openHome(tester);
      await tester.tap(find.byKey(const ValueKey('home-settings-button')));
      await tester.pumpAndSettle();
      final settingsScroll = find
          .descendant(
            of: find.byKey(const ValueKey('game-settings-list')),
            matching: find.byType(Scrollable),
          )
          .first;
      for (final style in ClassicPieceStyle.values) {
        final option = find.byKey(ValueKey('settings-classic-${style.name}'));
        await tester.scrollUntilVisible(
          option,
          150,
          scrollable: settingsScroll,
        );
        await tester.pumpAndSettle();
        await tester.tap(option);
        await tester.pumpAndSettle();
        final saved = await HomeChessSet.load();
        expect(saved.classic, isTrue);
        expect(saved.style, style);
      }
      for (final pack in availablePiecePacks) {
        final option = find.byKey(
          ValueKey('settings-animated-${pack.id.name}'),
        );
        await tester.scrollUntilVisible(
          option,
          150,
          scrollable: settingsScroll,
        );
        await tester.pumpAndSettle();
        await tester.tap(option);
        await tester.pumpAndSettle();
        final saved = await HomeChessSet.load();
        expect(saved.classic, isFalse);
        expect(saved.pack, pack.id);
      }
      await tester.tap(find.byTooltip('Close settings'));
      await tester.pumpAndSettle();
      final play = find.byKey(const ValueKey('play-computer-button'));
      await tester.ensureVisible(play);
      await tester.pumpAndSettle();
      await tester.tap(play);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('computer-difficulty-easy')));
      await tester.tap(find.byKey(const ValueKey('start-computer-game')));
      await chooseGamePieces(tester, classic: false);
      final game = tester.widget<AnimationLabScreen>(
        find.byType(AnimationLabScreen),
      );
      expect(game.pack.id, availablePiecePacks.last.id);
      expect(game.initialAnimatedArena, isTrue);
      expect(game.timeControl.timed, isFalse);
      expect(find.byKey(const ValueKey('piece-type-choice')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home opens separate tournament and conquest catalogs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await openHome(tester);
    await tester.ensureVisible(find.text('Conquests'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conquests'));
    await tester.pumpAndSettle();
    expect(find.text('Indo-Arabian Conquest'), findsOneWidget);
    expect(find.text('Rising Knights Cup'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tournaments'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tournaments'));
    await tester.pumpAndSettle();
    expect(find.text('Rising Knights Cup'), findsOneWidget);
    expect(find.text('Indo-Arabian Conquest'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('home board and actions stay usable at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);
      SharedPreferences.setMockInitialValues({});
      await openHome(tester);
      await chooseFamily(tester, 'choose-themed');
      final rect = tester.getRect(find.byType(ChessBoard));
      final previewWidth = tester
          .getSize(find.byKey(const ValueKey('home-board-preview')))
          .width;
      final chooserWidth = tester
          .getSize(find.byType(ChessSetFamilySelector))
          .width;
      expect(rect.width, closeTo(rect.height, .01));
      expect(previewWidth, closeTo(chooserWidth, .01));
      if (size == const Size(390, 844)) {
        expect(rect.bottom, lessThan(size.height - 24));
      }
      expect(boardPieces, findsNWidgets(32));
      await capture(
        tester,
        'themed-${size.width.toInt()}x${size.height.toInt()}',
      );
      for (final label in [
        'Play Computer',
        'Play Online',
        'Tournaments',
        'Conquests',
      ]) {
        // Very short and wide screens retain scrolling rather than shrinking
        // the full-width board below a readable size.
        if (find.text(label).hitTestable().evaluate().isEmpty) {
          await tester.ensureVisible(find.text(label));
          await tester.pumpAndSettle();
        }
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await chooseFamily(tester, 'choose-classic');
      await next(tester);
      await next(tester);
      await capture(
        tester,
        'classic-${size.width.toInt()}x${size.height.toInt()}',
      );
    });
  }

  testWidgets('large text remains usable with vertical scrolling', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    await openHome(tester);
    await tester.scrollUntilVisible(
      find.text('Tournaments'),
      160,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('home-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Tournaments').hitTestable(), findsOneWidget);
    expect(find.byType(ChessSetCarousel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'narrow picker offers four Fantasy realms while retaining a saved army',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      BoardAppearance? chosen;
      final initial = BoardAppearance.forPack(
        piecePacks.firstWhere((pack) => pack.id == PiecePackId.chinese),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    chosen = await chooseBoardAppearance(context, initial);
                  },
                  child: const Text('Choose realm'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose realm'));
      await tester.pumpAndSettle();
      final fields = find.byType(DropdownButtonFormField<PiecePack>);
      expect(fields, findsNWidgets(3));
      for (final field in tester.widgetList<DropdownButton<PiecePack>>(
        find.byType(DropdownButton<PiecePack>),
      )) {
        expect(field.items, hasLength(4));
      }
      expect(tester.takeException(), isNull);
      await tester.tap(fields.first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Neon Dominion'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      if (find.text('Neon Dominion').hitTestable().evaluate().isEmpty) {
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -80));
        await tester.pumpAndSettle();
      }
      expect(find.text('Neon Dominion').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Neon Dominion').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(chosen?.white.id, PiecePackId.futuristic);
      expect(chosen?.black.id, PiecePackId.chinese);
      expect(chosen?.board.id, PiecePackId.chinese);
      expect(tester.takeException(), isNull);
    },
  );
}
