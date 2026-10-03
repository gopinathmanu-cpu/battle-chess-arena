import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/play/themed_piece_sprite.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _visuals = bool.fromEnvironment('THEMED_PIECE_VISUALS');
const _legacyOnly = bool.fromEnvironment('THEMED_PIECE_LEGACY_ONLY');
const _roles = CharacterPiece.roles;

void main() {
  setUpAll(() async {
    const directory = String.fromEnvironment('THEMED_PIECE_FONT_DIR');
    if (!_visuals || directory.isEmpty) return;
    final bytes = await io.File('$directory/Roboto-Regular.ttf').readAsBytes();
    await (FontLoader(
      'Roboto',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  test('every themed role has the same large height and shared baseline', () {
    expect(_roles.map(ThemedPieceMetrics.scaleFor), [1, 1, 1, 1, 1, 1]);
    final boxes = [
      for (final role in _roles)
        ThemedPieceMetrics.destination(
          const Size.square(48),
          const Size(150, 220),
          role,
        ),
    ];
    for (var index = 0; index < boxes.length; index++) {
      expect(
        boxes[index].bottom,
        closeTo(48 * ThemedPieceMetrics.baseline, .001),
      );
      expect(boxes[index].center.dx, 24);
      expect(boxes[index].left, greaterThanOrEqualTo(0));
      expect(boxes[index].top, greaterThanOrEqualTo(0));
      expect(
        boxes[index].height,
        closeTo(48 * ThemedPieceMetrics.maximumHeight, .001),
      );
    }
    expect(boxes.last.width, lessThanOrEqualTo(48 * .38 + .001));
  });

  test('all roles share height while every army keeps a lean pawn', () {
    const sources = [
      Rect.fromLTWH(0, 0, 120, 220),
      Rect.fromLTWH(0, 0, 100, 220),
      Rect.fromLTWH(0, 0, 95, 220),
      Rect.fromLTWH(0, 0, 230, 160),
      Rect.fromLTWH(0, 0, 240, 110),
      Rect.fromLTWH(0, 0, 160, 220),
    ];
    final pawn = ThemedPieceMetrics.destination(
      const Size.square(48),
      sources.last.size,
      Role.pawn,
      pawnWidthLimit: ThemedPieceMetrics.pawnWidthForArmy(sources),
      pawnHeightLimit: ThemedPieceMetrics.pawnHeightForArmy(sources),
    );
    for (var i = 0; i < 5; i++) {
      final major = ThemedPieceMetrics.destination(
        const Size.square(48),
        sources[i].size,
        _roles[i],
      );
      expect(pawn.width, lessThan(major.width));
      expect(pawn.height, closeTo(major.height, .001));
    }
  });

  testWidgets(
    'alpha bounds isolate each cell and discard almost transparent fringes',
    (tester) async {
      await tester.runAsync(() async {
        final atlas = await _fixture();
        final sources = await measureThemedSpriteBounds(atlas, 2);
        expect(sources, hasLength(12));
        for (var row = 0; row < 2; row++) {
          for (var col = 0; col < 6; col++) {
            expect(
              sources[row * 6 + col],
              Rect.fromLTWH(
                col * 100 + 10 + col.toDouble(),
                row * 100 + 5 + col.toDouble(),
                50 + col * 2.0,
                85 - col.toDouble(),
              ),
            );
          }
        }
        atlas.dispose();
      });
    },
  );

  testWidgets('48px painted silhouettes fill the square at one shared height', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final atlas = await _fixture();
      final sources = await measureThemedSpriteBounds(atlas, 2);
      final army = sources.take(6).toList();
      final visible = <Rect>[];
      for (var i = 0; i < 6; i++) {
        final image = await _render(
          ThemedPieceSpritePainter(
            image: atlas,
            source: sources[i],
            role: _roles[i],
            pawnWidthLimit: ThemedPieceMetrics.pawnWidthForArmy(army),
            pawnHeightLimit: ThemedPieceMetrics.pawnHeightForArmy(army),
          ),
          48,
        );
        visible.add(_pixelBounds((await image.toByteData())!, 48));
        image.dispose();
      }
      for (var i = 0; i < visible.length; i++) {
        expect(visible[i].bottom, visible.first.bottom);
        expect(visible[i].left, greaterThanOrEqualTo(0));
        expect(visible[i].right, lessThanOrEqualTo(48));
        expect(visible[i].height, closeTo(visible.first.height, 1));
      }
      for (final major in visible.take(5)) {
        expect(visible.last.width, lessThan(major.width));
      }
      atlas.dispose();
    });
  });

  testWidgets('sprite mirroring reverses only the horizontal artwork', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 20, 40),
        Paint()..color = Colors.red,
      );
      canvas.drawRect(
        const Rect.fromLTWH(20, 0, 20, 40),
        Paint()..color = Colors.blue,
      );
      final picture = recorder.endRecording();
      final atlas = await picture.toImage(40, 40);
      picture.dispose();
      final normal = await _render(
        ThemedPieceSpritePainter(
          image: atlas,
          source: const Rect.fromLTWH(0, 0, 40, 40),
          role: Role.king,
        ),
        48,
      );
      final flipped = await _render(
        ThemedPieceSpritePainter(
          image: atlas,
          source: const Rect.fromLTWH(0, 0, 40, 40),
          role: Role.king,
          flipX: true,
        ),
        48,
      );
      final a = (await normal.toByteData())!;
      final b = (await flipped.toByteData())!;
      expect(a.getUint32((20 * 48 + 12) * 4), b.getUint32((20 * 48 + 35) * 4));
      expect(a.getUint32((20 * 48 + 35) * 4), b.getUint32((20 * 48 + 12) * 4));
      expect(_pixelBounds(a, 48), _pixelBounds(b, 48));
      normal.dispose();
      flipped.dispose();
      atlas.dispose();
    });
  });

  testWidgets('both armies receive a visible midtone lift for face details', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final atlas = await _fixture();
      final source = (await measureThemedSpriteBounds(atlas, 2)).first;
      const original = Color.fromARGB(255, 40, 70, 120);
      for (final darkArmy in [false, true]) {
        final image = await _render(
          ThemedPieceSpritePainter(
            image: atlas,
            source: source,
            role: Role.king,
            brightenDarkArmy: darkArmy,
          ),
          48,
        );
        final bytes = (await image.toByteData())!;
        const offset = (24 * 48 + 24) * 4;
        final rendered = Color.fromARGB(
          bytes.getUint8(offset + 3),
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
        );
        expect(
          rendered.computeLuminance(),
          greaterThan(original.computeLuminance()),
        );
        image.dispose();
      }
      atlas.dispose();
    });
  });

  testWidgets(
    'all shipped themed atlases have isolated same-height sprites and lean pawns',
    (tester) async {
      await tester.runAsync(() async {
        final cache = <String, (ui.Image, List<Rect>)>{};
        try {
          for (final pack in _legacyOnly ? piecePacks.take(4) : piecePacks) {
            final sample = CharacterPiece(
              piece: const Piece(color: Side.white, role: Role.king),
              pack: pack,
            );
            if (!cache.containsKey(sample.atlasAsset)) {
              final bytes = await rootBundle.load(sample.atlasAsset);
              final codec = await ui.instantiateImageCodec(
                bytes.buffer.asUint8List(),
              );
              final image = (await codec.getNextFrame()).image;
              codec.dispose();
              expect(image.width, 1536);
              expect(image.height, sample.atlasRows * 256);
              final rgba = (await image.toByteData())!;
              for (var row = 0; row < sample.atlasRows; row++) {
                for (var column = 0; column < 6; column++) {
                  var transparent = 0;
                  for (var y = row * 256; y < (row + 1) * 256; y++) {
                    for (var x = column * 256; x < (column + 1) * 256; x++) {
                      if (rgba.getUint8((y * image.width + x) * 4 + 3) < 8) {
                        transparent++;
                      }
                    }
                  }
                  expect(
                    transparent,
                    greaterThan(256 * 256 * .1),
                    reason:
                        '${sample.atlasAsset} cell $row:$column transparent margin',
                  );
                }
              }
              cache[sample.atlasAsset] = (
                image,
                await measureThemedSpriteBounds(image, sample.atlasRows),
              );
            }
            final (image, sources) = cache[sample.atlasAsset]!;
            for (final side in Side.values) {
              final row = sample.usesKingdomAtlas
                  ? side.index
                  : pack.id.index * 2 + side.index;
              final army = sources.sublist(row * 6, row * 6 + 6);
              final rectangles = <Rect>[];
              for (var column = 0; column < 6; column++) {
                expect(army[column].left, greaterThanOrEqualTo(column * 256));
                expect(
                  army[column].right,
                  lessThanOrEqualTo((column + 1) * 256),
                );
                expect(army[column].top, greaterThanOrEqualTo(row * 256));
                expect(army[column].bottom, lessThanOrEqualTo((row + 1) * 256));
                final rendered = await _render(
                  ThemedPieceSpritePainter(
                    image: image,
                    source: army[column],
                    role: _roles[column],
                    flipX: side == Side.black,
                    brightenDarkArmy: side == Side.black,
                    pawnWidthLimit: ThemedPieceMetrics.pawnWidthForArmy(army),
                    pawnHeightLimit: ThemedPieceMetrics.pawnHeightForArmy(army),
                  ),
                  48,
                );
                final visible = _pixelBounds(
                  (await rendered.toByteData())!,
                  48,
                );
                expect(
                  visible.width,
                  greaterThan(3),
                  reason:
                      '${pack.id.name} ${side.name} ${_roles[column].name} visible width',
                );
                expect(
                  visible.height,
                  greaterThan(3),
                  reason:
                      '${pack.id.name} ${side.name} ${_roles[column].name} visible height',
                );
                rectangles.add(visible);
                rendered.dispose();
              }
              for (final piece in rectangles.skip(1)) {
                expect(
                  (piece.height - rectangles.first.height).abs(),
                  lessThanOrEqualTo(2),
                  reason: '${pack.id.name} ${side.name} equal visual height',
                );
              }
              for (final major in rectangles.take(5)) {
                expect(
                  (rectangles.last.height - major.height).abs(),
                  lessThanOrEqualTo(2),
                  reason: '${pack.id.name} ${side.name} pawn equal height',
                );
                expect(
                  rectangles.last.width,
                  lessThan(major.width),
                  reason: '${pack.id.name} ${side.name} pawn width',
                );
                expect(
                  (rectangles.last.bottom - major.bottom).abs(),
                  lessThanOrEqualTo(1),
                );
              }
            }
          }
          if (_visuals) await _contactSheet(cache);
        } finally {
          for (final entry in cache.values) {
            entry.$1.dispose();
          }
        }
      });
    },
  );
}

