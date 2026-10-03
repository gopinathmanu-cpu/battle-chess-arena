import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:battle_chess_arena/src/domain/custom_avatar.dart';
import 'package:battle_chess_arena/src/features/online/custom_avatar_portrait.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _visuals = bool.fromEnvironment('AVATAR_STUDIO_VISUALS');
const _base = CustomAvatarDesign();

void main() {
  setUpAll(() async {
    const directory = String.fromEnvironment('AVATAR_STUDIO_FONT_DIR');
    if (!_visuals || directory.isEmpty) return;
    final bytes = await io.File('$directory/Roboto-Regular.ttf').readAsBytes();
    await (FontLoader(
      'Roboto',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  test('portrait palette options match the stored design categories', () {
    expect(
      CustomAvatarPortrait.skinTones,
      hasLength(CustomAvatarDesign.skinToneLabels.length),
    );
    expect(
      CustomAvatarPortrait.hairColors,
      hasLength(CustomAvatarDesign.hairColorLabels.length),
    );
    expect(
      CustomAvatarPortrait.outfitColors,
      hasLength(CustomAvatarDesign.outfitColorLabels.length),
    );
    expect(
      CustomAvatarPortrait.backgroundColors,
      hasLength(CustomAvatarDesign.backgroundLabels.length),
    );
    for (final palette in [
      CustomAvatarPortrait.skinTones,
      CustomAvatarPortrait.hairColors,
      CustomAvatarPortrait.outfitColors,
      CustomAvatarPortrait.backgroundColors,
    ]) {
      expect(palette.toSet(), hasLength(palette.length));
      expect(palette.every((color) => color.a == 1), isTrue);
    }
  });

  final groups = <String, List<CustomAvatarDesign>>{
    'presentation': [
      for (var i = 0; i < 2; i++) _base.copyWith(presentation: i),
    ],
    'age': [for (var i = 0; i < 4; i++) _base.copyWith(age: i)],
    'face': [for (var i = 0; i < 4; i++) _base.copyWith(face: i)],
    'skin tone': [for (var i = 0; i < 8; i++) _base.copyWith(skinTone: i)],
    'hair style': [for (var i = 0; i < 12; i++) _base.copyWith(hairStyle: i)],
    'hair colour': [for (var i = 0; i < 10; i++) _base.copyWith(hairColor: i)],
    'moustache': [for (var i = 0; i < 5; i++) _base.copyWith(moustache: i)],
    'beard': [for (var i = 0; i < 6; i++) _base.copyWith(beard: i)],
    'eyewear': [for (var i = 0; i < 6; i++) _base.copyWith(eyewear: i)],
    'outfit': [for (var i = 0; i < 6; i++) _base.copyWith(outfit: i)],
    'outfit colour': [
      for (var i = 0; i < 8; i++) _base.copyWith(outfitColor: i),
    ],
    'background': [for (var i = 0; i < 8; i++) _base.copyWith(background: i)],
  };
  for (final entry in groups.entries) {
    testWidgets(
      'every ${entry.key} option produces a distinct visible portrait',
      (tester) async {
        await tester.runAsync(() async {
          final painted = <ByteData>[];
          for (final design in entry.value) {
            final image = await _portrait(design, 120);
            painted.add((await image.toByteData())!);
            image.dispose();
          }
          for (var i = 0; i < painted.length; i++) {
            for (var j = i + 1; j < painted.length; j++) {
              var changed = 0;
              for (var pixel = 0; pixel < 120 * 120; pixel++) {
                if (painted[i].getUint32(pixel * 4) !=
                    painted[j].getUint32(pixel * 4)) {
                  changed++;
                }
              }
              expect(
                changed,
                greaterThan(10),
                reason: '${entry.key} $i versus $j',
              );
            }
          }
        });
      },
    );
  }

  testWidgets('portraits remain circular and clipped at small and hero sizes', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final size in [32, 200]) {
        for (var hair = 0; hair < 12; hair++) {
          final image = await _portrait(
            _base.copyWith(hairStyle: hair, beard: 5, eyewear: 5),
            size,
          );
          final pixels = (await image.toByteData())!;
          for (var y = 0; y < size; y++) {
            for (var x = 0; x < size; x++) {
              final dx = x + .5 - size / 2;
              final dy = y + .5 - size / 2;
              if (dx * dx + dy * dy > (size / 2 + 1) * (size / 2 + 1)) {
                expect(
                  pixels.getUint8((y * size + x) * 4 + 3),
                  0,
                  reason: 'hair $hair at $size px',
                );
              }
            }
          }
          expect(
            pixels.getUint8(((size ~/ 2) * size + size ~/ 2) * 4 + 3),
            255,
          );
          image.dispose();
        }
      }
    });
  });

  testWidgets('portrait widget supports tiny and large layouts and updates', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              CustomAvatarPortrait(design: _base, size: 32),
              CustomAvatarPortrait(design: _base, size: 200),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(CustomAvatarPortrait).first),
      const Size.square(32),
    );
    expect(
      tester.getSize(find.byType(CustomAvatarPortrait).last),
      const Size.square(200),
    );
    expect(find.bySemanticsLabel('Custom avatar portrait'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    const painter = CustomAvatarPainter(_base);
    expect(painter.shouldRepaint(const CustomAvatarPainter(_base)), isFalse);
    expect(
      painter.shouldRepaint(CustomAvatarPainter(_base.copyWith(eyewear: 3))),
      isTrue,
    );
  });

  testWidgets('render avatar appearance contact sheets for visual review', (
    tester,
  ) async {
    if (!_visuals) return;
    await tester.runAsync(() async {
      await _sheet('hairstyles', [
        for (var i = 0; i < 12; i++)
          (
            CustomAvatarDesign.hairStyleLabels[i],
            _base.copyWith(
              hairStyle: i,
              presentation: i >= 6 ? 1 : 0,
              hairColor: i % 6,
              background: i % 8,
              outfitColor: i % 8,
            ),
          ),
      ], columns: 6);
      await _sheet('ages-and-faces', [
        for (var presentation = 0; presentation < 2; presentation++)
          for (var age = 0; age < 4; age++)
            (
              CustomAvatarDesign.ageLabels[age],
              _base.copyWith(
                presentation: presentation,
                age: age,
                background: 5,
                hairStyle: presentation == 0 ? 2 : 7,
                hairColor: 1,
              ),
            ),
        for (var i = 0; i < 4; i++)
          (
            CustomAvatarDesign.faceLabels[i],
            _base.copyWith(face: i, hairStyle: 0, background: 1),
          ),
      ], columns: 4);
      await _sheet('skin-tones', [
        for (var i = 0; i < 8; i++)
          (
            CustomAvatarDesign.skinToneLabels[i],
            _base.copyWith(
              skinTone: i,
              hairStyle: i.isEven ? 4 : 9,
              presentation: i.isEven ? 0 : 1,
              background: 7,
            ),
          ),
      ], columns: 4);
      await _sheet('accessories', [
        for (var i = 0; i < 6; i++)
          (
            CustomAvatarDesign.beardLabels[i],
            _base.copyWith(beard: i, hairStyle: 1, background: 1),
          ),
        for (var i = 0; i < 6; i++)
          (
            CustomAvatarDesign.eyewearLabels[i],
            _base.copyWith(eyewear: i, hairStyle: 3, background: 3),
          ),
        for (var i = 0; i < 5; i++)
          (
            CustomAvatarDesign.moustacheLabels[i],
            _base.copyWith(moustache: i, background: 4),
          ),
      ], columns: 6);
      await _sheet('outfits', [
        for (var i = 0; i < 6; i++)
          (
            CustomAvatarDesign.outfitLabels[i],
            _base.copyWith(
              outfit: i,
              outfitColor: i,
              hairStyle: i.isEven ? 2 : 10,
              presentation: i.isEven ? 0 : 1,
              background: 7,
            ),
          ),
      ], columns: 6);
      await _sheet('colour-combinations', [
        for (var i = 0; i < 10; i++)
          (
            CustomAvatarDesign.hairColorLabels[i],
            _base.copyWith(
              hairStyle: 8,
              hairColor: i,
              presentation: 1,
              skinTone: i % 8,
              outfitColor: (i + 1) % 8,
              background: (i + 2) % 8,
            ),
          ),
      ], columns: 5);
    });
  });
}

