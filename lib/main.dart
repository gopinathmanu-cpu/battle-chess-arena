import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/services/one_time_cleanup.dart';
import 'src/services/app_diagnostics.dart';
import 'src/services/app_licenses.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final diagnostics = AppDiagnostics.instance;
  diagnostics.installErrorHandlers();
  await diagnostics.initialize();
  try {
    await OneTimeCleanup.run();
  } catch (error, stack) {
    diagnostics.record(DiagnosticSource.startup, error, stack);
  }
  registerAppLicenses();
  runApp(const BattleChessArenaApp());
}