Future<ui.Image> _fixture() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  for (var row = 0; row < 2; row++) {
    for (var col = 0; col < 6; col++) {
      canvas.drawRect(
        Rect.fromLTWH(
          col * 100 + 10 + col.toDouble(),
          row * 100 + 5 + col.toDouble(),
          50 + col * 2.0,
          85 - col.toDouble(),
        ),
        Paint()..color = Color.fromARGB(255, 40 + col * 30, 70 + row * 60, 120),
      );
      canvas.drawRect(
        Rect.fromLTWH(col * 100.0, row * 100.0, 2, 2),
        Paint()..color = const Color(0x030000FF),
      );
    }
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(600, 200);
  picture.dispose();
  return image;
}

Future<ui.Image> _render(ThemedPieceSpritePainter painter, int size) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), Size.square(size.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  picture.dispose();
  return image;
}

Rect _pixelBounds(ByteData pixels, int size) {
  var minX = size, minY = size, maxX = -1, maxY = -1;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      if (pixels.getUint8((y * size + x) * 4 + 3) < 16) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  return Rect.fromLTRB(
    minX.toDouble(),
    minY.toDouble(),
    maxX + 1.0,
    maxY + 1.0,
  );
}

Future<void> _contactSheet(Map<String, (ui.Image, List<Rect>)> atlases) async {
  const left = 170.0, cell = 48.0, rowHeight = 74.0;
  final width = (left + 12 * cell + 12).round();
  final packs = (_legacyOnly ? piecePacks.take(4) : piecePacks).toList();
  final height = (packs.length * rowHeight + 24).round();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF192230),
  );
  for (var index = 0; index < packs.length; index++) {
    final pack = packs[index];
    final sample = CharacterPiece(
      piece: const Piece(color: Side.white, role: Role.king),
      pack: pack,
    );
    final (image, sources) = atlases[sample.atlasAsset]!;
    final y = index * rowHeight + 12;
    final label = TextPainter(
      text: TextSpan(
        text: pack.name,
        style: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 13,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: left - 20);
    label.paint(canvas, Offset(10, y + 12));
    label.dispose();
    for (final side in Side.values) {
      final row = sample.usesKingdomAtlas
          ? side.index
          : pack.id.index * 2 + side.index;
      final army = sources.sublist(row * 6, row * 6 + 6);
      for (var column = 0; column < 6; column++) {
        final x = left + (side.index * 6 + column) * cell;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cell, cell),
          Paint()..color = column.isEven ? pack.lightSquare : pack.darkSquare,
        );
        canvas.save();
        canvas.translate(x, y);
        ThemedPieceSpritePainter(
          image: image,
          source: army[column],
          role: _roles[column],
          flipX: side == Side.black,
          brightenDarkArmy: side == Side.black,
          pawnWidthLimit: ThemedPieceMetrics.pawnWidthForArmy(army),
          pawnHeightLimit: ThemedPieceMetrics.pawnHeightForArmy(army),
        ).paint(canvas, const Size.square(cell));
        canvas.restore();
      }
    }
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = io.File(
    'build/themed-piece-review/${_legacyOnly ? 'original-themes' : 'all-kingdoms'}-48px.png',
  );
  await file.parent.create(recursive: true);
  await file.writeAsBytes(png!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}
