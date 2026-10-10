// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Enables after acknowledging the fee, or stops an already active auto-play.
/// Zero-duration pumps preserve the timing boundaries asserted by callers.
Future<void> toggleAutoPlay(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('auto-play-toggle')));
  await tester.pump();
  final confirmation = find.byKey(const ValueKey('confirm-auto-play'));
  if (confirmation.evaluate().isNotEmpty) {
    await tester.tap(confirmation);
    await tester.pump();
  }
}
