import 'package:battle_chess_arena/src/domain/avatar_name_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Avatar IDs reject abusive terms and common obfuscation', () {
    for (final name in ['BadFuckName', 'sh1t king', 'f-u-c-k', 'NaziPlayer']) {
      expect(avatarNameValidationError(name), contains('respectful'));
    }
  });

  test(
    'Avatar IDs accept printable keyboard characters with length limits',
    () {
      expect(avatarNameValidationError('ClassicKnight'), isNull);
      expect(avatarNameValidationError('Player_42'), isNull);
      expect(avatarNameValidationError('ab'), contains('3–20'));
      for (var code = 33; code <= 126; code++) {
        expect(
          avatarNameValidationError('${String.fromCharCode(code)}Knight'),
          isNull,
        );
      }
      expect(avatarNameValidationError('@Nova#42'), isNull);
      expect(avatarNameValidationError('Knight\u0000'), isNotNull);
      expect(avatarNameValidationError('Knight\u007f'), isNotNull);
      expect(avatarNameValidationError('A' * 21), isNotNull);
    },
  );
}
