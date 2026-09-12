// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/online_player_profile.dart';
import '../../domain/online_social.dart';
import '../../domain/online_time_control.dart';
import '../../domain/piece_pack.dart';
import '../../services/online_game_history.dart';
import '../../services/online_match_client.dart';
import '../../services/theme_music.dart';
import '../play/board_appearance.dart';
import 'online_game_screen.dart';
import 'online_avatar_image.dart';

class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({required this.pack, this.client, super.key});
  final PiecePack pack;
  final OnlineMatchClient? client;

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  static final _endpoint = Uri.parse(
    const String.fromEnvironment(
      'ONLINE_SERVER_URL',
      defaultValue: 'wss://battle-chess-arena-server.onrender.com',
    ),
  );
  late final OnlineMatchClient _client;
  final _avatarName = TextEditingController();
  final _opponentSearch = TextEditingController();
  var _avatarId = onlineAvatarChoices.first.id;
  var _playerLevel = OnlinePlayerLevel.intermediate;
  var _timeControl = onlineTimeControls.last;
  var _favorites = <OnlineFavorite>[];
  var _reminders = <String>{};
  var _loading = true;
  var _profileReady = false;
  String? _openedGameId;
  String? _savedProfileKey;
  final _shownReminders = <String>{};
  String? _presenceRequestKey;
  Timer? _reminderTimer;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? OnlineMatchClient();
    _client.addListener(_refresh);
    _reminderTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _showDueReminder(),
    );
    if (widget.client != null) {
      _profileReady = true;
      _loading = false;
    } else {
      unawaited(_restore());
    }
  }

  Future<void> _restore() async {
    final profile = await OnlineGameHistory.loadProfile();
    final restored = await Future.wait([
      OnlineGameHistory.loadFavorites(),
      OnlineGameHistory.loadReminders(),
    ]);
    if (!mounted) return;
    _favorites = restored[0] as List<OnlineFavorite>;
    _reminders = restored[1] as Set<String>;
    if (profile != null) {
      _client.setProfile(profile);
      _avatarName.text = profile.name;
      _avatarId = profile.avatarId;
      _playerLevel = profile.level;
      _savedProfileKey =
          '${profile.name}|${profile.avatarId}|${profile.level.name}|${profile.playerToken}';
      _profileReady = true;
    }
    setState(() => _loading = false);
    if (profile != null) await _client.connect(_endpoint);
  }

  @override
  void dispose() {
    _client.removeListener(_refresh);
    _reminderTimer?.cancel();
    if (widget.client == null) _client.dispose();
    _avatarName.dispose();
    _opponentSearch.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    final profile = _client.profile;
    final profileKey = profile == null
        ? null
        : '${profile.name}|${profile.avatarId}|${profile.level.name}|${profile.playerToken}';
    if (profile?.playerToken != null && profileKey != _savedProfileKey) {
      _savedProfileKey = profileKey;
      unawaited(OnlineGameHistory.saveProfile(profile!));
    }
    final state = _client.state;
    if (_client.connected && _favorites.isNotEmpty) {
      final key = (_favorites.map((favorite) => favorite.name).toList()..sort())
          .join('|');
      if (key != _presenceRequestKey) {
        _presenceRequestKey = key;
        _client.loadPresence(_favorites.map((favorite) => favorite.name));
      }
    }
    setState(() {});
    if (state != null &&
        state.status != 'waiting' &&
        _client.connected &&
        _openedGameId != state.gameId) {
      _openedGameId = state.gameId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openGame();
      });
    }
  }

  void _showDueReminder() {
    if (!mounted) return;
    final now = DateTime.now();
    for (final invitation in _client.invitations) {
      final scheduled = invitation.scheduledAt;
      if (!_reminders.contains(invitation.inviteId) ||
          _shownReminders.contains(invitation.inviteId) ||
          scheduled == null ||
          scheduled.isAfter(now) ||
          ['declined', 'blocked'].contains(invitation.status)) {
        continue;
      }
      _shownReminders.add(invitation.inviteId);
      final opponent = invitation.receivedBy(_client.profile?.name ?? '')
          ? invitation.senderName
          : invitation.recipientName;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scheduled game with $opponent is due now.')),
      );
    }
  }

  Future<void> _toggleFavorite(String name, String avatarId) async {
    final favorites = await OnlineGameHistory.toggleFavorite(
      OnlineFavorite(name: name, avatarId: avatarId),
    );
    if (!mounted) return;
    setState(() => _favorites = favorites);
    _presenceRequestKey = null;
    _client.loadPresence(favorites.map((favorite) => favorite.name));
  }

  Future<void> _toggleReminder(String inviteId) async {
    setState(() {
      if (!_reminders.add(inviteId)) _reminders.remove(inviteId);
    });
    await OnlineGameHistory.saveReminders(_reminders);
  }

  Future<void> _deleteInvitation(OnlineInvitation invitation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete invitation?'),
        content: const Text(
          'This removes the invitation from your list only. Any accepted game and the other player’s copy remain available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _client.deleteInvitation(invitation.inviteId);
    _reminders.remove(invitation.inviteId);
    await OnlineGameHistory.saveReminders(_reminders);
  }

  Future<void> _createProfile() async {
    final name = _avatarName.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9 _-]{2,19}$').hasMatch(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use 3–20 letters, numbers, spaces, _ or -'),
        ),
      );
      return;
    }
    _client.setProfile(
      OnlinePlayerProfile(name: name, avatarId: _avatarId, level: _playerLevel),
    );
    setState(() => _profileReady = true);
    await _client.connect(_endpoint);
  }

  Future<void> _playAnother() async {
    _openedGameId = null;
    await _client.startAnotherGame();
  }

  void _openGame() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnlineGameScreen(client: _client, pack: widget.pack),
      ),
    );
  }

  Future<void> _openInvitation(OnlineInvitation invitation) async {
    final game = invitation.game;
    if (game == null) return;
    _openedGameId = null;
    await _client.openSavedGame(
      savedGameId: game.gameId,
      savedSeat: game.seat,
      savedSeatToken: game.seatToken,
    );
  }

  Future<void> _openActiveGame(OnlineInviteGame game) async {
    _openedGameId = null;
    await _client.openSavedGame(
      savedGameId: game.gameId,
      savedSeat: game.seat,
      savedSeatToken: game.seatToken,
    );
  }

  Future<DateTime?> _pickDateTime({DateTime? initial}) async {
    final now = DateTime.now();
    final seed = initial != null && initial.isAfter(now)
        ? initial.toLocal()
        : now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(seed.year, seed.month, seed.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(seed),
    );
    if (time == null) return null;
    final result = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!result.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose a time at least one minute from now.'),
          ),
        );
      }
      return null;
    }
    return result;
  }

  Future<void> _scheduleFor(String opponentName) async {
    final scheduled = await _pickDateTime();
    if (scheduled == null || !mounted) return;
    final format = await _pickInviteFormat();
    if (format == null) return;
    _client.sendInvitation(
      opponentName,
      scheduledAt: scheduled,
      timed: format.timed,
      baseMs: format.baseMs,
    );
  }

  Future<void> _inviteNow(String opponentName) async {
    final format = await _pickInviteFormat();
    if (format == null) return;
    _client.sendInvitation(
      opponentName,
      timed: format.timed,
      baseMs: format.baseMs,
    );
  }

  Future<void> _counterInvitation(OnlineInvitation invitation) async {
    final scheduled = await _pickDateTime(initial: invitation.scheduledAt);
    if (scheduled == null || !mounted) return;
    final format = await _pickInviteFormat(
      timed: invitation.timed,
      baseMs: invitation.baseMs,
    );
    if (format == null) return;
    _client.proposeInvitationTime(
      invitation.inviteId,
      scheduled,
      timed: format.timed,
      baseMs: format.baseMs,
    );
  }

  Future<_InviteFormat?> _pickInviteFormat({
    bool timed = true,
    int baseMs = 900000,
  }) {
    baseMs = closestOnlineTimeControl(baseMs).baseMs;
    return showDialog<_InviteFormat>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Game timer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Timed game'),
                subtitle: Text(
                  timed ? 'Both players use a clock.' : 'Play without a clock.',
                ),
                value: timed,
                onChanged: (value) => setDialogState(() => timed = value),
              ),
              if (timed)
                DropdownButtonFormField<int>(
                  initialValue: baseMs,
                  decoration: const InputDecoration(
                    labelText: 'Time per player',
                  ),
                  items: [
                    for (final control in onlineTimeControls)
                      DropdownMenuItem(
                        value: control.baseMs,
                        child: Text(control.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => baseMs = value);
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, _InviteFormat(timed, baseMs)),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editProfile() async {
    final profile = _client.profile;
    if (profile == null) return;
    final controller = TextEditingController(text: profile.name);
    var avatarId = profile.avatarId;
    var level = profile.level;
    final updated = await showDialog<(String, String, OnlinePlayerLevel)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit online profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  maxLength: 20,
                  decoration: const InputDecoration(labelText: 'Avatar ID'),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final avatar in onlineAvatarChoices)
                      ChoiceChip(
                        selected: avatarId == avatar.id,
                        avatar: OnlineAvatarImage(
                          avatarId: avatar.id,
                          size: 28,
                        ),
                        label: Text(avatar.label),
                        onSelected: (_) =>
                            setDialogState(() => avatarId = avatar.id),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<OnlinePlayerLevel>(
                  initialValue: level,
                  decoration: const InputDecoration(labelText: 'Player level'),
                  items: [
                    for (final option in OnlinePlayerLevel.values)
                      DropdownMenuItem(
                        value: option,
                        child: Text(option.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => level = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim().replaceAll(
                  RegExp(r'\s+'),
                  ' ',
                );
                if (!RegExp(
                  r'^[A-Za-z0-9][A-Za-z0-9 _-]{2,19}$',
                ).hasMatch(name)) {
                  return;
                }
                Navigator.pop(context, (name, avatarId, level));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (updated != null) {
      _client.updateProfile(
        name: updated.$1,
        avatarId: updated.$2,
        level: updated.$3,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Play Online'),
      actions: const [MusicButton()],
    ),
    body: WorldBackdrop(
      pack: widget.pack,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_profileReady
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: [_profileForm()],
            )
          : RefreshIndicator(
              onRefresh: () async {
                _client.loadInvitations();
                _client.loadLeaderboard();
                _client.loadPointHistory();
                _client.loadActiveGames();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _profileSummary(),
                  if (_client.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _client.error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _quickGameCard(),
                  const SizedBox(height: 10),
                  _findOpponentCard(),
                  const SizedBox(height: 20),
                  _activeGamesSection(),
                  const SizedBox(height: 20),
                  _invitationsSection(),
                  const SizedBox(height: 20),
                  _rankingSection(),
                ],
              ),
            ),
    ),
  );

  Widget _profileForm() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create your online Avatar ID',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text('Your Avatar ID is unique and lets friends find you.'),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('avatar-name-field'),
            controller: _avatarName,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: 'Avatar ID',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const Text('Choose an icon'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final avatar in onlineAvatarChoices)
                ChoiceChip(
                  key: ValueKey('avatar-${avatar.id}'),
                  selected: _avatarId == avatar.id,
                  avatar: OnlineAvatarImage(avatarId: avatar.id, size: 28),
                  label: Text(avatar.label),
                  onSelected: (_) => setState(() => _avatarId = avatar.id),
                ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<OnlinePlayerLevel>(
            key: const ValueKey('player-level-selector'),
            initialValue: _playerLevel,
            decoration: const InputDecoration(
              labelText: 'Player level',
              prefixIcon: Icon(Icons.equalizer),
            ),
            items: [
              for (final level in OnlinePlayerLevel.values)
                DropdownMenuItem(value: level, child: Text(level.label)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _playerLevel = value);
            },
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const ValueKey('enter-arena-button'),
            onPressed: _createProfile,
            icon: const Icon(Icons.sports_esports),
            label: const Text('Enter Arena'),
          ),
        ],
      ),
    ),
  );

  Widget _profileSummary() {
    final profile = _client.profile;
    final mine = _client.leaderboard.where(
      (entry) => entry.name.toLowerCase() == profile?.name.toLowerCase(),
    );
    final points = mine.isEmpty ? 0 : mine.first.points;
    return Row(
      children: [
        OnlineAvatarImage(avatarId: profile?.avatarId ?? _avatarId, size: 52),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile?.name ?? _avatarName.text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${_client.connectionLabel} · ${profile?.level.label ?? _playerLevel.label}',
              ),
            ],
          ),
        ),
        Chip(label: Text('$points pts')),
        IconButton(
          tooltip: 'Edit Avatar ID and image',
          onPressed: _client.connected && !_client.busy ? _editProfile : null,
          icon: const Icon(Icons.edit),
        ),
        if (_client.connection == MatchConnection.disconnected)
          IconButton(
            tooltip: 'Reconnect',
            onPressed: () => _client.connect(_endpoint),
            icon: const Icon(Icons.refresh),
          ),
      ],
    );
  }

  Widget _quickGameCard() {
    if (_client.searchingForOpponent) {
      return Card(
        key: const ValueKey('matchmaking-waiting'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                'Finding a ${_client.profile?.level.label.toLowerCase() ?? 'similar-level'} opponent…',
              ),
              const Text(
                'Search expands to other levels after 15 seconds.',
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: _client.busy ? null : _client.cancelMatchmaking,
                child: const Text('Cancel search'),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Quick Game',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            Text(
              'Matches your ${_client.profile?.level.label ?? 'player'} level first.',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<OnlineTimeControl>(
                    key: const ValueKey('online-time-control'),
                    initialValue: _timeControl,
                    decoration: const InputDecoration(labelText: 'Game time'),
                    items: [
                      for (final control in onlineTimeControls)
                        DropdownMenuItem(
                          value: control,
                          child: Text(control.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _timeControl = value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  key: const ValueKey('quick-match-button'),
                  onPressed: _client.connected && !_client.busy
                      ? () async {
                          if (_client.gameId != null) await _playAnother();
                          _client.quickMatch(baseMs: _timeControl.baseMs);
                        }
                      : null,
                  icon: const Icon(Icons.bolt),
                  label: const Text('Play'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _findOpponentCard() => Card(
    child: ExpansionTile(
      key: const ValueKey('find-opponent-section'),
      leading: const Icon(Icons.person_search),
      title: const Text(
        'Find Opponent',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: const Text('Search by exact Avatar ID'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        TextField(
          key: const ValueKey('opponent-search-field'),
          controller: _opponentSearch,
          maxLength: 20,
          textInputAction: TextInputAction.search,
          onSubmitted: _client.findPlayer,
          decoration: InputDecoration(
            labelText: 'Avatar ID',
            suffixIcon: IconButton(
              tooltip: 'Search',
              onPressed: () => _client.findPlayer(_opponentSearch.text),
              icon: const Icon(Icons.search),
            ),
          ),
        ),
        if (_client.playerSearchCompleted && _client.playerSearchResult == null)
          const ListTile(title: Text('No matching Avatar ID found.')),
        if (_client.playerSearchResult case final result?)
          ListTile(
            key: const ValueKey('opponent-search-result'),
            contentPadding: EdgeInsets.zero,
            leading: OnlineAvatarImage(avatarId: result.avatarId),
            title: Text(result.name),
            subtitle: Text(
              '${result.level.label} · ${result.online ? 'Online' : 'Offline'}',
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'Opponent actions',
              onSelected: (action) {
                if (action == 'now') _inviteNow(result.name);
                if (action == 'schedule') _scheduleFor(result.name);
                if (action == 'favorite') {
                  _toggleFavorite(result.name, result.avatarId);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'now', child: Text('Invite now')),
                PopupMenuItem(
                  value: 'schedule',
                  child: Text('Choose date & time'),
                ),
                PopupMenuItem(
                  value: 'favorite',
                  child: Text('Add/remove favourite'),
                ),
              ],
            ),
          ),
        if (_favorites.isNotEmpty) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Favourites',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final favorite in _favorites)
                ActionChip(
                  avatar: OnlineAvatarImage(
                    avatarId: favorite.avatarId,
                    size: 26,
                  ),
                  label: Text(favorite.name),
                  onPressed: () {
                    _opponentSearch.text = favorite.name;
                    _client.findPlayer(favorite.name);
                  },
                ),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _activeGamesSection() {
    final serverActive = _client.activeGames;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACTIVE GAMES',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1),
        ),
        const SizedBox(height: 6),
        if (_client.activeGamesLoaded && serverActive.isEmpty)
          const Text('You have no open games.'),
        if (!_client.activeGamesLoaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('Loading your open games…'),
              ],
            ),
          ),
        for (final game in serverActive)
          Builder(
            builder: (context) {
              final opponent = game.state.opponentFor(game.seat);
              return Card(
                key: ValueKey('active-${game.gameId}'),
                child: ListTile(
                  leading: OnlineAvatarImage(avatarId: opponent.avatarId),
                  title: Text(opponent.name),
                  subtitle: Text(
                    '${game.state.status == 'waiting' ? 'Waiting' : 'In progress'} · ${game.state.san.length} moves',
                  ),
                  trailing: const Icon(Icons.play_arrow),
                  onTap: () => _openActiveGame(game),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _invitationsSection() {
    final name = _client.profile?.name ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'INVITATIONS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh invitations',
              onPressed: _client.loadInvitations,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_client.invitations.isEmpty) const Text('No invitations.'),
        for (final invitation in _client.invitations)
          _invitationTile(invitation, name),
      ],
    );
  }

  Widget _invitationTile(OnlineInvitation invitation, String myName) {
    final received = invitation.receivedBy(myName);
    final opponentName = received
        ? invitation.senderName
        : invitation.recipientName;
    final opponentAvatar = received
        ? invitation.senderAvatarId
        : invitation.recipientAvatarId;
    final canRespond = invitation.canRespondBy(myName);
    final acceptedGame =
        invitation.status == 'accepted' && invitation.game != null;
    final schedule = invitation.scheduledAt == null
        ? 'Play now'
        : _formatSchedule(invitation.scheduledAt!);
    final gameFormat = invitation.timed
        ? '${invitation.baseMs ~/ 60000} min timed'
        : 'No timer';
    final status = acceptedGame
        ? 'Ready to play · $gameFormat'
        : canRespond
        ? 'Your response · $schedule · $gameFormat'
        : invitation.status == 'pending'
        ? 'Waiting for ${invitation.awaitingResponseFromName} · $schedule · $gameFormat'
        : '${invitation.status.toUpperCase()} · $schedule · $gameFormat';
    return Card(
      key: ValueKey('invite-${invitation.inviteId}'),
      child: ListTile(
        onTap: acceptedGame ? () => _openInvitation(invitation) : null,
        leading: OnlineAvatarImage(avatarId: opponentAvatar),
        title: Text(opponentName),
        subtitle: Text(status),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (acceptedGame) const Icon(Icons.play_arrow),
            if (canRespond)
              PopupMenuButton<String>(
                tooltip: 'Respond to invitation',
                onSelected: (action) {
                  if (action == 'accept') {
                    _client.respondToInvitation(invitation.inviteId, true);
                  }
                  if (action == 'decline') {
                    _client.respondToInvitation(invitation.inviteId, false);
                  }
                  if (action == 'counter') _counterInvitation(invitation);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'accept', child: Text('Accept')),
                  PopupMenuItem(
                    value: 'counter',
                    child: Text('Propose new date & time'),
                  ),
                  PopupMenuItem(value: 'decline', child: Text('Decline')),
                ],
              )
            else if (invitation.scheduledAt != null &&
                ['pending', 'accepted'].contains(invitation.status))
              IconButton(
                tooltip: 'Scheduled-game reminder',
                onPressed: () => _toggleReminder(invitation.inviteId),
                icon: Icon(
                  _reminders.contains(invitation.inviteId)
                      ? Icons.notifications_active
                      : Icons.notifications_none,
                ),
              ),
            IconButton(
              key: ValueKey('delete-invite-${invitation.inviteId}'),
              tooltip: 'Delete invitation',
              onPressed: () => _deleteInvitation(invitation),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rankingSection() {
    final myName = _client.profile?.name ?? '';
    final mine = _client.leaderboard.where(
      (entry) => entry.name.toLowerCase() == myName.toLowerCase(),
    );
    final entry = mine.isEmpty ? null : mine.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'YOUR RANKING',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1),
            ),
            const SizedBox(height: 8),
            Text(
              '${entry?.points ?? 0} points',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            Text(
              '${entry?.wins ?? 0} wins · ${entry?.draws ?? 0} draws · ${entry?.losses ?? 0} losses',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _showPointsBreakdown,
                  child: const Text('Game history'),
                ),
                FilledButton.tonal(
                  onPressed: _showLeaderboard,
                  child: const Text('View leaderboard'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLeaderboard() async {
    _client.loadLeaderboard();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(
            children: [
              const ListTile(
                title: Text(
                  'Leaderboard',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                subtitle: Text('Win 3 · Draw 1 · Loss 0'),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _client.leaderboard.length,
                  itemBuilder: (_, index) {
                    final entry = _client.leaderboard[index];
                    return ListTile(
                      leading: OnlineAvatarImage(avatarId: entry.avatarId),
                      title: Text('${index + 1}. ${entry.name}'),
                      subtitle: Text(
                        '${entry.level.label} · ${entry.wins}W  ${entry.draws}D  ${entry.losses}L',
                      ),
                      trailing: Text(
                        '${entry.points} pts',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPointsBreakdown() async {
    _client.loadPointHistory();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(
            children: [
              const ListTile(
                title: Text(
                  'Game history',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                subtitle: Text('Completed games are retained with your score.'),
              ),
              if (_client.pointHistory.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('Completed matches will appear here.'),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    children: [
                      for (final match in _client.pointHistory)
                        Card(
                          key: ValueKey('history-${match.recordId}'),
                          child: ListTile(
                            leading: OnlineAvatarImage(
                              avatarId: match.opponentAvatarId,
                            ),
                            title: Text(match.opponentName),
                            subtitle: Text(
                              '${_historyStatus(match.result)} · ${_formatSchedule(match.completedAt)}',
                            ),
                            trailing: Chip(label: Text('+${match.points} pts')),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSchedule(DateTime value) {
    final local = value.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} $hour:$minute';
  }

  String _historyStatus(String result) => switch (result) {
    'win' => 'WON',
    'loss' => 'LOST',
    _ => 'DRAW',
  };
}

class _InviteFormat {
  const _InviteFormat(this.timed, this.baseMs);
  final bool timed;
  final int baseMs;
}
