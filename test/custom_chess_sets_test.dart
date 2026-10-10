// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';

import 'package:battle_chess_arena/src/domain/custom_chess_set.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/services/custom_chess_sets.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('all twelve piece designs and board options round trip', () {
    var original = CustomChessSet.create(id: 'my-set', name: 'Royal garden')
        .copyWith(
          lightSquare: 0xFFCCEECC,
          darkSquare: 0xFF224422,
          whiteAccent: 0xFFFFCC11,
          blackAccent: 0xFF6622AA,
          backgroundColor: 0xFF102030,
          surface: CustomBoardSurface.marble,
          background: CustomBackground.forest,
        );
    var index = 0;
    for (final side in Side.values) {
      for (final role in Role.values) {
        original = original.withDesign(
          side,
          role,
          CustomPieceDesign(
            horse: index % 4,
            costume: (index + 1) % 4,
            face: (index + 2) % 4,
            crown: (index + 3) % 4,
            weapon: (index + 2) % 4,
            structure: (index + 1) % 4,
            scale: .65 + index * .04,
          ),
        );
        index++;
      }
    }
    final restored = CustomChessSet.fromJson(
      jsonDecode(jsonEncode(original.toJson())),
    );
    expect(restored.toJson(), original.toJson());
    expect(restored.pieces.length, 12);
    for (final side in Side.values) {
      for (final role in Role.values) {
        expect(restored.designFor(side, role), original.designFor(side, role));
      }
    }
    expect(
      () => restored.pieces['white.pawn'] = const CustomPieceDesign(),
      throwsUnsupportedError,
    );
  });

  test('piece variants and sizes are bounded, including malformed input', () {
    const bounded = CustomPieceDesign(horse: -1, crown: 8, scale: 10);
    expect(bounded.horse, 0);
    expect(bounded.crown, 3);
    expect(bounded.scale, 1.15);
    expect(bounded.copyWith(scale: -10).scale, .65);
    expect(const CustomPieceDesign(scale: double.nan).scale, 1);
    final restored = CustomPieceDesign.fromJson({
      'horse': '3',
      'costume': 99,
      'face': -5,
      'crown': 2.1,
      'weapon': true,
      'structure': [],
      'scale': double.infinity,
    });
    expect(restored, const CustomPieceDesign(costume: 3));
    expect(CustomPieceDesign.fromJson(null), const CustomPieceDesign());
  });

  test(
    'new and missing designs have role-specific silhouettes for each side',
    () {
      final created = CustomChessSet.create(id: 'new-set');
      final restoredMissing = CustomChessSet.fromJson({'id': 'restored-set'});
      for (final side in Side.values) {
        final designs = {
          for (final role in Role.values) role: created.designFor(side, role),
        };
        expect(designs[Role.king]!.crown, 0);
        expect(designs[Role.queen]!.crown, 1);
        expect(designs[Role.knight]!.crown, 2);
        expect(designs[Role.bishop]!.crown, 3);
        expect(designs[Role.king]!.face, side == Side.white ? 0 : 1);
        expect(designs[Role.queen]!.face, side == Side.white ? 2 : 3);
        expect(designs[Role.bishop]!.face, 1);
        expect(designs[Role.knight]!.horse, side == Side.white ? 0 : 2);
        expect(designs[Role.rook]!.structure, side == Side.white ? 0 : 3);
        expect(designs[Role.king]!.weapon, 0);
        expect(designs[Role.queen]!.weapon, 1);
        expect(designs[Role.bishop]!.weapon, 1);
        expect(designs[Role.knight]!.weapon, 2);
        expect(designs[Role.pawn]!.weapon, 2);
        for (final role in Role.values) {
          expect(designs[role]!.costume, side == Side.white ? 0 : 1);
          expect(
            designs[role]!.formationPack,
            side == Side.white ? PiecePackId.anime : PiecePackId.indianEpic,
          );
          expect(restoredMissing.designFor(side, role).formationPack, isNull);
          expect(
            restoredMissing.designFor(side, role).costume,
            side == Side.white ? 0 : 1,
          );
        }
      }
    },
  );

  test(
    'role-aware defaults never replace explicitly saved piece selections',
    () {
      final json = CustomChessSet.create(id: 'existing-set').toJson();
      json['pieces'] = {
        for (final side in Side.values)
          for (final role in Role.values)
            CustomChessSet.pieceKey(side, role): const CustomPieceDesign()
                .toJson(),
      };
      final restored = CustomChessSet.fromJson(json);
      for (final side in Side.values) {
        for (final role in Role.values) {
          expect(restored.designFor(side, role), const CustomPieceDesign());
        }
      }
    },
  );

  test(
    'malformed appearance fields recover defaults without losing valid designs',
    () {
      final defaults = CustomChessSet.create(id: 'safe');
      final set = CustomChessSet.fromJson({
        'id': ' safe ',
        'name': '  \n ',
        'surface': 'unknown',
        'background': 7,
        'lightSquare': -1,
        'darkSquare': 0x100000000,
        'whiteAccent': 'pink',
        'blackAccent': null,
        'backgroundColor': [],
        'pieces': {
          'white.knight': {'horse': 3, 'scale': .9},
          'black.king': 'invalid',
          'white.dragon': {'crown': 2},
        },
      });
      expect(set.id, 'safe');
      expect(set.name, CustomChessSet.defaultName);
      expect(set.lightSquare, defaults.lightSquare);
      expect(set.darkSquare, defaults.darkSquare);
      expect(set.whiteAccent, defaults.whiteAccent);
      expect(set.blackAccent, defaults.blackAccent);
      expect(set.backgroundColor, defaults.backgroundColor);
      expect(set.surface, defaults.surface);
      expect(set.background, defaults.background);
      expect(set.designFor(Side.white, Role.knight).horse, 3);
      expect(
        set.designFor(Side.black, Role.king),
        CustomChessSet.fromJson({
          'id': 'legacy-safe',
        }).designFor(Side.black, Role.king),
      );
      expect(set.pieces.length, 12);
      expect(CustomChessSet.fromJson([]).id, '');
      expect(
        CustomChessSet.create(id: 'bounded', name: '👑' * 60).name.runes.length,
        40,
      );
      expect(
        defaults.designFor(Side.white, Role.king),
        isNot(defaults.designFor(Side.black, Role.king)),
      );
      expect(defaults.whiteAccent, isNot(defaults.blackAccent));
    },
  );

  test('save, restore, edit, and deactivate retain local designs', () async {
    final library = CustomChessSets();
    addTearDown(library.dispose);
    await library.ready;
    expect(library.loaded, isTrue);
    expect(library.sets, isEmpty);
    final original = CustomChessSet.create(id: 'first').withDesign(
      Side.black,
      Role.king,
      const CustomPieceDesign(crown: 3, weapon: 1, scale: 1.1),
    );
    expect(await library.save(original), isTrue);
    expect(library.activeId, 'first');
    expect(
      await library.save(CustomChessSet.create(id: 'second'), activate: false),
      isTrue,
    );
    expect(library.activeId, 'first');
    expect(await library.save(original.copyWith(name: 'Edited')), isTrue);
    expect(library.sets.length, 2);
    final restored = CustomChessSets();
    addTearDown(restored.dispose);
    await restored.ready;
    expect(restored.active?.name, 'Edited');
    expect(restored.active?.designFor(Side.black, Role.king).crown, 3);
    expect(restored.sets.map((set) => set.id), ['first', 'second']);
    expect(() => restored.sets.add(original), throwsUnsupportedError);
    expect(await restored.activate(null), isTrue);
    expect(restored.active, isNull);
    expect(restored.sets.length, 2);
  });

  test(
    'rapid saves serialize and preserve all sets before activation and deletion',
    () async {
      final library = CustomChessSets();
      addTearDown(library.dispose);
      final results = await Future.wait([
        library.save(CustomChessSet.create(id: 'first')),
        library.save(CustomChessSet.create(id: 'second')),
        library.activate('first'),
        library.delete('second'),
      ]);
      expect(results, everyElement(isTrue));
      expect(library.sets.map((set) => set.id), ['first']);
      expect(library.activeId, 'first');
      final restored = CustomChessSets();
      addTearDown(restored.dispose);
      await restored.ready;
      expect(restored.sets.map((set) => set.id), ['first']);
      expect(restored.activeId, 'first');
      expect(await restored.delete('first'), isTrue);
      expect(restored.activeId, isNull);
      expect(restored.active, isNull);
      expect(restored.sets, isEmpty);
    },
  );

  test(
    'saving during initial restore does not overwrite an existing collection',
    () async {
      final seeded = CustomChessSets(autoLoad: false);
      addTearDown(seeded.dispose);
      await seeded.save(CustomChessSet.create(id: 'existing'));
      final gate = Completer<SharedPreferences>();
      var reads = 0;
      final library = CustomChessSets(
        preferences: () =>
            reads++ == 0 ? gate.future : SharedPreferences.getInstance(),
      );
      addTearDown(library.dispose);
      final saving = library.save(CustomChessSet.create(id: 'new'));
      expect(library.loaded, isFalse);
      gate.complete(await SharedPreferences.getInstance());
      expect(await saving, isTrue);
      expect(library.sets.map((set) => set.id), ['existing', 'new']);
      expect(library.activeId, 'new');
    },
  );

  test(
    'failed writes preserve in-memory state and subsequent writes can recover',
    () async {
      var failStorage = false;
      final library = CustomChessSets(
        preferences: () async {
          if (failStorage) throw StateError('Storage unavailable');
          return SharedPreferences.getInstance();
        },
      );
      addTearDown(library.dispose);
      await library.save(CustomChessSet.create(id: 'existing'));
      failStorage = true;
      expect(await library.save(CustomChessSet.create(id: 'unsaved')), isFalse);
      expect(library.error, contains('could not be saved'));
      expect(library.sets.map((set) => set.id), ['existing']);
      expect(library.activeId, 'existing');
      expect(await library.delete('existing'), isFalse);
      expect(await library.activate(null), isFalse);
      expect(library.activeId, 'existing');
      failStorage = false;
      expect(
        await library.save(CustomChessSet.create(id: 'recovered')),
        isTrue,
      );
      expect(library.error, isNull);
      final restored = CustomChessSets();
      addTearDown(restored.dispose);
      await restored.ready;
      expect(restored.sets.map((set) => set.id), ['existing', 'recovered']);
    },
  );

  test(
    'invalid IDs and unknown selections do not mutate the library',
    () async {
      final library = CustomChessSets();
      addTearDown(library.dispose);
      expect(
        await library.save(CustomChessSet.create(id: '../invalid')),
        isFalse,
      );
      expect(library.error, contains('invalid ID'));
      expect(await library.activate('unknown'), isFalse);
      expect(await library.delete('unknown'), isFalse);
      expect(library.sets, isEmpty);
      expect(await library.save(CustomChessSet.create(id: 'valid-1')), isTrue);
      expect(library.error, isNull);
    },
  );

  test(
    'collection limit rejects new sets but permits editing and replacing IDs',
    () async {
      final library = CustomChessSets();
      addTearDown(library.dispose);
      for (var index = 0; index < CustomChessSets.maxSets; index++) {
        expect(
          await library.save(CustomChessSet.create(id: 'set-$index')),
          isTrue,
        );
      }
      expect(
        await library.save(CustomChessSet.create(id: 'one-too-many')),
        isFalse,
      );
      expect(library.error, contains('up to 20'));
      expect(library.sets.length, 20);
      expect(
        await library.save(library.sets.first.copyWith(name: 'Updated')),
        isTrue,
      );
      expect(library.sets.first.name, 'Updated');
      expect(library.sets.length, 20);
    },
  );

  for (final invalidData in [
    '{not valid json',
    jsonEncode({'version': 5, 'sets': []}),
    jsonEncode({'version': 1, 'sets': {}}),
    jsonEncode({
      'version': 1,
      'sets': [null],
    }),
    jsonEncode({
      'version': 1,
      'sets': [
        CustomChessSet.create(id: 'duplicate').toJson(),
        CustomChessSet.create(id: 'duplicate').toJson(),
      ],
    }),
  ]) {
    test(
      'unreadable collections are reported and never silently overwritten: $invalidData',
      () async {
        SharedPreferences.setMockInitialValues({
          CustomChessSets.storageKey: invalidData,
        });
        final library = CustomChessSets();
        addTearDown(library.dispose);
        await library.ready;
        expect(library.loaded, isTrue);
        expect(library.error, contains('could not be loaded'));
        expect(
          await library.save(CustomChessSet.create(id: 'replacement')),
          isFalse,
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(CustomChessSets.storageKey), invalidData);
      },
    );
  }

  test(
    'orphan active IDs fall back to no selection without losing sets',
    () async {
      SharedPreferences.setMockInitialValues({
        CustomChessSets.storageKey: jsonEncode({
          'version': 1,
          'sets': [CustomChessSet.create(id: 'existing').toJson()],
          'activeId': 'missing',
        }),
      });
      final library = CustomChessSets();
      addTearDown(library.dispose);
      await library.ready;
      expect(library.active, isNull);
      expect(library.sets.length, 1);
      expect(library.error, isNull);
    },
  );

  testWidgets(
    'scope observes saved selections and supports an absent controller',
    (tester) async {
      final library = CustomChessSets();
      addTearDown(library.dispose);
      await library.ready;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CustomChessSetScope(
            controller: library,
            child: Builder(
              builder: (context) => Text(
                CustomChessSetScope.of(context).active?.name ?? 'Default',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Default'), findsOneWidget);
      await library.save(
        CustomChessSet.create(id: 'scope-set', name: 'Royal guard'),
      );
      await tester.pump();
      expect(find.text('Royal guard'), findsOneWidget);
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            expect(CustomChessSetScope.maybeOf(context), isNull);
            expect(() => CustomChessSetScope.of(context), throwsStateError);
            return const SizedBox();
          },
        ),
      );
    },
  );
}
