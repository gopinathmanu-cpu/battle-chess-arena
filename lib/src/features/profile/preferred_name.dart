// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../domain/avatar_name_policy.dart';
import '../../services/player_identity_controller.dart';

Future<bool> showPreferredNameSheet(BuildContext context) async {
  final controller = PlayerIdentityScope.maybeOf(context);
  if (controller == null) return false;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (_) => _PreferredNameSheet(controller: controller),
  );
  return saved ?? false;
}

class _PreferredNameSheet extends StatefulWidget {
  const _PreferredNameSheet({required this.controller});
  final PlayerIdentityController controller;

  @override
  State<_PreferredNameSheet> createState() => _PreferredNameSheetState();
}

class _PreferredNameSheetState extends State<_PreferredNameSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.controller.nickname,
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final validation = preferredNameValidationError(_text.text);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() => _saving = true);
    await widget.controller.saveNickname(_text.text);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _continueWithoutName() async {
    setState(() => _saving = true);
    await widget.controller.continueWithoutNickname();
    if (mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24,
      8,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'What should we call you?',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Optional. We’ll use it in congratulations and game messages only on this device.',
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('preferred-name-field'),
          controller: _text,
          autofocus: true,
          maxLength: 24,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Nickname or first name',
            errorText: _error,
          ),
          onSubmitted: _saving ? null : (_) => _save(),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            TextButton(
              key: const ValueKey('continue-without-name'),
              onPressed: _saving ? null : _continueWithoutName,
              child: const Text('Continue without a name'),
            ),
            FilledButton(
              key: const ValueKey('save-preferred-name'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ],
    ),
  );
}

class PreferredNameSettingsTile extends StatelessWidget {
  const PreferredNameSettingsTile({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final controller = PlayerIdentityScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    if (compact) {
      return Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          key: const ValueKey('preferred-name-settings'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => showPreferredNameSheet(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.waving_hand_outlined, size: 20),
                    Spacer(),
                    Icon(Icons.edit_rounded, size: 17),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nickname',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  controller.nickname ?? 'Guest',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Private; online players will not see it.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ListTile(
      key: const ValueKey('preferred-name-settings'),
      leading: const Icon(Icons.waving_hand_outlined),
      title: const Text('Private in-app nickname'),
      subtitle: Text(
        controller.nickname == null
            ? 'Optional. Used only in app messages; online players will not see it.'
            : 'Using ${controller.nickname} in app messages. Online players will not see it.',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showPreferredNameSheet(context),
    );
  }
}
