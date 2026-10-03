import 'package:battle_chess_arena/src/domain/avatar_name_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Avatar IDs reject abusive terms and common obfuscation', () {
    for (final name in ['BadFuckName', 'sh1t king', 'f-u-c-k', 'NaziPlayer']) {
      expect(avatarNameValidationError(name), contains('respectful'));
    }
  });

  test(
    'Avatar IDs retain the existing format rules without false positives',
    () {
      expect(avatarNameValidationError('ClassicKnight'), isNull);
      expect(avatarNameValidationError('Player_42'), isNull);
      expect(avatarNameValidationError('ab'), contains('3–20'));
    },
  );
}
