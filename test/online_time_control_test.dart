import 'package:battle_chess_arena/src/domain/online_time_control.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unsupported invitation clocks select the closest available option', () {
    expect(closestOnlineTimeControl(6000000).baseMs, 3600000);
    expect(closestOnlineTimeControl(600000).baseMs, 900000);
    expect(closestOnlineTimeControl(1800000).baseMs, 1800000);
  });
}
