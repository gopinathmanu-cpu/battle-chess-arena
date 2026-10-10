// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

Future<bool> confirmAutoPlay(BuildContext context) async =>
    await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cancel auto-play',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (context, _, _) => SafeArea(
        child: AlertDialog(
          key: const ValueKey('auto-play-confirmation'),
          scrollable: true,
          title: const Text('Enable auto-play?'),
          content: const Text(
            'Auto-play makes moves for both sides using the strongest assistance. '
            'Auto-play is free. You can stop it at any time.',
          ),
          actions: [
            TextButton(
              key: const ValueKey('cancel-auto-play'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('confirm-auto-play'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enable auto-play'),
            ),
          ],
        ),
      ),
    ) ??
    false;
