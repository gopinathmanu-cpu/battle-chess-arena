// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../domain/avatar_name_policy.dart';
import '../../domain/online_player_profile.dart';
import '../../services/online_game_history.dart';
import '../../services/online_profile_save.dart';
import '../online/online_avatar_image.dart';

Future<OnlinePlayerProfile?> showOnlineProfileSettings(
  BuildContext context, {
  OnlinePlayerProfile? initialProfile,
}) async {
  final saved = initialProfile ?? await OnlineGameHistory.loadProfile();
  if (!context.mounted) return null;
  return showDialog<OnlinePlayerProfile>(
    context: context,
    builder: (_) => _OnlineProfileEditorDialog(saved: saved),
  );
}

class _OnlineProfileEditorDialog extends StatefulWidget {
  const _OnlineProfileEditorDialog({required this.saved});

  final OnlinePlayerProfile? saved;

  @override
  State<_OnlineProfileEditorDialog> createState() =>
      _OnlineProfileEditorDialogState();
}

class _OnlineProfileEditorDialogState
    extends State<_OnlineProfileEditorDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.saved?.name ?? '',
  );
  late String _avatarId =
      widget.saved?.avatarId ?? onlineAvatarChoices.first.id;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final normalized = normalizedAvatarName(_name.text);
    final validation = avatarNameValidationError(normalized);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final profile = OnlinePlayerProfile(
      name: normalized,
      avatarId: _avatarId,
      level: widget.saved?.level ?? OnlinePlayerLevel.intermediate,
      playerToken: widget.saved?.playerToken,
    );
    try {
      final accepted = await saveOnlineProfileConfirmed(
        profile,
        previous: widget.saved,
      );
      if (mounted) Navigator.pop(context, accepted);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is StateError
              ? error.message.toString()
              : 'Could not verify and save your online avatar. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.saved == null ? 'Create online avatar' : 'Edit online avatar',
    ),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Your Online Avatar Name and image are public. Other players will see them when you play online.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'This is separate from your private in-app nickname, which is used only when Battle Chess Arena addresses you in messages.',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('settings-online-avatar-name'),
              controller: _name,
              maxLength: 20,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Online Avatar Name',
                errorText: _error,
                prefixIcon: const Icon(Icons.public),
              ),
            ),
            const Text('Choose the image other online players will see'),
            const SizedBox(height: 8),
            OnlineAvatarPicker(
              selectedId: _avatarId,
              height: 280,
              onSelected: (value) => setState(() => _avatarId = value),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('save-online-profile-settings'),
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Save'),
      ),
    ],
  );
}

class OnlineProfileSettingsTile extends StatefulWidget {
  const OnlineProfileSettingsTile({
    required this.onChanged,
    this.compact = false,
    super.key,
  });

  final ValueChanged<OnlinePlayerProfile> onChanged;
  final bool compact;

  @override
  State<OnlineProfileSettingsTile> createState() =>
      _OnlineProfileSettingsTileState();
}

class _OnlineProfileSettingsTileState extends State<OnlineProfileSettingsTile> {
  OnlinePlayerProfile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await OnlineGameHistory.loadProfile();
    if (mounted) setState(() => _profile = profile);
  }

  Future<void> _edit() async {
    final profile = await showOnlineProfileSettings(
      context,
      initialProfile: _profile,
    );
    if (!mounted || profile == null) return;
    setState(() => _profile = profile);
    widget.onChanged(profile);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          key: const ValueKey('online-profile-settings'),
          borderRadius: BorderRadius.circular(16),
          onTap: _edit,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_profile == null)
                      const Icon(Icons.public, size: 20)
                    else
                      OnlineAvatarImage(avatarId: _profile!.avatarId, size: 28),
                    const Spacer(),
                    const Icon(Icons.edit_rounded, size: 17),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Online avatar',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  _profile?.name ?? 'Not configured',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  _profile == null
                      ? 'Set the public name and image other online players will see'
                      : 'Public name and image seen by online players.',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ListTile(
      key: const ValueKey('online-profile-settings'),
      leading: _profile == null
          ? const Icon(Icons.public)
          : OnlineAvatarImage(avatarId: _profile!.avatarId, size: 42),
      title: const Text('Online avatar profile'),
      subtitle: Text(
        _profile == null
            ? 'Set the public name and image other online players will see'
            : '${_profile!.name} · Public name and image seen by online players',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: _edit,
    );
  }
}