Future<ui.Image> _portrait(CustomAvatarDesign design, int size) async {
  final recorder = ui.PictureRecorder();
  CustomAvatarPainter(
    design,
  ).paint(Canvas(recorder), Size.square(size.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  picture.dispose();
  return image;
}

Future<void> _sheet(
  String name,
  List<(String, CustomAvatarDesign)> portraits, {
  required int columns,
}) async {
  const tileWidth = 160.0;
  const tileHeight = 190.0;
  const portraitSize = 142.0;
  final width = (columns * tileWidth).round();
  final height = ((portraits.length / columns).ceil() * tileHeight).round();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFFF4F1EB),
  );
  for (var i = 0; i < portraits.length; i++) {
    final x = (i % columns) * tileWidth + 9;
    final y = (i ~/ columns) * tileHeight + 10;
    canvas.save();
    canvas.translate(x, y);
    CustomAvatarPainter(
      portraits[i].$2,
    ).paint(canvas, const Size.square(portraitSize));
    canvas.restore();
    final label = TextPainter(
      text: TextSpan(
        text: portraits[i].$1,
        style: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF35424D),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(minWidth: tileWidth, maxWidth: tileWidth);
    label.paint(canvas, Offset(x - 9, y + portraitSize + 9));
    label.dispose();
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = io.File('build/custom-avatar-review/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(data!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}
