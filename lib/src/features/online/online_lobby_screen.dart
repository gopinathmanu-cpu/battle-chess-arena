// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/online_player_profile.dart';
import '../../domain/piece_pack.dart';
import '../../services/online_game_history.dart';
import '../../services/online_match_client.dart';
import '../../services/theme_music.dart';
import '../play/board_appearance.dart';
import 'online_game_screen.dart';

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
  static const _controls = <_OnlineTimeControl>[
    _OnlineTimeControl('3 min', 180000),
    _OnlineTimeControl('5 min', 300000),
    _OnlineTimeControl('10 min', 600000),
  ];

  late final OnlineMatchClient _client;
  final _avatarName = TextEditingController();
  final _gameId = TextEditingController();
  var _avatarId = onlineAvatarChoices.first.id;
  var _timeControl = _controls.last;
  var _history = <OnlineGameRecord>[];
  var _favorites = <OnlineFavorite>[];
  var _reminders = <String>{};
  var _loading = true;
  var _profileReady = false;
  String? _openedGameId;
  String? _savedProfileToken;
  int _savedSequence = -1;
  final _savedInviteGames = <String>{};
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
    final history = await OnlineGameHistory.loadGames();
    final favorites = await OnlineGameHistory.loadFavorites();
    final reminders = await OnlineGameHistory.loadReminders();
    if (!mounted) return;
    _history = history;
    _favorites = favorites;
    _reminders = reminders;
    if (profile != null) {
      _client.setProfile(profile);
      _avatarName.text = profile.name;
      _avatarId = profile.avatarId;
      _savedProfileToken = profile.playerToken;
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
    _gameId.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    final profile = _client.profile;
    if (profile?.playerToken != null &&
        profile!.playerToken != _savedProfileToken) {
      _savedProfileToken = profile.playerToken;
      unawaited(OnlineGameHistory.saveProfile(profile));
    }
    final state = _client.state;
    if (state != null &&
        _client.seat != null &&
        _client.seatToken != null &&
        state.sequence != _savedSequence) {
      _savedSequence = state.sequence;
      final opponent = state.opponentFor(_client.seat!);
      unawaited(
        _saveGame(
          OnlineGameRecord(
            gameId: state.gameId,
            seat: _client.seat!,
            seatToken: _client.seatToken!,
            opponentName: opponent.name,
            opponentAvatarId: opponent.avatarId,
            status: state.status,
            moveCount: state.san.length,
            updatedAt: DateTime.now(),
          ),
        ),
      );
    }
    for (final invitation in _client.invitations) {
      final game = invitation.game;
      if (game == null || !_savedInviteGames.add(game.gameId)) continue;
      final isRecipient = invitation.receivedBy(profile?.name ?? '');
      unawaited(
        _saveGame(
          OnlineGameRecord(
            gameId: game.gameId,
            seat: game.seat,
            seatToken: game.seatToken,
            opponentName: isRecipient
                ? invitation.senderName
                : invitation.recipientName,
            opponentAvatarId: isRecipient
                ? invitation.senderAvatarId
                : invitation.recipientAvatarId,
            status: game.state.status,
            moveCount: game.state.san.length,
            updatedAt: DateTime.now(),
          ),
        ),
      );
    }
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

  Future<void> _saveGame(OnlineGameRecord record) async {
    final history = await OnlineGameHistory.upsert(record);
    if (mounted) setState(() => _history = history);
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
    _client.setProfile(OnlinePlayerProfile(name: name, avatarId: _avatarId));
    setState(() => _profileReady = true);
    await _client.connect(_endpoint);
  }

  Future<void> _playAnother() async {
    _openedGameId = null;
    _savedSequence = -1;
    await _client.startAnotherGame();
  }

  Future<void> _resume(OnlineGameRecord record) async {
    _openedGameId = null;
    _savedSequence = -1;
    await _client.openSavedGame(
      savedGameId: record.gameId,
      savedSeat: record.seat,
      savedSeatToken: record.seatToken,
    );
  }

  void _openGame() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnlineGameScreen(client: _client, pack: widget.pack),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Online Match Lobby'),
      actions: const [MusicButton()],
    ),
    body: WorldBackdrop(
      pack: widget.pack,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _banner(),
                const SizedBox(height: 18),
                if (!_profileReady)
                  _profileForm()
                else ...[
                  _profileHeader(),
                  const SizedBox(height: 14),
                  _connectionStatus(),
                  if (_client.connected) ...[
                    const SizedBox(height: 18),
                    if (_client.gameId == null) _newGameControls(),
                    if (_client.gameId != null) _currentGameCard(),
                  ],
                  if (_client.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _client.error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_client.profile?.playerToken == null &&
                        _client.connection == MatchConnection.disconnected)
                      TextButton(
                        onPressed: () {
                          _client.disconnect();
                          setState(() => _profileReady = false);
                        },
                        child: const Text('Choose a different Avatar Name'),
                      ),
                  ],
                  const SizedBox(height: 24),
                  _historySection(),
                  const SizedBox(height: 24),
                  _favoritesSection(),
                  const SizedBox(height: 24),
                  _invitationsSection(),
                  const SizedBox(height: 24),
                  _leaderboardSection(),
                ],
              ],
            ),
    ),
  );

  Widget _banner() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          widget.pack.accent.withValues(alpha: .28),
          const Color(0xFF151725),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MULTIPLAYER ARENA',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        SizedBox(height: 8),
        Text(
          'Challenge several opponents, reopen active boards, and climb the leaderboard.',
        ),
      ],
    ),
  );

  Widget _profileForm() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create your arena avatar',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const Text('Avatar Names are unique across the arena.'),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('avatar-name-field'),
            controller: _avatarName,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: 'Avatar Name',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const Text('Choose an Avatar Icon'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final avatar in onlineAvatarChoices)
                ChoiceChip(
                  key: ValueKey('avatar-${avatar.id}'),
                  selected: _avatarId == avatar.id,
                  avatar: Icon(avatar.icon),
                  label: Text(avatar.label),
                  onSelected: (_) => setState(() => _avatarId = avatar.id),
                ),
            ],
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

  Widget _profileHeader() {
    final profile = _client.profile;
    final avatar = onlineAvatar(profile?.avatarId ?? _avatarId);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: widget.pack.accent.withValues(alpha: .25),
        child: Icon(avatar.icon, color: widget.pack.accent, size: 28),
      ),
      title: Text(
        profile?.name ?? _avatarName.text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
      subtitle: Text(avatar.label),
    );
  }

  Widget _connectionStatus() => Row(
    children: [
      Icon(
        _client.connected ? Icons.cloud_done : Icons.cloud_sync,
        color: _client.connected ? Colors.greenAccent : Colors.amberAccent,
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(_client.connectionLabel)),
      if (_client.connection == MatchConnection.disconnected)
        TextButton(
          onPressed: () => _client.connect(_endpoint),
          child: const Text('Retry'),
        ),
    ],
  );

  Widget _newGameControls() => Column(
    children: [
      DropdownButtonFormField<_OnlineTimeControl>(
        key: const ValueKey('online-time-control'),
        initialValue: _timeControl,
        decoration: const InputDecoration(
          labelText: 'Time control',
          prefixIcon: Icon(Icons.timer_outlined),
        ),
        items: [
          for (final control in _controls)
            DropdownMenuItem(value: control, child: Text(control.label)),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _timeControl = value);
        },
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        key: const ValueKey('quick-match-button'),
        onPressed: !_client.busy
            ? () => _client.quickMatch(baseMs: _timeControl.baseMs)
            : null,
        icon: const Icon(Icons.bolt),
        label: Text('Quick Match · ${_timeControl.label}'),
      ),
      const SizedBox(height: 18),
      const Divider(),
      OutlinedButton.icon(
        onPressed: !_client.busy
            ? () => _client.createGame(baseMs: _timeControl.baseMs)
            : null,
        icon: const Icon(Icons.add),
        label: Text('Create ${_timeControl.label} private room'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _gameId,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Friend’s Game ID',
          prefixIcon: Icon(Icons.key),
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: !_client.busy && _gameId.text.trim().isNotEmpty
            ? () => _client.joinGame(_gameId.text)
            : null,
        icon: const Icon(Icons.login),
        label: const Text('Join private room'),
      ),
    ],
  );

  Widget _currentGameCard() {
    if (_client.searchingForOpponent) {
      return Card(
        key: const ValueKey('matchmaking-waiting'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              const Text('Searching for an opponent…'),
              TextButton(
                onPressed: _client.busy ? null : _client.cancelMatchmaking,
                child: const Text('Cancel search'),
              ),
            ],
          ),
        ),
      );
    }
    final opponent = _client.state?.opponentFor(_client.seat ?? 'w');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                child: Icon(onlineAvatar(opponent?.avatarId ?? 'crown').icon),
              ),
              title: Text(opponent?.name ?? 'Waiting opponent'),
              subtitle: Text(_client.state?.statusLabel ?? 'Waiting'),
            ),
            SelectableText('Game ID: ${_client.gameId}'),
            if (_client.state?.status != 'waiting')
              FilledButton(
                onPressed: _openGame,
                child: const Text('Return to game'),
              ),
            OutlinedButton(
              key: const ValueKey('play-another-opponent'),
              onPressed: _playAnother,
              child: const Text('Play another opponent'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historySection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'GAME HISTORY',
        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1),
      ),
      if (_history.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Active and completed games will appear here.'),
        ),
      for (final record in _history)
        Card(
          key: ValueKey('history-${record.gameId}'),
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(onlineAvatar(record.opponentAvatarId).icon),
            ),
            title: Text(record.opponentName),
            subtitle: Text(
              '${record.isOpen ? 'Open' : 'Completed'} · ${record.moveCount} moves · ${record.seat == 'w' ? 'White' : 'Black'}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Favourite opponent',
                  onPressed: () => _toggleFavorite(
                    record.opponentName,
                    record.opponentAvatarId,
                  ),
                  icon: Icon(
                    _favorites.any(
                          (item) =>
                              item.name.toLowerCase() ==
                              record.opponentName.toLowerCase(),
                        )
                        ? Icons.favorite
                        : Icons.favorite_border,
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _resume(record),
          ),
        ),
    ],
  );

  Widget _favoritesSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'FAVOURITE OPPONENTS',
        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1),
      ),
      const SizedBox(height: 6),
      if (_favorites.isEmpty)
        const Text('Tap the heart beside a game-history opponent to add them.'),
      for (final favorite in _favorites)
        Card(
          child: ListTile(
            leading: Stack(
              children: [
                CircleAvatar(child: Icon(onlineAvatar(favorite.avatarId).icon)),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _client.presence[favorite.name] == true
                          ? Colors.greenAccent
                          : Colors.grey,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            title: Text(favorite.name),
            subtitle: Text(
              _client.presence[favorite.name] == true ? 'Online' : 'Offline',
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'Invite opponent',
              onSelected: (value) {
                if (value == 'now') {
                  _client.sendInvitation(favorite.name);
                } else if (value == 'schedule') {
                  _scheduleInvitation(favorite);
                } else if (value == 'remove') {
                  _toggleFavorite(favorite.name, favorite.avatarId);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'now', child: Text('Invite now')),
                PopupMenuItem(
                  value: 'schedule',
                  child: Text('Schedule invitation'),
                ),
                PopupMenuItem(value: 'remove', child: Text('Remove favourite')),
              ],
            ),
          ),
        ),
    ],
  );

  Future<void> _scheduleInvitation(OnlineFavorite favorite) async {
    final delay = await showModalBottomSheet<Duration>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Schedule game',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            for (final choice in const [
              ('In 15 minutes', Duration(minutes: 15)),
              ('In 1 hour', Duration(hours: 1)),
              ('Tomorrow', Duration(days: 1)),
            ])
              ListTile(
                title: Text(choice.$1),
                onTap: () => Navigator.pop(context, choice.$2),
              ),
          ],
        ),
      ),
    );
    if (delay != null) {
      _client.sendInvitation(
        favorite.name,
        scheduledAt: DateTime.now().add(delay),
      );
    }
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
        if (_client.invitations.isEmpty)
          const Text('Sent and received invitations will appear here.'),
        for (final invitation in _client.invitations)
          Builder(
            builder: (context) {
              final received = invitation.receivedBy(name);
              final opponentName = received
                  ? invitation.senderName
                  : invitation.recipientName;
              final opponentAvatar = received
                  ? invitation.senderAvatarId
                  : invitation.recipientAvatarId;
              final scheduled = invitation.scheduledAt;
              return Card(
                key: ValueKey('invite-${invitation.inviteId}'),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(onlineAvatar(opponentAvatar).icon),
                  ),
                  title: Text('${received ? 'From' : 'To'} $opponentName'),
                  subtitle: Text(
                    '${invitation.status.toUpperCase()}${scheduled == null ? ' · Play now' : ' · ${_formatSchedule(scheduled)}'}',
                  ),
                  trailing: invitation.status == 'pending' && received
                      ? Wrap(
                          spacing: 2,
                          children: [
                            IconButton(
                              tooltip: 'Decline invitation',
                              onPressed: () => _client.respondToInvitation(
                                invitation.inviteId,
                                false,
                              ),
                              icon: const Icon(Icons.close),
                            ),
                            IconButton(
                              tooltip: 'Accept invitation',
                              onPressed: () => _client.respondToInvitation(
                                invitation.inviteId,
                                true,
                              ),
                              icon: const Icon(Icons.check),
                            ),
                          ],
                        )
                      : scheduled != null &&
                            ['pending', 'accepted'].contains(invitation.status)
                      ? IconButton(
                          tooltip: 'Scheduled-game reminder',
                          onPressed: () => _toggleReminder(invitation.inviteId),
                          icon: Icon(
                            _reminders.contains(invitation.inviteId)
                                ? Icons.notifications_active
                                : Icons.notifications_none,
                          ),
                        )
                      : invitation.game != null
                      ? const Icon(Icons.sports_esports)
                      : null,
                ),
              );
            },
          ),
      ],
    );
  }

  String _formatSchedule(DateTime value) {
    final local = value.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month} ${local.hour}:$minute';
  }

  Widget _leaderboardSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'LEADERBOARD',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1),
            ),
          ),
          IconButton(
            tooltip: 'Refresh leaderboard',
            onPressed: _client.loadLeaderboard,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const Text('Win 3 points · Draw 1 point · Loss 0 points'),
      const SizedBox(height: 8),
      for (var index = 0; index < _client.leaderboard.length; index++)
        ListTile(
          dense: true,
          leading: CircleAvatar(
            child: Icon(onlineAvatar(_client.leaderboard[index].avatarId).icon),
          ),
          title: Text(
            '${index + 1}. ${_client.leaderboard[index].name}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${_client.leaderboard[index].wins}W  ${_client.leaderboard[index].draws}D  ${_client.leaderboard[index].losses}L',
          ),
          trailing: Text(
            '${_client.leaderboard[index].points} pts',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
    ],
  );
}

class _OnlineTimeControl {
  const _OnlineTimeControl(this.label, this.baseMs);
  final String label;
  final int baseMs;
}
