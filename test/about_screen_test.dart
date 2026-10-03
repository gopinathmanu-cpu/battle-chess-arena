import 'package:battle_chess_arena/src/features/settings/about_screen.dart';
import 'package:battle_chess_arena/src/services/beta_app_info.dart';
import 'package:battle_chess_arena/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const info = BetaAppInfo(
  version: '0.9.0',
  build: '24',
  platform: 'Android',
  device: 'Test phone',
  architecture: 'arm64-v8a',
);

void main() {
  testWidgets('about is release-friendly and contains no diagnostics', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: const AboutScreen(appInfo: info),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('About'), findsOneWidget);
    expect(find.text('Version 0.9.0 (24)'), findsOneWidget);
    expect(find.textContaining('Firebase'), findsNothing);
    expect(find.textContaining('diagnostic'), findsNothing);
    expect(find.textContaining('server'), findsNothing);
    expect(find.textContaining('engine'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Open source & licences'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Open source & licences'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
