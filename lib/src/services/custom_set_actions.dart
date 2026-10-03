// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'custom_chess_sets.dart';

/// A built-in set selection should explicitly leave the custom appearance.
Future<bool> restoreBuiltInChessSet(BuildContext context) async {
  final library = CustomChessSetScope.maybeOf(context);
  if (library == null) return true;
  await library.ready;
  if (!context.mounted) return false;
  if (library.activeId == null) return true;
  final ok = await library.activate(null);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          library.error ?? 'Could not save the chess set choice. Try again.',
        ),
      ),
    );
  }
  return ok;
}
