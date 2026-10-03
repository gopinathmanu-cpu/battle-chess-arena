import 'package:battle_chess_arena/src/domain/capture_threat.dart';
import 'package:battle_chess_arena/src/features/play/threat_scan.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final sampleThreats = immediateCaptureThreats(
  Chess.fromSetup(Setup.parseFen('r6k/8/2b5/3P4/Q7/8/8/6K1 w - - 0 1')),
  defender: Side.white,
);

void main() {
  testWidgets(
    'every pair blinks and lasts exactly three seconds, then clears',
    (tester) async {
      await tester.pumpWidget(const SizedBox());
      final scan = ThreatScanController();
      addTearDown(scan.dispose);
      scan.start(sampleThreats, reducedMotion: false);
      expect(scan.current, sampleThreats[0]);
      expect(scan.lit, isTrue);
      await tester.pump(const Duration(milliseconds: 500));
      expect(scan.lit, isFalse);
      await tester.pump(const Duration(milliseconds: 500));
      expect(scan.lit, isTrue);
      await tester.pump(const Duration(milliseconds: 1999));
      expect(scan.current, sampleThreats[0]);
      await tester.pump(const Duration(milliseconds: 1));
      expect(scan.current, sampleThreats[1]);
      expect(scan.lit, isTrue);
      await tester.pump(const Duration(seconds: 3));
      expect(scan.current, sampleThreats[2]);
      await tester.pump(const Duration(seconds: 3));
      expect(scan.active, isFalse);
      expect(scan.current, isNull);
      expect(scan.message, 'Scan complete · 3 threats shown.');
    },
  );

  testWidgets(
    'reduced motion stays red, supports changes, restart and stop cancel timers',
    (tester) async {
      await tester.pumpWidget(const SizedBox());
      final scan = ThreatScanController();
      scan.start(sampleThreats, reducedMotion: true);
      await tester.pump(const Duration(milliseconds: 500));
      expect(scan.lit, isTrue);
      scan.setReducedMotion(false);
      await tester.pump(const Duration(milliseconds: 500));
      expect(scan.lit, isFalse);
      scan.setReducedMotion(true);
      expect(scan.lit, isTrue);
      scan.start([sampleThreats.last], reducedMotion: true);
      await tester.pump(const Duration(seconds: 2));
      expect(scan.current, sampleThreats.last);
      await tester.pump(const Duration(seconds: 1));
      expect(scan.active, isFalse);
      scan.start(sampleThreats, reducedMotion: false);
      scan.stop();
      await tester.pump(const Duration(seconds: 10));
      expect(scan.current, isNull);
      expect(scan.message, isNull);
      scan.start(sampleThreats, reducedMotion: false);
      scan.dispose();
      await tester.pump(const Duration(seconds: 10));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty scan reports no threats without an active timer', (
    tester,
  ) async {
    final scan = ThreatScanController();
    scan.start([], reducedMotion: false);
    expect(scan.active, isFalse);
    expect(scan.message, contains('No immediate checks or capture threats'));
    scan.dispose();
  });
}
