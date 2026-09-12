import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/services/one_time_cleanup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OneTimeCleanup.run();
  runApp(const BattleChessArenaApp());
}
