// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/online_player_profile.dart';
import '../../domain/online_credits.dart';
import '../../domain/avatar_name_policy.dart';
import '../../domain/online_social.dart';
import '../../domain/online_time_control.dart';
import '../../domain/piece_pack.dart';
import '../../services/online_game_history.dart';
import '../../services/arena_credit_controller.dart';
import '../../services/game_invite_links.dart';
import '../../services/online_match_client.dart';
import '../../services/mobile_notifications.dart';
import '../../services/theme_music.dart';
import '../../services/player_identity_controller.dart';
import '../credits/gold_credit_coin.dart';
import '../credits/credit_rules_sheet.dart';
import '../play/board_appearance.dart';
import '../play/play_assist_style.dart';
import 'online_game_screen.dart';
import 'invitation_waiting_screen.dart';
import 'online_avatar_image.dart';

class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({
    required this.pack,
    this.client,
    this.endpoint,
    this.initialClassicPieces = true,
    this.initialAnimatedArena,
    this.initialClassicStyle = ClassicPieceStyle.magneticTeaching,
    this.initialGameId,
    this.initialSharedInviteId,
    this.launchExternal,
    this.notifications,
    super.key,
  });
  final PiecePack pack;
  final OnlineMatchClient? client;
  final Uri? endpoint;
  final bool initialClassicPieces;
  final bool? initialAnimatedArena;
  final ClassicPieceStyle initialClassicStyle;
  final String? initialGameId;
  final String? initialSharedInviteId;
  final Future<bool> Function(Uri uri)? launchExternal;
  final MobileNotificationService? notifications;

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  static const _serverUrl = onlineServerUrl;
  late final OnlineMatchClient _client;
  late final MobileNotificationService _notifications;
  final _avatarName = TextEditingController();
  final _opponentSearch = TextEditingController();
  var _avatarId = onlineAvatarChoices.first.id;
  var _playerLevel = OnlinePlayerLevel.intermediate;
  var _timeControl = onlineTimeControls.first;
  bool _tossForColors = false;
  var _favorites = <OnlineFavorite>[];
  var _reminders = <String>{};
  var _loading = true;
  var _profileReady = false;
  String? _openedGameId;
  String? _waitingInviteId;
  String? _pendingWaitOpponent;
  String? _acceptedInviteId;
  String? _savedProfileKey;
  final _shownReminders = <String>{};
  String? _presenceRequestKey;
  Timer? _reminderTimer;
  String? _pendingInviteGameId;
  String? _pendingSharedInviteId;
  bool _preparingWhatsAppInvite = false;
  bool _mobileNotificationsEnabled = false;
  bool _notificationPreferenceReady = false;
  final _deliveredNotificationEvents = <String>{};
  final _scheduledNotificationSignatures = <String, String>{};
  int? _lastCreditBalance;
  ArenaCreditController? _creditHeader;
  OnlineCreditAccount? _publishedCreditAccount;
  String? _publishedCreditToken;
  int? _publishedCreditPolicyVersion;
  String? _leaderboardSnapshot;
  int? _observedLeaderboardRank;
  int _leaderboardMovement = 0;

  Uri? get _endpoint {
    if (widget.endpoint != null) return widget.endpoint;
    final endpoint = Uri.tryParse(_serverUrl);
    return endpoint != null &&
            endpoint.host.isNotEmpty &&
            const {'ws', 'wss'}.contains(endpoint.scheme)
        ? endpoint
        : null;
  }

  bool get _networkConfigured => _endpoint != null;

  @override
  void initState() {
    super.initState();
    _pendingInviteGameId = widget.initialGameId;
    _pendingSharedInviteId = widget.initialSharedInviteId;
    _client = widget.client ?? OnlineMatchClient();
    _lastCreditBalance = _client.credits;
    _notifications = widget.notifications ?? MobileNotificationService();
    _client.addListener(_refresh);
    unawaited(_restoreNotificationPreference());
    _reminderTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _showDueReminder();
      if (mounted) setState(() {});
    });
    if (widget.client != null) {
      _profileReady = true;
      _loading = false;
      unawaited(_restoreSavedPlayerLists());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryJoinPendingInvite();
      });
    } else {
      unawaited(_restore());
    }
  }

  Future<void> _restoreSavedPlayerLists() async {
    final restored = await Future.wait([
      OnlineGameHistory.loadFavorites(),
      OnlineGameHistory.loadReminders(),
    ]);
    if (!mounted) return;
    setState(() {
      _favorites = restored[0] as List<OnlineFavorite>;
      _reminders = restored[1] as Set<String>;
    });
    _requestConnectionPresence();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _creditHeader = ArenaCreditScope.maybeOf(context);
    _syncCreditHeader();
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
    final endpoint = _endpoint;
    if (profile != null && endpoint != null) await _client.connect(endpoint);
  }

  Future<void> _restoreNotificationPreference() async {
    final enabled = await OnlineGameHistory.loadMobileNotificationsEnabled();
    if (!mounted) return;
    setState(() {
      _mobileNotificationsEnabled = enabled && _notifications.isSupported;
      _notificationPreferenceReady = true;
    });
    if (_mobileNotificationsEnabled) {
      unawaited(_processInvitationNotifications());
    }
  }

  @override
  void dispose() {
    _creditHeader?.markDisconnected(profileToken: _client.profile?.playerToken);
    _client.removeListener(_refresh);
    _reminderTimer?.cancel();
    if (widget.client == null) _client.dispose();
    _avatarName.dispose();
    _opponentSearch.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    _captureLeaderboardMovement();
    _syncCreditHeader();
    final nextCreditBalance = _client.credits;
    final previousCreditBalance = _lastCreditBalance;
    if (nextCreditBalance != null) _lastCreditBalance = nextCreditBalance;
    final profile = _client.profile;
    final profileKey = profile == null
        ? null
        : '${profile.name}|${profile.avatarId}|${profile.level.name}|${profile.playerToken}';
    if (profile?.playerToken != null && profileKey != _savedProfileKey) {
      _savedProfileKey = profileKey;
      unawaited(OnlineGameHistory.saveProfile(profile!));
    }
    if (profile?.playerToken == null &&
        _client.error != null &&
        !_client.connected) {
      _profileReady = false;
    }
    if (_pendingWaitOpponent != null) {
      final invitation = _client.invitations
          .where(
            (item) =>
                item.senderName.toLowerCase() ==
                    _client.profile?.name.toLowerCase() &&
                item.recipientName.toLowerCase() ==
                    _pendingWaitOpponent!.toLowerCase() &&
                item.scheduledAt == null &&
                item.status == 'pending' &&
                !item.isExpired,
          )
          .firstOrNull;
      if (invitation != null) {
        _pendingWaitOpponent = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _waitForInvitation(invitation);
        });
      } else if (_client.error != null) {
        _pendingWaitOpponent = null;
      }
    }
    if (_acceptedInviteId != null) {
      final accepted = _client.invitations
          .where(
            (item) =>
                item.inviteId == _acceptedInviteId &&
                item.game != null &&
                item.status == 'accepted',
          )
          .firstOrNull;
      if (accepted != null) {
        _acceptedInviteId = null;
        unawaited(_openInvitation(accepted));
      } else if (_client.error != null) {
        _acceptedInviteId = null;
      }
    }
    final state = _client.state;
    _requestConnectionPresence();
    _tryJoinPendingInvite();
    setState(() {});
    if (previousCreditBalance != null &&
        nextCreditBalance != null &&
        nextCreditBalance > previousCreditBalance) {
      _showCreditAddition(nextCreditBalance - previousCreditBalance);
    } else if (previousCreditBalance != null &&
        nextCreditBalance != null &&
        nextCreditBalance < previousCreditBalance) {
      _showCreditDeduction(previousCreditBalance - nextCreditBalance);
    }
    if (_mobileNotificationsEnabled) {
      unawaited(_processInvitationNotifications());
    }
    if (_waitingInviteId == null &&
        state != null &&
        state.status != 'waiting' &&
        _client.connected &&
        _openedGameId != state.gameId) {
      _openedGameId = state.gameId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openGame();
      });
    }
  }

  void _captureLeaderboardMovement() {
    final entries = _client.leaderboard;
    final snapshot = entries
        .map(
          (entry) =>
              '${entry.name}:${entry.points}:${entry.wins}:${entry.draws}:${entry.losses}',
        )
        .join('|');
    if (snapshot == _leaderboardSnapshot) return;
    final myName = _client.profile?.name.toLowerCase();
    final index = myName == null
        ? -1
        : entries.indexWhere((entry) => entry.name.toLowerCase() == myName);
    final nextRank = index < 0 ? null : index + 1;
    if (_leaderboardSnapshot != null &&
        _observedLeaderboardRank != null &&
        nextRank != null) {
      _leaderboardMovement = _observedLeaderboardRank! - nextRank;
    }
    _observedLeaderboardRank = nextRank;
    _leaderboardSnapshot = snapshot;
  }

  void _syncCreditHeader() {
    final header = _creditHeader;
    final profileToken = _client.profile?.playerToken;
    final account = _client.creditAccount;
    if (header == null || profileToken == null || profileToken.isEmpty) return;
    if (!_client.connected) {
      header.markDisconnected(profileToken: profileToken);
      return;
    }
    if (!_client.supportsCredits || account == null) return;
    if (identical(account, _publishedCreditAccount) &&
        profileToken == _publishedCreditToken &&
        _client.creditPolicy.version == _publishedCreditPolicyVersion) {
      return;
    }
    _publishedCreditAccount = account;
    _publishedCreditToken = profileToken;
    _publishedCreditPolicyVersion = _client.creditPolicy.version;
    header.acceptServerAccount(
      profileToken: profileToken,
      account: account,
      policy: _client.creditPolicy,
    );
  }

  void _showCreditAddition(int amount) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context)..removeCurrentSnackBar();
      final nickname = PlayerIdentityScope.maybeOf(context)?.nickname;
      messenger.showSnackBar(
        SnackBar(
          key: const ValueKey('credit-reward-feedback'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF17613F),
          content: Row(
            children: [
              const Icon(Icons.celebration, color: Color(0xFFFFD166)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Congratulations${nickname == null ? '' : ', $nickname'}! +$amount credit${amount == 1 ? '' : 's'} added.',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showCreditDeduction(int amount) {
    final matching = _client.creditAccount?.recentTransactions
        .where((transaction) => transaction.delta == -amount)
        .firstOrNull;
    final activity = matching == null
        ? 'Online activity'
        : _creditTransactionLabel(matching.reason);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context)..removeCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          key: const ValueKey('credit-spend-feedback'),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const GoldCreditCoin(size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$amount credit${amount == 1 ? '' : 's'} used · $activity',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _setMobileNotifications(bool enabled) async {
    if (enabled) {
      final granted = await _notifications.requestPermission();
      if (!mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification permission was not granted.'),
          ),
        );
        return;
      }
    } else {
      await _notifications.cancelAll();
      _scheduledNotificationSignatures.clear();
      _deliveredNotificationEvents.clear();
    }
    if (!mounted) return;
    setState(() => _mobileNotificationsEnabled = enabled);
    await OnlineGameHistory.saveMobileNotificationsEnabled(enabled);
    if (enabled) await _processInvitationNotifications();
  }

  Future<void> _processInvitationNotifications() async {
    if (!_notificationPreferenceReady || !_mobileNotificationsEnabled) return;
    final myName = _client.profile?.name;
    if (myName == null) return;
    final now = DateTime.now();
    final currentScheduledInvites = <String>{};
    for (final invitation in _client.invitations) {
      final opponent = invitation.receivedBy(myName)
          ? invitation.senderName
          : invitation.recipientName;
      final incomingKey = 'invite:${invitation.inviteId}';
      if (invitation.receivedBy(myName) &&
          invitation.canRespondBy(myName) &&
          _deliveredNotificationEvents.add(incomingKey)) {
        await _notifications.show(
          id: incomingKey,
          title: 'Game invitation',
          body: '$opponent invited you to play Battle Chess Arena.',
        );
      }
      final scheduled = invitation.scheduledAt;
      final canStillPlay =
          !invitation.isExpired &&
          ['pending', 'accepted'].contains(invitation.status);
      if (scheduled != null && canStillPlay) {
        currentScheduledInvites.add(invitation.inviteId);
        final signature =
            '${scheduled.millisecondsSinceEpoch}:$opponent:${invitation.status}';
        if (_scheduledNotificationSignatures[invitation.inviteId] !=
            signature) {
          _scheduledNotificationSignatures[invitation.inviteId] = signature;
          await _notifications.cancel('scheduled-soon:${invitation.inviteId}');
          await _notifications.cancel('scheduled-start:${invitation.inviteId}');
          final soon = scheduled.subtract(const Duration(minutes: 10));
          if (soon.isAfter(now)) {
            await _notifications.schedule(
              id: 'scheduled-soon:${invitation.inviteId}',
              title: 'Game starting soon',
              body: 'Your scheduled game with $opponent starts in 10 minutes.',
              at: soon,
            );
          } else if (scheduled.isAfter(now) &&
              _deliveredNotificationEvents.add(
                'scheduled-soon:${invitation.inviteId}',
              )) {
            await _notifications.show(
              id: 'scheduled-soon:${invitation.inviteId}',
              title: 'Game starting soon',
              body: 'Your scheduled game with $opponent starts shortly.',
            );
          }
          if (scheduled.isAfter(now)) {
            await _notifications.schedule(
              id: 'scheduled-start:${invitation.inviteId}',
              title: 'Scheduled game time',
              body: 'Your game with $opponent is ready to start.',
              at: scheduled,
            );
          }
        }
      } else {
        _scheduledNotificationSignatures.remove(invitation.inviteId);
        await _notifications.cancel('scheduled-soon:${invitation.inviteId}');
        await _notifications.cancel('scheduled-start:${invitation.inviteId}');
      }
    }
    final removedInvites = _scheduledNotificationSignatures.keys
        .where((id) => !currentScheduledInvites.contains(id))
        .toList();
    for (final id in removedInvites) {
      _scheduledNotificationSignatures.remove(id);
      await _notifications.cancel('scheduled-soon:$id');
      await _notifications.cancel('scheduled-start:$id');
    }
  }

  void _tryJoinPendingInvite() {
    if (_pendingSharedInviteId != null &&
        _profileReady &&
        _client.connected &&
        !_client.busy &&
        _client.gameId == null) {
      final id = _pendingSharedInviteId!;
      _pendingSharedInviteId = null;
      _client.openSharedInvitation(id);
      return;
    }
    final pendingInvite = _pendingInviteGameId;
    if (pendingInvite == null ||
        !_profileReady ||
        !_client.connected ||
        _client.busy ||
        _client.gameId != null) {
      return;
    }
    _pendingInviteGameId = null;
    _client.joinGame(pendingInvite);
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

  void _requestConnectionPresence({bool force = false}) {
    if (!_client.connected || _favorites.isEmpty) return;
    final key = (_favorites.map((favorite) => favorite.name).toList()..sort())
        .join('|');
    if (!force && key == _presenceRequestKey) return;
    _presenceRequestKey = key;
    _client.loadPresence(_favorites.map((favorite) => favorite.name));
  }

  OnlineFavorite? _savedConnection(String name) => _favorites
      .where((item) => item.name.toLowerCase() == name.toLowerCase())
      .firstOrNull;

  Future<void> _saveConnection(
    String name,
    String avatarId,
    OnlinePlayerCircle circle,
  ) async {
    final favorites = await OnlineGameHistory.saveConnection(
      OnlineFavorite(name: name, avatarId: avatarId, circle: circle),
    );
    if (!mounted) return;
    setState(() => _favorites = favorites);
    _presenceRequestKey = null;
    _requestConnectionPresence();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$name added to ${circle.label}.')));
  }

  Future<void> _removeConnection(String name) async {
    final favorites = await OnlineGameHistory.removeConnection(name);
    if (!mounted) return;
    setState(() => _favorites = favorites);
    _presenceRequestKey = null;
    _requestConnectionPresence();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$name removed from your lists.')));
  }

  void _handlePlayerAction(String action, String name, String avatarId) {
    if (action == 'now') _inviteNow(name);
    if (action == 'schedule') _scheduleFor(name);
    if (action == 'remove') unawaited(_removeConnection(name));
    for (final circle in OnlinePlayerCircle.values) {
      if (action == 'circle:${circle.name}') {
        unawaited(_saveConnection(name, avatarId, circle));
      }
    }
  }

  List<PopupMenuEntry<String>> _playerActions(
    String name, {
    bool includeInvite = true,
  }) => [
    if (includeInvite) ...[
      const PopupMenuItem(value: 'now', child: Text('Invite now')),
      const PopupMenuItem(value: 'schedule', child: Text('Choose date & time')),
      const PopupMenuDivider(),
    ],
    for (final circle in OnlinePlayerCircle.values)
      PopupMenuItem(
        value: 'circle:${circle.name}',
        child: Text(
          _savedConnection(name)?.circle == circle
              ? 'In ${circle.label}'
              : 'Add to ${circle.label}',
        ),
      ),
    if (_savedConnection(name) != null) ...[
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'remove', child: Text('Remove from list')),
    ],
  ];

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
        content: Text(
          invitation.game == null &&
                  ['pending', 'accepted'].contains(invitation.status)
              ? 'This cancels the invitation for both players. It can no longer be accepted.'
              : 'This removes the invitation from your list. A game that has already started and its history will not be deleted.',
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
    final endpoint = _endpoint;
    if (endpoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Online play is unavailable in this build.'),
        ),
      );
      return;
    }
    final name = normalizedAvatarName(_avatarName.text);
    final validationError = avatarNameValidationError(name);
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }
    _client.setProfile(
      OnlinePlayerProfile(name: name, avatarId: _avatarId, level: _playerLevel),
    );
    setState(() => _profileReady = true);
    await _client.connect(endpoint);
  }

  Future<void> _playAnother() async {
    _openedGameId = null;
    await _client.startAnotherGame();
  }

  Future<void> _quickMatch() async {
    if (!_client.connected || _client.busy) return;
    if (_client.gameId != null) await _playAnother();
    if (!mounted || !_client.connected || _client.busy) return;
    _client.quickMatch(
      baseMs: _timeControl.baseMs,
      incrementMs: _timeControl.incrementMs,
      tossForColors: _tossForColors,
    );
  }

  Future<void> _prepareWhatsAppInvite() async {
    if (_preparingWhatsAppInvite || _client.profile == null) return;
    final format = _client.supportsSharedInvites
        ? await _pickInviteFormat()
        : null;
    if (!mounted || (_client.supportsSharedInvites && format == null)) return;
    setState(() => _preparingWhatsAppInvite = true);
    try {
      Uri? link;
      if (_client.supportsSharedInvites) {
        final invite = await _client.createSharedInvitation(
          baseMs: format!.baseMs,
          incrementMs: format.incrementMs,
          clockMode: format.clockMode,
          tossForColors: format.tossForColors,
        );
        link = sharedInviteUri(invite.inviteId, server: _client.endpoint);
      }
      if (mounted) await _shareWhatsAppInvite(inviteLink: link);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not prepare the invitation. Reconnect and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _preparingWhatsAppInvite = false);
    }
  }

  Future<void> _shareWhatsAppInvite({Uri? inviteLink}) async {
    final avatarName = _client.profile?.name ?? _avatarName.text.trim();
    final uri = whatsAppInviteUri(
      avatarName: avatarName,
      inviteLink: inviteLink,
    );
    var launched = false;
    try {
      launched =
          await (widget.launchExternal?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      // A missing external app can throw instead of returning false.
    }
    if (launched || !mounted) return;
    final message = gameInviteMessage(
      avatarName: avatarName,
      inviteLink: inviteLink,
    );
    await Clipboard.setData(ClipboardData(text: message));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp could not open. Invite copied instead.'),
        ),
      );
    }
  }

  Future<void> _deleteSharedInvitation(SharedInvitation invitation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete invitation link?'),
        content: const Text(
          'Anyone opening this link will see that the invitation was deleted. Games already started are kept.',
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
    if (confirmed == true && mounted) {
      _client.deleteSharedInvitation(invitation.inviteId);
    }
  }

  Future<void> _chooseComputerOpponent() async {
    final matchIdentity =
        '${_client.gameId}:${_client.state?.round}:${_client.seat}:${_client.state?.status}';
    final opponent = await showDialog<BuiltInComputerOpponent>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose a computer opponent'),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: builtInComputerOpponents.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final candidate = builtInComputerOpponents[index];
              return ListTile(
                key: ValueKey('computer-opponent-${candidate.id}'),
                leading: OnlineAvatarImage(
                  avatarId: candidate.avatarId,
                  size: 40,
                ),
                title: Text(candidate.name),
                subtitle: Text('${candidate.difficultyLabel} · Computer'),
                onTap: () => Navigator.pop(context, candidate),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (opponent == null ||
        !mounted ||
        matchIdentity !=
            '${_client.gameId}:${_client.state?.round}:${_client.seat}:${_client.state?.status}') {
      return;
    }
    if (!_client.connected || _client.busy) return;
    if (_client.gameId != null && !_client.searchingForOpponent) {
      await _playAnother();
    }
    if (!mounted || !_client.connected || _client.busy) return;
    _client.startComputerGame(
      opponent.id,
      baseMs: _timeControl.baseMs,
      incrementMs: _timeControl.incrementMs,
      tossForColors: _tossForColors,
    );
  }

  void _reconnect() {
    final endpoint = _endpoint;
    if (endpoint != null) unawaited(_client.connect(endpoint));
  }

  void _openGame() {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(name: '/online-game:${_client.gameId}'),
        builder: (_) => OnlineGameScreen(
          client: _client,
          pack: widget.pack,
          initialClassicPieces: widget.initialClassicPieces,
          initialAnimatedArena:
              widget.initialAnimatedArena ?? !widget.initialClassicPieces,
          initialClassicStyle: widget.initialClassicStyle,
        ),
      ),
    );
  }

  Future<void> _waitForInvitation(
    OnlineInvitation invitation, {
    String? sharedInviteId,
  }) async {
    if (_waitingInviteId != null || !mounted) return;
    _waitingInviteId = invitation.inviteId;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: RouteSettings(
          name: sharedInviteId == null
              ? '/waiting-invite:${invitation.inviteId}'
              : '/waiting-shared:$sharedInviteId',
        ),
        builder: (waitingContext) => InvitationWaitingScreen(
          client: _client,
          invitation: invitation,
          sharedInviteId: sharedInviteId,
          pack: widget.pack,
          onReady: (game) async {
            _openedGameId = game.gameId;
            await _client.openSavedGame(
              savedGameId: game.gameId,
              savedSeat: game.seat,
              savedSeatToken: game.seatToken,
            );
            if (!waitingContext.mounted) return;

            Navigator.of(waitingContext).pushReplacement<void, void>(
              MaterialPageRoute(
                settings: RouteSettings(name: '/online-game:${game.gameId}'),
                builder: (_) => OnlineGameScreen(
                  client: _client,
                  pack: widget.pack,
                  initialClassicPieces: true,
                  initialAnimatedArena: false,
                  initialClassicStyle: widget.initialClassicStyle,
                ),
              ),
            );
          },
        ),
      ),
    );
    _waitingInviteId = null;
  }

  Future<void> _waitForSharedInvitation(SharedInvitation shared) =>
      _waitForInvitation(
        OnlineInvitation(
          inviteId: shared.inviteId,
          senderName: shared.avatarName,
          senderAvatarId: _client.profile?.avatarId ?? 'crown',
          recipientName: 'your friend',
          recipientAvatarId: 'crown',
          status: shared.status,
          createdAt: DateTime.now(),
          awaitingResponseFromName: 'your friend',
          timed: true,
          baseMs: 600000,
          expiresAt: shared.expiresAt,
        ),
        sharedInviteId: shared.inviteId,
      );

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
      tossForColors: format.tossForColors,
      timed: format.timed,
      baseMs: format.baseMs,
      incrementMs: format.incrementMs,
      clockMode: format.clockMode,
    );
  }

  Future<void> _inviteNow(String opponentName) async {
    final format = await _pickInviteFormat();
    if (format == null) return;
    _pendingWaitOpponent = opponentName;
    _client.sendInvitation(
      opponentName,
      tossForColors: format.tossForColors,
      timed: format.timed,
      baseMs: format.baseMs,
      incrementMs: format.incrementMs,
      clockMode: format.clockMode,
    );
  }

  Future<void> _counterInvitation(OnlineInvitation invitation) async {
    final scheduled = await _pickDateTime(initial: invitation.scheduledAt);
    if (scheduled == null || !mounted) return;
    final format = await _pickInviteFormat(
      timed: invitation.timed,
      baseMs: invitation.baseMs,
      clockMode: invitation.clockMode,
      allowTossChange: false,
      tossForColors: invitation.tossForColors,
    );
    if (format == null) return;
    _client.proposeInvitationTime(
      invitation.inviteId,
      scheduled,
      timed: format.timed,
      baseMs: format.baseMs,
      incrementMs: format.incrementMs,
      clockMode: format.clockMode,
    );
  }

  Future<_InviteFormat?> _pickInviteFormat({
    bool timed = true,
    int baseMs = 86400000,
    String clockMode = 'daily',
    bool allowTossChange = true,
    bool tossForColors = false,
  }) {
    final requested = clockMode == 'daily'
        ? dailyTimeControl
        : closestOnlineTimeControl(baseMs);
    bool supported(OnlineTimeControl control) =>
        (!control.isDaily || _client.supportsDailyGames) &&
        (control.incrementMs == 0 || _client.supportsInviteClocks);
    var selected = supported(requested)
        ? requested
        : friendTimeControls.firstWhere(supported);
    return showDialog<_InviteFormat>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Game timer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Toss for colours'),
                subtitle: Text(
                  _client.supportsColorToss
                      ? 'A fair toss assigns White and Black. Rematches keep the same colours.'
                      : 'Available after the online service update.',
                ),
                value: tossForColors,
                onChanged: allowTossChange && _client.supportsColorToss
                    ? (value) => setDialogState(() => tossForColors = value)
                    : null,
              ),
              DropdownButtonFormField<OnlineTimeControl>(
                isExpanded: true,
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'Game format'),
                items: [
                  for (final control in friendTimeControls)
                    DropdownMenuItem(
                      value: control,
                      enabled: supported(control),
                      child: Text(control.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => selected = value);
                },
              ),
              const SizedBox(height: 12),
              Text(
                selected.isDaily
                    ? 'Each turn has a fresh 24 hours. You do not need to be online together. The clock continues while you are away.'
                    : 'A live game: both players should be online together.',
              ),
              const SizedBox(height: 8),
              const Text(
                'All games are free. Only Suggest Move uses credits.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              if (selected.isDaily && !_client.supportsDailyGames)
                const Text(
                  'Daily play needs the upcoming online service update. You can choose a live format now.',
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed:
                  (selected.isDaily && !_client.supportsDailyGames) ||
                      (selected.incrementMs > 0 &&
                          !_client.supportsInviteClocks)
                  ? null
                  : () => Navigator.pop(
                      context,
                      _InviteFormat(
                        true,
                        selected.baseMs,
                        tossForColors,
                        selected.incrementMs,
                        selected.clockMode,
                      ),
                    ),
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
    String? saveError;
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit online profile'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (saveError != null)
                    Text(
                      saveError!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  TextField(
                    controller: controller,
                    maxLength: 20,
                    decoration: const InputDecoration(labelText: 'Avatar ID'),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Choose or create your avatar'),
                  ),
                  const SizedBox(height: 8),
                  OnlineAvatarPicker(
                    selectedId: avatarId,
                    onSelected: (value) =>
                        setDialogState(() => avatarId = value),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<OnlinePlayerLevel>(
                    isExpanded: true,
                    initialValue: level,
                    decoration: const InputDecoration(
                      labelText: 'Player level',
                    ),
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
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = normalizedAvatarName(controller.text);
                      final validationError = avatarNameValidationError(name);
                      if (validationError != null) {
                        setDialogState(() => saveError = validationError);
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        saveError = null;
                      });
                      try {
                        await _client.updateProfileConfirmed(
                          name: name,
                          avatarId: avatarId,
                          level: level,
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (error) {
                        if (context.mounted) {
                          setDialogState(() {
                            saving = false;
                            saveError = error is StateError
                                ? error.message.toString()
                                : 'Could not save your profile. Try again.';
                          });
                        }
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Play Online'),
      actions: const [MusicButton()],
    ),
    bottomNavigationBar: !_loading && !_profileReady
        ? SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: FilledButton.icon(
                key: const ValueKey('enter-arena-button'),
                onPressed: _networkConfigured ? _createProfile : null,
                icon: const Icon(Icons.save_outlined),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Save & Enter Arena'),
                ),
              ),
            ),
          )
        : null,
    body: WorldBackdrop(
      pack: widget.pack,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_profileReady
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _networkBanner(),
                const SizedBox(height: 10),
                _profileForm(),
              ],
            )
          : RefreshIndicator(
              onRefresh: () async {
                _client.loadInvitations();
                _client.loadLeaderboard();
                _client.loadPointHistory();
                _client.loadActiveGames();
                _requestConnectionPresence(force: true);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _networkBanner(),
                  const SizedBox(height: 10),
                  _profileSummary(),
                  if (_client.supportsCredits) ...[
                    const SizedBox(height: 10),
                    _creditsCard(),
                  ],
                  if (_client.profileSavePending)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _client.connected
                            ? 'Saving your profile…'
                            : 'Your profile changes are waiting to save. Reconnect to finish.',
                      ),
                    ),
                  if (_client.avatarCompatibilityNotice case final notice?)
                    Card(
                      key: const ValueKey('custom-avatar-compatibility'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(notice),
                      ),
                    ),
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
                  const SizedBox(height: 10),
                  _mobileNotificationsCard(),
                  const SizedBox(height: 20),
                  _activeGamesSection(),
                  const SizedBox(height: 20),
                  _invitationsSection(),
                  const SizedBox(height: 20),
                  _rankingSection(),
                  const SizedBox(height: 20),
                  _computerOpponentsCard(),
                  const SizedBox(height: 20),
                  _connectionsCard(),
                ],
              ),
            ),
    ),
  );

  Widget _networkBanner() => Card(
    key: const ValueKey('online-network-banner'),
    child: ListTile(
      leading: Icon(Icons.cloud_outlined, color: widget.pack.accent),
      title: const Text('Online play'),
      subtitle: Text(
        _networkConfigured ? 'Ready to connect.' : 'Unavailable in this build.',
      ),
      trailing: _networkConfigured
          ? const Icon(Icons.check_circle, color: Colors.greenAccent)
          : const Icon(Icons.settings_outlined),
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
          const Text('Choose or create your avatar'),
          const SizedBox(height: 8),
          OnlineAvatarPicker(
            selectedId: _avatarId,
            onSelected: (value) => setState(() => _avatarId = value),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<OnlinePlayerLevel>(
            key: const ValueKey('player-level-selector'),
            isExpanded: true,
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
          const SizedBox(height: 8),
          const Text(
            'Save your Avatar ID and image using the button below.',
            style: TextStyle(fontSize: 12, color: Colors.white70),
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
            onPressed: _networkConfigured ? _reconnect : null,
            icon: const Icon(Icons.refresh),
          ),
      ],
    );
  }

  Widget _creditsCard() {
    final account = _client.creditAccount;
    final policy = _client.creditPolicy;
    final rewards = account == null
        ? null
        : '${account.completionRewardsToday}/${policy.dailyCompletionRewardCap} completion rewards today';
    return Card(
      key: const ValueKey('online-credits-card'),
      child: ListTile(
        key: const ValueKey('online-credits-balance'),
        leading: const CircleAvatar(
          backgroundColor: Color(0x332E1A00),
          child: GoldCreditCoin(size: 26),
        ),
        title: Text(
          account == null ? 'Syncing credits…' : '${account.credits} Credits',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          account == null
              ? 'Your server balance will appear here.'
              : 'Only Suggest Move uses credits.\n$rewards',
        ),
        isThreeLine: account != null,
        trailing: const Icon(Icons.info_outline),
        onTap: _showCreditsInfo,
      ),
    );
  }

  Future<void> _showCreditsInfo() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheetContext) => ListenableBuilder(
      listenable: _client,
      builder: (context, _) {
        final account = _client.creditAccount;
        final policy = _client.creditPolicy;
        return FractionallySizedBox(
          heightFactor: .86,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Credits',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close credits',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  key: const ValueKey('online-credits-explanation'),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: widget.pack.accent.withValues(alpha: .12),
                        border: Border.all(
                          color: widget.pack.accent.withValues(alpha: .35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const GoldCreditCoin(size: 42),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account == null
                                      ? 'Balance syncing…'
                                      : '${account.credits} credits',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  'New players begin with ${policy.starterCredits} welcome credits.',
                                ),
                                if (account != null)
                                  const Text(
                                    'One spendable balance, confirmed by the online service.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.tonalIcon(
                      key: const ValueKey('open-complete-credit-rules'),
                      onPressed: () => showCreditRulesSheet(context),
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text(
                        'View every credit cost, reward and fairness rule',
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'WHAT USES CREDITS',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    _CreditExplanationTile(
                      icon: Icons.lightbulb_rounded,
                      iconColor: moveSuggestionIconColor,
                      title: 'Online move suggestion',
                      subtitle:
                          'Not available against real online opponents for fair play',
                      trailing: '${policy.onlineMoveSuggestionCost}',
                    ),
                    const Text(
                      'All games, rematches, auto-play and retries are free. Credits are used only for Suggest Move.',
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'EARN CREDITS',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    _CreditExplanationTile(
                      icon: Icons.today_outlined,
                      title: 'Daily welcome-credit Top-up',
                      subtitle:
                          'Up to ${policy.dailyLoginCredits} daily, topping up welcome credits to ${policy.dailyAllowanceCap}',
                      trailing: 'up to +${policy.dailyLoginCredits}',
                    ),
                    _CreditExplanationTile(
                      icon: Icons.flag_outlined,
                      title: 'Complete a meaningful server match',
                      subtitle:
                          'After at least two legal half-moves · Up to ${policy.dailyCompletionRewardCap} rewards per day',
                      trailing: '+${policy.completionRewardCredits}',
                    ),
                    if (account != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${account.completionRewardsToday}/${policy.dailyCompletionRewardCap} completion rewards earned today',
                          style: TextStyle(
                            color: widget.pack.accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.all_inclusive),
                        title: const Text(
                          'The rest of the game stays free',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          'Local games, tournaments, conquests, chess sets, threat scans, browsing players, and notifications remain free. A successful move suggestion costs ${policy.onlineMoveSuggestionCost} credit${policy.onlineMoveSuggestionCost == 1 ? '' : 's'} in every game mode.',
                        ),
                      ),
                    ),
                    if (account != null &&
                        account.recentTransactions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'RECENT CREDIT ACTIVITY',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Card(
                        child: Column(
                          children: [
                            for (final transaction
                                in account.recentTransactions.take(5))
                              ListTile(
                                dense: true,
                                leading: Icon(
                                  transaction.delta >= 0
                                      ? Icons.add_circle_outline
                                      : Icons.remove_circle_outline,
                                  color: transaction.delta >= 0
                                      ? Colors.greenAccent
                                      : Colors.orangeAccent,
                                ),
                                title: Text(
                                  _creditTransactionLabel(transaction.reason),
                                ),
                                subtitle: Text(
                                  _formatSchedule(transaction.createdAt),
                                ),
                                trailing: Text(
                                  '${transaction.delta > 0 ? '+' : ''}${transaction.delta}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const Card(
                      key: ValueKey('credit-packs-coming-soon'),
                      child: ListTile(
                        leading: Icon(Icons.lock_outline),
                        title: Text(
                          'Credit packs · Coming later',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          'Purchases will use secure App Store or Google Play billing. No purchase is available in this build.',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

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
              OutlinedButton.icon(
                key: const ValueKey('choose-computer-while-waiting'),
                onPressed: _client.busy ? null : _chooseComputerOpponent,
                icon: const Icon(Icons.smart_toy_outlined),
                label: const Text('Play a computer instead'),
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
              _client.supportsCredits
                  ? 'Matches your ${_client.profile?.level.label ?? 'player'} level first. Games are free.'
                  : 'Matches your ${_client.profile?.level.label ?? 'player'} level first.',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<OnlineTimeControl>(
                    key: const ValueKey('online-time-control'),
                    isExpanded: true,
                    initialValue: _timeControl,
                    decoration: const InputDecoration(labelText: 'Game time'),
                    items: [
                      for (final control in onlineTimeControls)
                        DropdownMenuItem(
                          value: control,
                          child: Text(
                            control.label,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                      ? _quickMatch
                      : null,
                  icon: const Icon(Icons.bolt),
                  label: const Text('Play'),
                ),
              ],
            ),
            SwitchListTile(
              key: const ValueKey('online-colour-toss'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Toss for colours'),
              subtitle: Text(
                _client.supportsColorToss
                    ? 'Random colours for quick matches and computer opponents.'
                    : 'Available after the online service update.',
              ),
              value: _tossForColors,
              onChanged:
                  (_client.supportsColorToss || _tossForColors) && !_client.busy
                  ? (value) => setState(() => _tossForColors = value)
                  : null,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('invite-via-whatsapp'),
              onPressed: _client.profile != null && !_preparingWhatsAppInvite
                  ? _prepareWhatsAppInvite
                  : null,
              icon: _preparingWhatsAppInvite
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const WhatsAppInviteIcon(),
              label: Text(
                _preparingWhatsAppInvite
                    ? 'Preparing invitation…'
                    : 'Invite via WhatsApp',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _computerOpponentsCard() => Card(
    key: const ValueKey('computer-opponents-card'),
    child: ExpansionTile(
      leading: const Icon(Icons.smart_toy_outlined),
      title: const Text(
        'Computer Opponents',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: const Text(
        '20 built-in players across Beginner, Intermediate, and Advanced',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Choose one whenever no real player is available and start playing immediately.',
          ),
        ),
        if (_client.supportsCredits)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Computer games are free. Only Suggest Move uses credits.',
            ),
          ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          key: const ValueKey('choose-computer-opponent'),
          onPressed: _client.connected && !_client.busy
              ? _chooseComputerOpponent
              : null,
          icon: const Icon(Icons.people_alt_outlined),
          label: const Text('View all 20 players'),
        ),
      ],
    ),
  );

  Widget _findOpponentCard() => Card(
    child: ExpansionTile(
      key: const ValueKey('find-opponent-section'),
      leading: const Icon(Icons.person_search),
      title: const Text(
        'Find Opponent',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: const Text('Search by Avatar ID or browse available players'),
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
        OutlinedButton.icon(
          key: const ValueKey('view-available-players'),
          onPressed: _client.connected && !_client.availablePlayersLoading
              ? () => _client.loadAvailablePlayers()
              : null,
          icon: const Icon(Icons.people_outline),
          label: Text(
            _client.availablePlayersOpened
                ? 'Refresh connected players'
                : 'View all connected players',
          ),
        ),
        if (_client.connected && !_client.supportsAvailablePlayers)
          const Text(
            'Compatibility view: showing connected players from the current service directory.',
          ),
        if (_client.availablePlayersOpened) ...[
          const Text(
            'Connected real players not currently in a game. Availability can change.',
          ),
          for (final player in _client.availablePlayers)
            ListTile(
              key: ValueKey('available-player-${player.name}'),
              contentPadding: EdgeInsets.zero,
              leading: OnlineAvatarImage(avatarId: player.avatarId),
              title: Text(player.name),
              subtitle: Text('${player.level.label} · Online'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: _client.connected && !_client.busy
                        ? () => _inviteNow(player.name)
                        : null,
                    child: const Text('Invite'),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Save player to a list',
                    onSelected: (action) => _handlePlayerAction(
                      action,
                      player.name,
                      player.avatarId,
                    ),
                    itemBuilder: (_) =>
                        _playerActions(player.name, includeInvite: false),
                  ),
                ],
              ),
            ),
          if (_client.availablePlayersLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          if (_client.availablePlayersError case final message?) Text(message),
          if (!_client.availablePlayersLoading &&
              _client.availablePlayersError == null &&
              _client.availablePlayers.isEmpty)
            const Text(
              'No real players are available right now. Try refreshing shortly.',
            ),
          if (_client.hasMoreAvailablePlayers)
            TextButton.icon(
              key: const ValueKey('show-more-players'),
              onPressed: _client.availablePlayersLoading
                  ? null
                  : () => _client.loadAvailablePlayers(more: true),
              icon: const Icon(Icons.expand_more),
              label: const Text('Show 10 more'),
            ),
        ],
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
              onSelected: (action) =>
                  _handlePlayerAction(action, result.name, result.avatarId),
              itemBuilder: (_) => _playerActions(result.name),
            ),
          ),
      ],
    ),
  );

  IconData _circleIcon(OnlinePlayerCircle circle) => switch (circle) {
    OnlinePlayerCircle.family => Icons.home_outlined,
    OnlinePlayerCircle.friends => Icons.people_outline,
    OnlinePlayerCircle.professionals => Icons.workspace_premium_outlined,
  };

  Widget _connectionsCard() => Card(
    key: const ValueKey('player-connections-card'),
    child: ExpansionTile(
      key: const ValueKey('player-connections-section'),
      leading: const Icon(Icons.diversity_3_outlined),
      title: const Text(
        'Your Chess Circle',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        _favorites.isEmpty
            ? 'Family, Friends, and Professionals appear here'
            : '${_favorites.length} saved player${_favorites.length == 1 ? '' : 's'} · check status and invite',
      ),
      onExpansionChanged: (expanded) {
        if (expanded) _requestConnectionPresence(force: true);
      },
      childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 4, 6),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Save players from Find Opponent. These lists stay on this device.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              IconButton(
                key: const ValueKey('refresh-connections-presence'),
                tooltip: 'Refresh online status',
                onPressed: _client.connected && _favorites.isNotEmpty
                    ? () => _requestConnectionPresence(force: true)
                    : null,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        for (final circle in OnlinePlayerCircle.values)
          Builder(
            builder: (context) {
              final people = _favorites
                  .where((person) => person.circle == circle)
                  .toList();
              final onlineCount = people
                  .where((person) => _client.presence[person.name] == true)
                  .length;
              return Column(
                key: ValueKey('connections-${circle.name}'),
                children: [
                  ListTile(
                    dense: true,
                    leading: Icon(
                      _circleIcon(circle),
                      color: widget.pack.accent,
                    ),
                    title: Text(
                      circle.label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      people.isEmpty
                          ? 'No players added'
                          : '$onlineCount online · ${people.length} saved',
                    ),
                  ),
                  if (people.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Use a player’s menu to add them here.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                  else
                    for (final person in people) _connectionTile(person),
                ],
              );
            },
          ),
      ],
    ),
  );

  Widget _connectionTile(OnlineFavorite person) {
    final status = _client.presence[person.name];
    final statusLabel = !_client.connected
        ? 'Status unavailable'
        : status == null
        ? 'Checking status…'
        : status
        ? 'Online'
        : 'Offline';
    final statusColor = status == true ? Colors.greenAccent : Colors.white54;
    return ListTile(
      key: ValueKey('connection-${person.circle.name}-${person.name}'),
      contentPadding: const EdgeInsets.only(left: 16, right: 0),
      leading: OnlineAvatarImage(avatarId: person.avatarId),
      title: Text(person.name),
      subtitle: Row(
        children: [
          Icon(Icons.circle, size: 9, color: statusColor),
          const SizedBox(width: 5),
          Text(statusLabel),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Invite ${person.name}',
            onPressed: _client.connected && !_client.busy
                ? () => _inviteNow(person.name)
                : null,
            icon: const Icon(Icons.mail_outline),
          ),
          PopupMenuButton<String>(
            tooltip: 'Manage ${person.name}',
            onSelected: (action) =>
                _handlePlayerAction(action, person.name, person.avatarId),
            itemBuilder: (_) =>
                _playerActions(person.name, includeInvite: false),
          ),
        ],
      ),
    );
  }

  Widget _mobileNotificationsCard() => Card(
    key: const ValueKey('mobile-notifications-card'),
    child: SwitchListTile(
      key: const ValueKey('mobile-notifications-toggle'),
      secondary: const Icon(Icons.notifications_outlined),
      title: const Text(
        'Mobile notifications',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        _notifications.isSupported
            ? 'Notify me about invites, reminders, opponents joining, and moves in other games.'
            : 'Available in the Android and iOS apps.',
      ),
      value: _mobileNotificationsEnabled,
      onChanged: _notificationPreferenceReady && _notifications.isSupported
          ? _setMobileNotifications
          : null,
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
                Expanded(child: Text('Loading your open games…')),
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
              onPressed: () {
                _client.loadInvitations();
                _client.loadSharedInvitations();
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_client.invitations.isEmpty && _client.sharedInvitations.isEmpty)
          const Text('No invitations.'),
        for (final invitation in _client.sharedInvitations)
          Card(
            key: ValueKey('shared-invite-${invitation.inviteId}'),
            child: ListTile(
              onTap: !invitation.isExpired
                  ? () => _waitForSharedInvitation(invitation)
                  : null,
              leading: const WhatsAppInviteIcon(),
              title: const Text('WhatsApp invitation'),
              subtitle: Text(
                invitation.isExpired
                    ? 'Expired · Create a new invitation'
                    : invitation.status == 'accepted'
                    ? 'Friend joined · Tap to play'
                    : 'Waiting for a friend · ${invitation.avatarName}\n${invitation.expiresAt == null ? 'Expires after 24 hours' : 'Expires ${_formatSchedule(invitation.expiresAt!.toLocal())}'}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!invitation.isExpired)
                    IconButton(
                      tooltip: 'Wait at the chessboard',
                      onPressed: () => _waitForSharedInvitation(invitation),
                      icon: const Icon(Icons.hourglass_top),
                    ),
                  if (invitation.status == 'pending' && !invitation.isExpired)
                    IconButton(
                      tooltip: 'Share invitation again',
                      onPressed: () => _shareWhatsAppInvite(
                        inviteLink: sharedInviteUri(
                          invitation.inviteId,
                          server: _client.endpoint,
                        ),
                      ),
                      icon: const Icon(Icons.share),
                    ),
                  IconButton(
                    key: ValueKey(
                      'delete-shared-invite-${invitation.inviteId}',
                    ),
                    tooltip: 'Delete invitation link',
                    onPressed: _client.connected
                        ? () => _deleteSharedInvitation(invitation)
                        : null,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
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
    final canWait =
        !received &&
        !invitation.isExpired &&
        invitation.game == null &&
        ['pending', 'accepted'].contains(invitation.status);
    final schedule = invitation.scheduledAt == null
        ? 'Play now'
        : _formatSchedule(invitation.scheduledAt!);
    final timerFormat = invitation.clockMode == 'daily'
        ? 'Daily · 24 hours per move'
        : invitation.timed
        ? '${invitation.baseMs ~/ 60000}+${invitation.incrementMs ~/ 1000} live'
        : 'No timer';
    final gameFormat =
        '$timerFormat${invitation.tossForColors ? ' · Colour toss' : ''}';
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
        onTap: acceptedGame
            ? () => _openInvitation(invitation)
            : canWait
            ? () => _waitForInvitation(invitation)
            : null,
        leading: OnlineAvatarImage(avatarId: opponentAvatar),
        title: Text(opponentName),
        subtitle: Text(
          invitation.isExpired
              ? 'Expired · Ask for a new invitation'
              : '$status${invitation.game == null && invitation.expiresAt != null ? '\nExpires ${_formatSchedule(invitation.expiresAt!)}' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (acceptedGame) const Icon(Icons.play_arrow),
            if (canWait)
              IconButton(
                key: ValueKey('wait-at-board-${invitation.inviteId}'),
                tooltip: 'Wait at the chessboard',
                onPressed: () => _waitForInvitation(invitation),
                icon: const Icon(Icons.hourglass_top),
              ),
            if (canRespond)
              PopupMenuButton<String>(
                tooltip: 'Respond to invitation',
                onSelected: (action) {
                  if (action == 'accept') {
                    if (invitation.scheduledAt == null ||
                        !invitation.scheduledAt!.isAfter(DateTime.now())) {
                      _acceptedInviteId = invitation.inviteId;
                    }
                    _client.respondToInvitation(invitation.inviteId, true);
                  }
                  if (action == 'decline') {
                    _client.respondToInvitation(invitation.inviteId, false);
                  }
                  if (action == 'counter') _counterInvitation(invitation);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'accept', child: Text('Accept')),
                  const PopupMenuItem(
                    value: 'counter',
                    child: Text('Propose new date & time'),
                  ),
                  const PopupMenuItem(value: 'decline', child: Text('Decline')),
                ],
              )
            else if (!invitation.isExpired &&
                invitation.scheduledAt != null &&
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
    final rank = entry == null ? null : _client.leaderboard.indexOf(entry) + 1;
    final history = _client.pointHistory;
    final points =
        entry?.points ??
        history.fold<int>(0, (total, match) => total + match.points);
    final wins =
        entry?.wins ?? history.where((match) => match.result == 'win').length;
    final draws =
        entry?.draws ?? history.where((match) => match.result == 'draw').length;
    final losses =
        entry?.losses ??
        history.where((match) => match.result == 'loss').length;
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
              '$points points',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            Text('$wins wins · $draws draws · $losses losses'),
            const SizedBox(height: 6),
            Text(
              _leaderboardEncouragement(entry, rank),
              key: const ValueKey('leaderboard-encouragement'),
              style: TextStyle(
                color: entry == null ? Colors.white70 : Colors.amberAccent,
                fontWeight: FontWeight.w700,
              ),
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
      builder: (context) => ListenableBuilder(
        listenable: _client,
        builder: (context, _) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .76,
            child: Column(
              children: [
                ListTile(
                  title: const Text(
                    'Leaderboard',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(_leaderboardStatsLabel()),
                ),
                _leaderboardPerformanceBanner(),
                Expanded(child: _leaderboardResults()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _leaderboardResults() {
    if (_client.leaderboardLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_client.leaderboard.isEmpty) {
      return const Center(
        child: Text('Complete an online game to enter the leaderboard.'),
      );
    }
    final myName = _client.profile?.name.toLowerCase();
    final onlyCurrentPlayer =
        _client.leaderboard.length == 1 &&
        _client.leaderboard.single.name.toLowerCase() == myName;
    return ListView.builder(
      itemCount: _client.leaderboard.length + (onlyCurrentPlayer ? 1 : 0),
      itemBuilder: (_, index) {
        if (index == _client.leaderboard.length) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'No other ranked players are currently available. They will appear here after their online profiles are retained by the game server.',
              textAlign: TextAlign.center,
            ),
          );
        }
        final entry = _client.leaderboard[index];
        final rank = index + 1;
        final isMe = entry.name.toLowerCase() == myName;
        return ListTile(
          tileColor: isMe ? Colors.amber.withValues(alpha: .10) : null,
          leading: OnlineAvatarImage(avatarId: entry.avatarId),
          title: Text('$rank. ${entry.name}${isMe ? ' · You' : ''}'),
          subtitle: Text(
            '${entry.level.label} · ${entry.wins}W  ${entry.draws}D  ${entry.losses}L',
          ),
          trailing: Text(
            '${entry.points} pts',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        );
      },
    );
  }

  Widget _leaderboardPerformanceBanner() {
    final myName = _client.profile?.name.toLowerCase() ?? '';
    final entries = _client.leaderboard;
    final index = entries.indexWhere(
      (entry) => entry.name.toLowerCase() == myName,
    );
    final entry = index < 0 ? null : entries[index];
    final rank = index < 0 ? null : index + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withValues(alpha: .32)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.amber),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _leaderboardEncouragement(entry, rank),
                  key: const ValueKey('leaderboard-performance-message'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _leaderboardEncouragement(OnlineLeaderboardEntry? entry, int? rank) {
    if (entry == null || rank == null) {
      if (_client.pointHistory.isNotEmpty) {
        return 'You are outside the displayed top 50 right now—your next strong result can bring you back.';
      }
      return 'Play a completed online game to earn your first ranking.';
    }
    if (_client.leaderboard.length == 1) {
      return 'You are currently the only ranked player. Complete more online games while other players join the rankings.';
    }
    final movement = _leaderboardMovement;
    final standing = rank == 1
        ? 'Congratulations—you are the topper!'
        : rank <= 10
        ? 'Excellent—you are in the top $rank!'
        : 'You are currently ranked #$rank.';
    if (movement > 0) {
      return '$standing You moved up $movement place${movement == 1 ? '' : 's'}—keep climbing!';
    }
    if (movement < 0) {
      return '$standing A small drop is only a comeback opportunity—your next win can lift you again.';
    }
    if (_leaderboardSnapshot != null && _observedLeaderboardRank != null) {
      return '$standing Keep the momentum going!';
    }
    return '$standing Keep playing to climb higher.';
  }

  String _leaderboardStatsLabel() {
    final myName = _client.profile?.name.toLowerCase() ?? '';
    final index = _client.leaderboard.indexWhere(
      (entry) => entry.name.toLowerCase() == myName,
    );
    final entry = index < 0 ? null : _client.leaderboard[index];
    final history = _client.pointHistory;
    final wins =
        entry?.wins ?? history.where((match) => match.result == 'win').length;
    final draws =
        entry?.draws ?? history.where((match) => match.result == 'draw').length;
    final losses =
        entry?.losses ??
        history.where((match) => match.result == 'loss').length;
    final completed = wins + draws + losses;
    return '$completed completed online ${completed == 1 ? 'game' : 'games'} · ${wins}W · ${draws}D · ${losses}L';
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

  String _creditTransactionLabel(String reason) => switch (reason) {
    'starter_credits' => 'Welcome credits',
    'daily_login' => 'Daily welcome-credit Top-up',
    'meaningful_round_completed' => 'Meaningful match completed',
    'live_human_round' => 'Live player round',
    'daily_human_round' => 'Daily player round',
    'server_computer_round' => 'Server computer round',
    'online_move_suggestion' => 'Online move suggestion',
    'verified_purchase' => 'Verified store purchase',
    'low_balance_recovery' => 'Low-balance safety grant',
    _ =>
      reason
          .split('_')
          .where((word) => word.isNotEmpty)
          .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
          .join(' '),
  };
}

class WhatsAppInviteIcon extends StatelessWidget {
  const WhatsAppInviteIcon({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 22,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.chat_bubble, color: Color(0xFF25D366), size: 22),
        Icon(Icons.phone, color: Colors.white, size: 12),
      ],
    ),
  );
}

class _CreditExplanationTile extends StatelessWidget {
  const _CreditExplanationTile({
    required this.icon,
    required this.title,
    required this.trailing,
    this.subtitle,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final String trailing;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: iconColor),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: Chip(
      avatar: const GoldCreditCoin(size: 18),
      label: Text(
        trailing,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
  );
}

class _InviteFormat {
  const _InviteFormat(
    this.timed,
    this.baseMs,
    this.tossForColors,
    this.incrementMs,
    this.clockMode,
  );
  final bool tossForColors;
  final bool timed;
  final int baseMs;
  final int incrementMs;
  final String clockMode;
}
