import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/services/home_chess_set.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('selection retains both families after saving', () async {
    SharedPreferences.setMockInitialValues({});
    await const HomeChessSet(
      pack: PiecePackId.greek,
      classic: true,
      style: ClassicPieceStyle.metal,
    ).save();
    final loaded = await HomeChessSet.load();
    expect(loaded.pack, PiecePackId.greek);
    expect(loaded.classic, isTrue);
    expect(loaded.style, ClassicPieceStyle.metal);
  });

  test('missing, malformed and unknown selections fall back safely', () async {
    for (final value in [
      null,
      12,
      ['broken'],
      ['unknown', 'unknown', 'unknown'],
    ]) {
      SharedPreferences.setMockInitialValues({
        if (value != null) HomeChessSet.preferenceKey: value,
      });
      final loaded = await HomeChessSet.load();
      expect(loaded.pack, PiecePackId.anime);
      expect(loaded.classic, isTrue);
      expect(loaded.style, ClassicPieceStyle.magneticTeaching);
    }
  });

  test('an existing themed selection remains themed', () async {
    SharedPreferences.setMockInitialValues({
      HomeChessSet.preferenceKey: [
        PiecePackId.greek.name,
        'themed',
        ClassicPieceStyle.wood.name,
      ],
    });

    final loaded = await HomeChessSet.load();
    expect(loaded.pack, PiecePackId.greek);
    expect(loaded.classic, isFalse);
    expect(loaded.style, ClassicPieceStyle.wood);
  });
}
