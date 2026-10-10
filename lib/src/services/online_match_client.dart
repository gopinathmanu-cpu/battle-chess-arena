// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/online_game_session.dart';
import '../domain/custom_avatar.dart';
import '../domain/online_credits.dart';
import '../domain/online_game_state.dart';
import '../domain/online_player_profile.dart';
import '../domain/online_social.dart';
import '../features/play/board_appearance.dart';
import 'online_game_archive.dart';
export '../domain/online_game_state.dart';

enum MatchConnection { disconnected, connecting, resuming, ready }

const onlineProtocolVersion = 4;

class OnlineMatchClient extends ChangeNotifier {
  OnlineMatchClient({
    WebSocketChannel Function(Uri)? channelFactory,
    OnlinePlayerProfile? profile,
    OnlineGameArchive? gameArchive,
    this.retryDelay = const Duration(seconds: 2),
    this.heartbeatInterval = const Duration(seconds: 5),
    this.connectionTimeout = const Duration(seconds: 8),
  }) : _channelFactory = channelFactory ?? WebSocketChannel.connect,
       _profile = profile,
       gameArchive = gameArchive ?? OnlineGameArchive(),
       _ownsArchive = gameArchive == null {
    this.gameArchive.addListener(_notify);
  }

  final WebSocketChannel Function(Uri) _channelFactory;
  final Duration retryDelay;
  final Duration heartbeatInterval;
  final Duration connectionTimeout;
  final OnlineGameArchive gameArchive;
  final bool _ownsArchive;
  String? get historySaveError => gameArchive.error;
  Future<void> retryHistorySave() => gameArchive.retryFailed();

  Future<void> rememberGameAppearance(BoardAppearance appearance) {
    final current = state;
    final currentSeat = seat;
    if (current == null || currentSeat == null) return Future.value();
    return gameArchive.rememberAppearance(
      gameId: current.gameId,
      round: current.round,
      seat: currentSeat,
      appearance: appearance,
    );
  }

  final session = OnlineGameSession();
  final _elapsed = Stopwatch()..start();
  final _idPrefix = List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  int _commandCounter = 0;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry;
  Timer? _heartbeat;
  Uri? _endpoint;
  String? _seatToken;
  Map<String, dynamic>? _pending;
  String? _setupCommandId;
  String? _profileCommandId;
  String? _profileUpdateCommandId;
  String? _registrationAvatarOverride;
  String? _updateAvatarOverride;
  OnlinePlayerProfile? _pendingProfileEdit;
  int _generation = 0;
  int _lastFrameAt = 0;
  bool _disposed = false;
  bool _stopped = false;
  bool _syncing = false;
  bool _matchmaking = false;
  OnlinePlayerProfile? _profile;
  List<OnlineLeaderboardEntry> leaderboard = const [];
  bool leaderboardLoading = false;
  List<OnlinePointRecord> pointHistory = const [];
  List<OnlineInvitation> invitations = const [];
  List<SharedInvitation> sharedInvitations = const [];
  Completer<SharedInvitation>? _sharedInviteRequest;
  String? _sharedInviteCommandId;
  List<OnlineInviteGame> activeGames = const [];
  bool activeGamesLoaded = false;
  Map<String, bool> presence = const {};
  OnlinePlayerSearchResult? playerSearchResult;
  bool playerSearchCompleted = false;
  bool supportsAvailablePlayers = false;
  bool supportsGamePush = false;
  Map<String, dynamic>? _pushDevice;
  List<OnlinePlayerSearchResult> availablePlayers = [];
  bool availablePlayersLoading = false;
  bool availablePlayersOpened = false;
  String? availablePlayersError;
  String? _playersCursor;
  String? _playersRequest;
  bool _legacyPlayersRequest = false;
  Set<String> _legacyPresenceNames = const {};
  List<OnlinePlayerSearchResult> _legacyAvailablePlayers = const [];
  int _legacyVisiblePlayers = 10;
  int _playersSequence = 0;
  Timer? _playersTimeout;
  bool get hasMoreAvailablePlayers =>
      _playersCursor != null ||
      (_legacyPlayersRequest &&
          availablePlayers.length < _legacyAvailablePlayers.length);

  void _clearAvailablePlayers() {
    _playersTimeout?.cancel();
    _playersRequest = null;
    _legacyPlayersRequest = false;
    _legacyPresenceNames = const {};
    _legacyAvailablePlayers = const [];
    _legacyVisiblePlayers = 10;
    availablePlayersLoading = false;
    availablePlayersOpened = false;
    availablePlayers = [];
    _playersCursor = null;
    availablePlayersError = null;
    supportsAvailablePlayers = false;
  }

  void loadAvailablePlayers({bool more = false}) {
    if (!connected || availablePlayersLoading) {
      return;
    }
    if (!supportsAvailablePlayers) {
      if (more && _legacyAvailablePlayers.isNotEmpty) {
        _legacyVisiblePlayers += 10;
        availablePlayers = List.unmodifiable(
          _legacyAvailablePlayers.take(_legacyVisiblePlayers),
        );
        _notify();
        return;
      }
      _legacyPlayersRequest = true;
      _legacyVisiblePlayers = 10;
      availablePlayersOpened = true;
      availablePlayersLoading = true;
      availablePlayersError = null;
      _send(const {'type': 'leaderboard'});
      _startPlayersTimeout('legacy-players');
      _notify();
      return;
    }
    if (more && _playersCursor == null) return;
    if (!more) {
      availablePlayers = [];
      _playersCursor = null;
    }
    availablePlayersOpened = true;
    availablePlayersLoading = true;
    availablePlayersError = null;
    final request = 'players-${++_playersSequence}';
    _playersRequest = request;
    _send({
      'type': 'list_available_players',
      'requestId': request,
      if (more) 'after': _playersCursor,
    });
    _startPlayersTimeout(request);
    _notify();
  }

  void _startPlayersTimeout(String request) {
    _playersTimeout?.cancel();
    _playersTimeout = Timer(const Duration(seconds: 10), () {
      if (request == 'legacy-players') {
        if (!_legacyPlayersRequest || !availablePlayersLoading) return;
        _legacyPlayersRequest = false;
      } else if (_playersRequest != request) {
        return;
      }
      _playersRequest = null;
      availablePlayersLoading = false;
      availablePlayersError = 'Could not load players. Please try again.';
      _notify();
    });
  }

  MatchConnection connection = MatchConnection.disconnected;
  String? gameId;
  String? seat;
  String? error;
  OnlinePlayerProfile? get profile => _profile;
  String? get seatToken => _seatToken;
  bool get connected => connection == MatchConnection.ready && !_syncing;
  bool supportsColorToss = false;
  bool supportsSharedInvites = false;
  bool supportsInviteClocks = false;
  bool supportsDailyGames = false;
  bool supportsCredits = false;
  OnlineCreditPolicy creditPolicy = defaultOnlineCreditPolicy;
  OnlineCreditAccount? creditAccount;
  int? get credits => creditAccount?.credits;

  bool _checkInviteClock(String mode, int incrementMs) {
    if ((mode == 'daily' && !supportsDailyGames) ||
        ((mode != 'live' || incrementMs != 0) && !supportsInviteClocks)) {
      error = mode == 'daily'
          ? 'Daily games are not available yet. Choose a live game or try again after the service update.'
          : 'This game clock needs an online service update.';
      _notify();
      return false;
    }
    return true;
  }

  bool supportsCustomAvatars = false;
  bool get profileSavePending => _pendingProfileEdit != null;
  String? get avatarCompatibilityNotice =>
      connected &&
          !supportsCustomAvatars &&
          CustomAvatarDesign.tryParse(_profile?.avatarId ?? '') != null
      ? 'Your custom avatar is saved on this device. Other players will see a preset portrait until the online service is updated.'
      : null;
  Uri? get endpoint => _endpoint;

  Future<SharedInvitation> createSharedInvitation({
    int baseMs = 86400000,
    int incrementMs = 0,
    String clockMode = 'daily',
    bool tossForColors = false,
  }) async {
    if (!_checkInviteClock(clockMode, incrementMs)) throw StateError(error!);
    if (!connected || !supportsSharedInvites || _sharedInviteRequest != null) {
      throw StateError(
        'Direct invitations are unavailable. Please reconnect after the online service update.',
      );
    }
    final request = Completer<SharedInvitation>();
    _sharedInviteRequest = request;
    _sharedInviteCommandId = _newId();
    _send({
      'type': 'create_shared_invite',
      if (supportsInviteClocks) 'clockMode': clockMode,
      if (supportsInviteClocks) 'incrementMs': incrementMs,
      'commandId': _sharedInviteCommandId,
      'baseMs': baseMs,
      if (tossForColors) 'tossForColors': true,
    });
    try {
      return await request.future.timeout(connectionTimeout);
    } finally {
      if (identical(_sharedInviteRequest, request)) {
        _sharedInviteRequest = null;
        _sharedInviteCommandId = null;
      }
    }
  }

  void loadSharedInvitations() {
    if (connected && supportsSharedInvites) {
      _send({'type': 'list_shared_invites'});
    }
  }

  void _cancelSharedInviteRequest() {
    if (_sharedInviteRequest?.isCompleted == false) {
      _sharedInviteRequest!.completeError(
        StateError('Connection interrupted. Please try again.'),
      );
    }
  }

  void deleteSharedInvitation(String inviteId) {
    if (!connected || !supportsSharedInvites) return;
    _send({
      'type': 'delete_shared_invite',
      'commandId': _newId(),
      'inviteId': inviteId,
    });
  }

  void openSharedInvitation(String inviteId) {
    if (!connected || busy) return;
    if (!supportsSharedInvites) {
      error =
          'Direct invitations are unavailable. Ask your friend for their Avatar name and search in Play Online.';
      _notify();
      return;
    }
    _setupCommandId = _newId();
    _send({
      'type': 'open_shared_invite',
      'commandId': _setupCommandId,
      'inviteId': inviteId,
    });
    _notify();
  }

  bool _checkToss(bool requested) {
    if (!requested || supportsColorToss) return true;
    error =
        'Colour toss is not available yet. Try again after the online service is updated.';
    _notify();
    return false;
  }

  bool get busy =>
      _pending != null ||
      _setupCommandId != null ||
      profileSavePending ||
      _profileUpdateCommandId != null;
  bool get searchingForOpponent =>
      _matchmaking && state?.status == 'waiting' && gameId != null;
  bool get canAct => connected && !busy && gameId != null && seat != null;
  OnlineGameState? get state => session.state;
  String get connectionLabel => switch (connection) {
    MatchConnection.ready => _syncing ? 'Synchronizing game…' : 'Connected',
    MatchConnection.connecting =>
      gameId == null ? 'Connecting…' : 'Connection lost · reconnecting…',
    MatchConnection.resuming => 'Reconnecting · restoring your seat…',
    MatchConnection.disconnected =>
      gameId == null ? 'Disconnected' : 'Connection lost · retrying…',
  };

  String _newId() => '${_idPrefix}_${++_commandCounter}';

  void setProfile(OnlinePlayerProfile profile) {
    _profile = profile;
    error = null;
    _notify();
  }

  bool updateProfile({
    required String name,
    required String avatarId,
    required OnlinePlayerLevel level,
  }) {
    if (_profile == null || profileSavePending) return false;
    error = null;
    _pendingProfileEdit = OnlinePlayerProfile(
      name: name,
      avatarId: avatarId,
      level: level,
      playerToken: _profile!.playerToken,
    );
    _sendPendingProfileEdit();
    _notify();
    return true;
  }

  /// Completes only after the server has accepted the unique public name.
  Future<OnlinePlayerProfile> updateProfileConfirmed({
    required String name,
    required String avatarId,
    required OnlinePlayerLevel level,
  }) async {
    if (!connected) {
      throw StateError('Connect to save and verify your Avatar Name.');
    }
    if (!updateProfile(name: name, avatarId: avatarId, level: level)) {
      throw StateError(
        'Another profile change is still saving. Please try again shortly.',
      );
    }
    final result = Completer<OnlinePlayerProfile>();
    void check() {
      if (profileSavePending) return;
      if (error != null) {
        if (!result.isCompleted) result.completeError(StateError(error!));
      } else if (!result.isCompleted) {
        result.complete(_profile!);
      }
    }

    addListener(check);
    check();
    try {
      return await result.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw StateError(
          'Could not verify your Avatar Name. Reconnect and try again.',
        ),
      );
    } finally {
      removeListener(check);
    }
  }

  void _sendPendingProfileEdit() {
    final edit = _pendingProfileEdit;
    if (edit == null ||
        !connected ||
        _profileUpdateCommandId != null ||
        _pending != null ||
        _setupCommandId != null) {
      return;
    }
    _updateAvatarOverride = _legacyAvatarOverride(edit.avatarId);
    _profileUpdateCommandId = _newId();
    _send({
      'type': 'update_player',
      'commandId': _profileUpdateCommandId,
      'name': edit.name,
      'avatarId': _updateAvatarOverride == null ? edit.avatarId : 'avatar-01',
      'level': edit.level.name,
    });
  }

  // Keep the user's design locally without sending unsupported IDs to older
  // services. A later connection to a capable service publishes the design.
  String? _legacyAvatarOverride(String avatarId) =>
      !supportsCustomAvatars && CustomAvatarDesign.tryParse(avatarId) != null
      ? avatarId
      : null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> connect(Uri endpoint) async {
    _clearAvailablePlayers();
    if (_disposed) return;
    if (!['ws', 'wss'].contains(endpoint.scheme) || endpoint.host.isEmpty) {
      error = 'Online play is not configured correctly';
      _notify();
      return;
    }
    if (gameId != null && _endpoint != null && endpoint != _endpoint) {
      error = 'Leave this room before starting another connection';
      _notify();
      return;
    }
    _endpoint = endpoint;
    supportsColorToss = false;
    supportsSharedInvites = false;
    supportsInviteClocks = false;
    supportsDailyGames = false;
    supportsCustomAvatars = false;
    supportsCredits = false;
    leaderboardLoading = false;
    creditPolicy = defaultOnlineCreditPolicy;
    creditAccount = null;
    _registrationAvatarOverride = null;
    _updateAvatarOverride = null;
    _profileUpdateCommandId = null;
    _stopped = false;
    final generation = ++_generation;
    await _closeTransport();
    if (_disposed || generation != _generation) return;
    connection = MatchConnection.connecting;
    _syncing = true;
    error = null;
    _notify();
    WebSocketChannel? channel;
    try {
      channel = _channelFactory(endpoint);
      _channel = channel;
      await channel.ready.timeout(connectionTimeout);
      if (_disposed || generation != _generation) {
        unawaited(channel.sink.close());
        return;
      }
      _lastFrameAt = _elapsed.elapsedMilliseconds;
      connection = _profile == null && _seatToken == null
          ? MatchConnection.ready
          : _profile == null
          ? MatchConnection.resuming
          : MatchConnection.connecting;
      _syncing = _profile != null || _seatToken != null;
      _subscription = channel.stream.listen(
        (raw) {
          if (generation == _generation && !_disposed) _handleFrame(raw);
        },
        onError: (_) => _lost(generation),
        onDone: () => _lost(generation),
      );
      if (_profile == null && gameId != null && _seatToken != null) {
        _send({
          'type': 'resume_game',
          'gameId': gameId,
          'seatToken': _seatToken,
        });
      }
      _heartbeat = Timer.periodic(heartbeatInterval, (_) {
        if (_elapsed.elapsedMilliseconds - _lastFrameAt >
            heartbeatInterval.inMilliseconds * 3) {
          _lost(generation);
          return;
        }
        _send(const {'type': 'ping'});
        if (gameId != null && connection == MatchConnection.ready) {
          sync(blockInput: false);
          if (_pending != null) _send(_pending!);
        }
      });
      _notify();
    } catch (_) {
      // Attach a listener to consume a failed channel's stream error as well.
      if (_subscription == null && channel != null) {
        _subscription = channel.stream.listen((_) {}, onError: (_) {});
      }
      _lost(generation);
    }
  }

  void _lost(int generation) {
    if (_disposed || _stopped || generation != _generation) return;
    _clearAvailablePlayers();
    _cancelSharedInviteRequest();
    ++_generation; // Invalidates callbacks from the old socket immediately.
    connection = MatchConnection.disconnected;
    _syncing = true;
    if (_setupCommandId != null) {
      _setupCommandId = null;
      error =
          'Room connection interrupted. Reconnect and create or join again.';
    } else {
      error = 'Connection lost. Your game clock continues while reconnecting.';
    }
    unawaited(_closeTransport());
    _retry = Timer(retryDelay, () {
      if (!_disposed && !_stopped && _endpoint != null) connect(_endpoint!);
    });
    _notify();
  }

  Future<void> reconnect() async {
    if (_endpoint != null) await connect(_endpoint!);
  }

  void createGame({
    int baseMs = 900000,
    int incrementMs = 10000,
    bool tossForColors = false,
  }) {
    if (!connected || busy || gameId != null) return;
    if (!_checkToss(tossForColors)) return;
    _setupCommandId = _newId();
    _send({
      'type': 'create_game',
      if (tossForColors) 'tossForColors': true,
      'commandId': _setupCommandId,
      'baseMs': baseMs,
      'incrementMs': incrementMs,
    });
    _notify();
  }

  void quickMatch({
    int baseMs = 900000,
    int incrementMs = 10000,
    bool tossForColors = false,
  }) {
    if (!connected || busy || gameId != null) return;
    if (!_checkToss(tossForColors)) return;
    _matchmaking = true;
    _setupCommandId = _newId();
    _send({
      'type': 'quick_match',
      if (tossForColors) 'tossForColors': true,
      'commandId': _setupCommandId,
      'baseMs': baseMs,
      'incrementMs': incrementMs,
    });
    _notify();
  }

  void startComputerGame(
    String opponentId, {
    int baseMs = 900000,
    int incrementMs = 10000,
    bool tossForColors = false,
  }) {
    if (!connected || busy || (gameId != null && !searchingForOpponent)) return;
    if (!_checkToss(tossForColors)) return;
    _setupCommandId = _newId();
    _send({
      'type': 'start_computer_game',
      if (tossForColors) 'tossForColors': true,
      'commandId': _setupCommandId,
      'opponentId': opponentId,
      'baseMs': baseMs,
      'incrementMs': incrementMs,
    });
    _notify();
  }

  void cancelMatchmaking() {
    if (!connected || busy || !searchingForOpponent) return;
    _setupCommandId = _newId();
    _send({
      'type': 'cancel_matchmaking',
      'commandId': _setupCommandId,
      'gameId': gameId,
    });
    _notify();
  }

  void joinGame(String id) {
    if (!connected || busy || gameId != null || id.trim().isEmpty) return;
    _setupCommandId = _newId();
    _send({
      'type': 'join_game',
      'commandId': _setupCommandId,
      'gameId': id.trim(),
    });
    _notify();
  }

  void requestMove({
    required Square from,
    required Square to,
    Role promotion = Role.queen,
  }) {
    if (!canAct) return;
    final move = session.moveRequest(from, to, seat, promotion: promotion);
    if (move == null) return;
    _action('move', {'ply': state!.san.length, 'move': move});
  }

  void resign() => _action('resign');
  void offerDraw() => _action('offer_draw');
  void respondDraw(bool accept) {
    if (state?.drawOfferId == null) return;
    _action('respond_draw', {'offerId': state!.drawOfferId, 'accept': accept});
  }

  void requestRematch() => _action('rematch');

  void useLifeline() => _action('use_lifeline');

  void loadLeaderboard() {
    if (!connected) return;
    leaderboardLoading = true;
    _send(const {'type': 'leaderboard'});
    _notify();
  }

  void loadPointHistory() {
    if (connected) _send(const {'type': 'points_history'});
  }

  void findPlayer(String avatarId) {
    if (!connected) return;
    playerSearchResult = null;
    playerSearchCompleted = false;
    _send({'type': 'find_player', 'query': avatarId.trim()});
    _notify();
  }

  void loadInvitations() {
    if (connected) _send(const {'type': 'list_invites'});
  }

  void deleteInvitation(String inviteId) {
    if (!connected) return;
    invitations = List.unmodifiable(
      invitations.where((item) => item.inviteId != inviteId),
    );
    _send({
      'type': 'delete_invite',
      'commandId': _newId(),
      'inviteId': inviteId,
    });
    _notify();
  }

  void loadActiveGames() {
    if (!connected) return;
    activeGames = const [];
    activeGamesLoaded = false;
    _send(const {'type': 'list_games'});
    _notify();
  }

  void loadPresence(Iterable<String> names) {
    if (connected) _send({'type': 'presence', 'names': names.toList()});
  }

  void setPushDevice({
    required String deviceId,
    required String token,
    required bool enabled,
    required bool active,
  }) {
    _pushDevice = {
      'type': 'set_push_device',
      'deviceId': deviceId,
      'token': token,
      'enabled': enabled,
      'active': active,
    };
    if (connected && supportsGamePush) _send(_pushDevice!);
  }

  void sendInvitation(
    String opponentName, {
    DateTime? scheduledAt,
    bool timed = true,
    int baseMs = 86400000,
    int incrementMs = 0,
    String clockMode = 'daily',
    bool tossForColors = false,
  }) {
    if (!connected) return;
    if (!_checkToss(tossForColors)) return;
    if (!_checkInviteClock(clockMode, incrementMs)) return;
    _send({
      'type': 'send_invite',
      if (supportsInviteClocks) 'clockMode': clockMode,
      if (supportsInviteClocks) 'incrementMs': incrementMs,
      if (tossForColors) 'tossForColors': true,
      'commandId': _newId(),
      'opponentName': opponentName,
      if (scheduledAt != null)
        'scheduledAt': scheduledAt.millisecondsSinceEpoch,
      'timed': timed,
      'baseMs': baseMs,
    });
  }

  void respondToInvitation(String inviteId, bool accept) {
    if (!connected) return;
    _send({
      'type': 'respond_invite',
      'commandId': _newId(),
      'inviteId': inviteId,
      'accept': accept,
    });
  }

  void proposeInvitationTime(
    String inviteId,
    DateTime scheduledAt, {
    bool timed = true,
    int baseMs = 86400000,
    int incrementMs = 0,
    String clockMode = 'daily',
  }) {
    if (!connected) return;
    if (!_checkInviteClock(clockMode, incrementMs)) return;
    _send({
      'type': 'propose_invite_time',
      if (supportsInviteClocks) 'clockMode': clockMode,
      if (supportsInviteClocks) 'incrementMs': incrementMs,
      'commandId': _newId(),
      'inviteId': inviteId,
      'scheduledAt': scheduledAt.millisecondsSinceEpoch,
      'timed': timed,
      'baseMs': baseMs,
    });
  }

  void _action(String type, [Map<String, dynamic> extra = const {}]) {
    if (!canAct || state == null) return;
    _pending = {
      'type': type,
      'gameId': gameId,
      'commandId': _newId(),
      'round': state!.round,
      ...extra,
    };
    error = null;
    _send(_pending!);
    _notify();
  }

  void sync({bool blockInput = true}) {
    if (gameId == null || _channel == null) return;
    if (blockInput) _syncing = true;
    _send({'type': 'sync', 'gameId': gameId});
    if (blockInput) _notify();
  }

  void _handleFrame(dynamic raw) {
    try {
      final frame = jsonDecode(raw as String) as Map<String, dynamic>;
      _lastFrameAt = _elapsed.elapsedMilliseconds;
      final type = frame['type'];
      if (type != 'connected' && supportsCredits) {
        _applyCreditEnvelope(frame);
      }
      if (type == 'pong') {
        // The frame timestamp above is the heartbeat acknowledgement.
      } else if (type == 'connected') {
        supportsGamePush =
            (frame['capabilities'] as List?)?.contains('game_push') ?? false;
        supportsInviteClocks =
            (frame['capabilities'] as List?)?.contains('invite_clocks') ??
            false;
        supportsDailyGames =
            (frame['capabilities'] as List?)?.contains('daily_games') ?? false;
        supportsCustomAvatars =
            (frame['capabilities'] as List?)?.contains('custom_avatars') ??
            false;
        supportsSharedInvites =
            (frame['capabilities'] as List?)?.contains('shared_invites') ??
            false;
        supportsAvailablePlayers =
            (frame['capabilities'] as List?)?.contains('available_players') ??
            false;
        supportsColorToss =
            (frame['capabilities'] as List?)?.contains('color_toss') ?? false;
        supportsCredits =
            (frame['capabilities'] as List?)?.contains('credits') ?? false;
        if (frame['protocolVersion'] != onlineProtocolVersion) {
          error =
              'Online play needs an app update. Install the latest version.';
          unawaited(disconnect());
        } else if (_profile != null) {
          _registrationAvatarOverride = _legacyAvatarOverride(
            _profile!.avatarId,
          );
          _profileCommandId = _newId();
          _send({
            'type': 'register_player',
            'commandId': _profileCommandId,
            'name': _profile!.name,
            'avatarId': _registrationAvatarOverride == null
                ? _profile!.avatarId
                : 'avatar-01',
            'level': _profile!.level.name,
            if (_profile!.playerToken != null)
              'playerToken': _profile!.playerToken,
          });
        } else {
          connection = MatchConnection.ready;
          _syncing = false;
        }
      } else if (type == 'player_registered') {
        if (frame['commandId'] != _profileCommandId) {
          throw const FormatException('Invalid profile registration');
        }
        _profile = OnlinePlayerProfile(
          name: frame['name'] as String,
          avatarId: frame['avatarId'] == 'avatar-01'
              ? _registrationAvatarOverride ?? frame['avatarId'] as String
              : frame['avatarId'] as String,
          level: onlinePlayerLevel(frame['level'] as String?),
          playerToken: frame['playerToken'] as String,
        );
        _profileCommandId = null;
        _registrationAvatarOverride = null;
        error = null;
        if (gameId != null && _seatToken != null) {
          connection = MatchConnection.resuming;
          _send({
            'type': 'resume_game',
            'gameId': gameId,
            'seatToken': _seatToken,
          });
        } else {
          connection = MatchConnection.ready;
          _syncing = false;
        }
        if (_pushDevice != null && supportsGamePush) _send(_pushDevice!);
        loadLeaderboard();
        loadPointHistory();
        loadInvitations();
        loadSharedInvitations();
        loadActiveGames();
      } else if (type == 'player_updated') {
        if (frame['commandId'] != _profileUpdateCommandId || _profile == null) {
          throw const FormatException('Invalid profile update');
        }
        _profile = OnlinePlayerProfile(
          name: frame['name'] as String,
          avatarId: frame['avatarId'] == 'avatar-01'
              ? _updateAvatarOverride ?? frame['avatarId'] as String
              : frame['avatarId'] as String,
          level: onlinePlayerLevel(frame['level'] as String?),
          playerToken: frame['playerToken'] as String,
        );
        _profileUpdateCommandId = null;
        _updateAvatarOverride = null;
        _pendingProfileEdit = null;
        error = null;
      } else if (type == 'leaderboard') {
        leaderboardLoading = false;
        leaderboard = List<OnlineLeaderboardEntry>.unmodifiable(
          (frame['leaders'] as List).map(
            (item) => OnlineLeaderboardEntry.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          ),
        );
        if (_legacyPlayersRequest) {
          final names = leaderboard
              .where((player) => player.name != _profile?.name)
              .map((player) => player.name)
              .toList(growable: false);
          if (names.isEmpty) {
            _completeLegacyPlayers(const {});
          } else {
            _legacyPresenceNames = names.toSet();
            _send({'type': 'presence', 'names': names});
          }
        }
      } else if (type == 'points_history') {
        pointHistory = List<OnlinePointRecord>.unmodifiable(
          (frame['matches'] as List).map(
            (item) => OnlinePointRecord.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          ),
        );
      } else if (type == 'credit_balance') {
        if (frame['account'] is! Map) {
          throw const FormatException('Missing credit account');
        }
      } else if (type == 'available_players') {
        if (frame['requestId'] != _playersRequest || _playersRequest == null) {
          return;
        }
        final page = (frame['players'] as List).map(
          (item) => OnlinePlayerSearchResult.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
        );
        final unique = {
          for (final player in availablePlayers) player.name: player,
        };
        for (final player in page) {
          unique[player.name] = player;
        }
        availablePlayers = List.unmodifiable(unique.values);
        _playersCursor = frame['nextCursor'] as String?;
        _playersTimeout?.cancel();
        _playersRequest = null;
        availablePlayersLoading = false;
      } else if (type == 'player_found') {
        final player = frame['player'] as Map?;
        playerSearchResult = player == null
            ? null
            : OnlinePlayerSearchResult.fromJson(player.cast<String, dynamic>());
        playerSearchCompleted = true;
      } else if (type == 'game_activity') {
        final game = OnlineInviteGame.fromJson(
          (frame['game'] as Map).cast<String, dynamic>(),
        );
        if (game.gameId != game.state.gameId ||
            !['w', 'b'].contains(game.seat)) {
          throw const FormatException('Invalid activity seat');
        }
        final previous = activeGames
            .where((g) => g.gameId == game.gameId)
            .firstOrNull;
        if (previous == null ||
            game.state.sequence >= previous.state.sequence) {
          activeGames = List.unmodifiable([
            game,
            ...activeGames.where((g) => g.gameId != game.gameId),
          ]);
          activeGamesLoaded = true;
          unawaited(
            gameArchive.recordAcceptedState(game.state, seat: game.seat),
          );
        }
      } else if (type == 'active_games') {
        final games = List<OnlineInviteGame>.unmodifiable(
          (frame['games'] as List).map(
            (item) => OnlineInviteGame.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          ),
        );
        if (games.any(
          (game) =>
              game.gameId != game.state.gameId ||
              !['w', 'b'].contains(game.seat),
        )) {
          throw const FormatException('Invalid active game seat');
        }
        activeGames = games;
        for (final game in games) {
          final current = state;
          if (current != null &&
              current.gameId == game.gameId &&
              current.sequence > game.state.sequence) {
            continue;
          }
          unawaited(
            gameArchive.recordAcceptedState(game.state, seat: game.seat),
          );
        }
        activeGamesLoaded = true;
      } else if (type == 'presence') {
        presence = {
          for (final item in frame['statuses'] as List)
            (item as Map)['name'] as String: item['online'] as bool,
        };
        if (_legacyPlayersRequest &&
            presence.keys.toSet().containsAll(_legacyPresenceNames)) {
          _completeLegacyPlayers(presence);
        }
      } else if (type == 'shared_invites') {
        sharedInvitations = List.unmodifiable(
          (frame['invites'] as List).map(
            (item) => SharedInvitation.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          ),
        );
      } else if (type == 'shared_invite_created' ||
          type == 'shared_invite_updated') {
        final invite = SharedInvitation.fromJson(
          (frame['invite'] as Map).cast<String, dynamic>(),
        );
        sharedInvitations = List.unmodifiable([
          if (invite.status != 'deleted') invite,
          ...sharedInvitations.where(
            (item) => item.inviteId != invite.inviteId,
          ),
        ]);
        if (type == 'shared_invite_created' &&
            frame['commandId'] == _sharedInviteCommandId &&
            _sharedInviteRequest?.isCompleted == false) {
          _sharedInviteRequest!.complete(invite);
        }
        if (invite.status == 'accepted') loadActiveGames();
      } else if (type == 'invites') {
        invitations = List<OnlineInvitation>.unmodifiable(
          (frame['invites'] as List).map(
            (item) => OnlineInvitation.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          ),
        );
      } else if (type == 'invite_deleted') {
        invitations = List.unmodifiable(
          invitations.where((item) => item.inviteId != frame['inviteId']),
        );
      } else if (type == 'invite_updated') {
        final invitation = OnlineInvitation.fromJson(
          (frame['invite'] as Map).cast<String, dynamic>(),
        );
        final updated = invitations.toList()
          ..removeWhere((item) => item.inviteId == invitation.inviteId)
          ..insert(0, invitation);
        invitations = List.unmodifiable(updated);
        if (invitation.game case final inviteGame?) {
          activeGames = List.unmodifiable([
            inviteGame,
            ...activeGames.where((game) => game.gameId != inviteGame.gameId),
          ]);
          activeGamesLoaded = true;
        }
      } else if (type == 'error') {
        error = frame['message'] as String? ?? 'The request was not accepted';
        if (frame['commandId'] == _sharedInviteCommandId &&
            _sharedInviteRequest?.isCompleted == false) {
          _sharedInviteRequest!.completeError(StateError(error!));
        }
        if (_profileUpdateCommandId != null &&
            frame['commandId'] == _profileUpdateCommandId) {
          _profileUpdateCommandId = null;
          _updateAvatarOverride = null;
          _pendingProfileEdit = null;
        }
        if (_profileCommandId != null &&
            frame['commandId'] == _profileCommandId) {
          _profileCommandId = null;
          _registrationAvatarOverride = null;
          _stopped = true;
          connection = MatchConnection.disconnected;
          _syncing = false;
          unawaited(_closeTransport());
        }
        if (frame['commandId'] == _pending?['commandId']) _pending = null;
        if (frame['commandId'] == null ||
            frame['commandId'] == _setupCommandId) {
          _setupCommandId = null;
          if (_matchmaking && state?.status != 'waiting') {
            _matchmaking = false;
          }
        }
        if (connection == MatchConnection.resuming) {
          // Missing rooms and invalid seats require a new lobby, not endless retries.
          _stopped = true;
          unawaited(_closeTransport());
          connection = MatchConnection.disconnected;
          if (_matchmaking) {
            _matchmaking = false;
            gameId = null;
            seat = null;
            _seatToken = null;
            session.clear();
            error = 'Match search ended after the connection was lost.';
          }
        }
      } else if ([
        'game_created',
        'seat_joined',
        'seat_resumed',
        'matchmaking_waiting',
        'match_found',
        'computer_match_found',
      ].contains(type)) {
        final next = OnlineGameState.fromJson(
          frame['state'] as Map<String, dynamic>,
        );
        final nextSeat = frame['seat'] as String;
        final replacedGameId = type == 'computer_match_found' ? gameId : null;
        if (!['w', 'b'].contains(nextSeat) ||
            frame['gameId'] != next.gameId ||
            (gameId != null &&
                gameId != next.gameId &&
                type != 'computer_match_found')) {
          throw const FormatException('Invalid seat');
        }
        gameId = next.gameId;
        seat = nextSeat;
        _seatToken = frame['seatToken'] as String? ?? _seatToken;
        if (_seatToken == null) {
          throw const FormatException('Missing seat token');
        }
        _setupCommandId = null;
        _matchmaking =
            next.status == 'waiting' &&
            (type == 'matchmaking_waiting' || _matchmaking);
        if (replacedGameId != null && replacedGameId != next.gameId) {
          session.clear();
        }
        if (session.apply(next, animate: false)) {
          unawaited(gameArchive.recordAcceptedState(next, seat: nextSeat));
        }
        activeGames = List.unmodifiable([
          OnlineInviteGame(
            gameId: next.gameId,
            seat: nextSeat,
            seatToken: _seatToken!,
            state: next,
          ),
          ...activeGames.where(
            (game) =>
                game.gameId != next.gameId && game.gameId != replacedGameId,
          ),
        ]);
        activeGamesLoaded = true;
        error = null;
        if (type == 'seat_resumed') {
          // Explicit full sync gates input and retries after recovering the seat.
          sync();
        } else {
          connection = MatchConnection.ready;
          _syncing = false;
        }
      } else if (type == 'game_state') {
        final next = OnlineGameState.fromJson(
          frame['state'] as Map<String, dynamic>,
        );
        if (next.gameId != gameId) return;
        if (session.apply(
              next,
              animate: connected && frame['synced'] != true,
            ) &&
            seat != null) {
          unawaited(gameArchive.recordAcceptedState(next, seat: seat!));
        }
        if (_seatToken != null && seat != null) {
          final remaining = activeGames.where(
            (game) => game.gameId != next.gameId,
          );
          activeGames = List.unmodifiable(
            next.status == 'complete'
                ? remaining
                : [
                    OnlineInviteGame(
                      gameId: next.gameId,
                      seat: seat!,
                      seatToken: _seatToken!,
                      state: next,
                    ),
                    ...remaining,
                  ],
          );
          activeGamesLoaded = true;
        }
        if (next.status != 'waiting') _matchmaking = false;
        if (next.status == 'complete') {
          loadLeaderboard();
          loadPointHistory();
        }
        if (frame['synced'] == true) {
          connection = MatchConnection.ready;
          _syncing = false;
          if (_pending != null) _send(_pending!);
        }
      } else if (type == 'matchmaking_cancelled') {
        if (frame['commandId'] == _setupCommandId &&
            frame['gameId'] == gameId) {
          _setupCommandId = null;
          _matchmaking = false;
          gameId = null;
          seat = null;
          _seatToken = null;
          session.clear();
          error = null;
        }
      } else if (type == 'command_result') {
        if (frame['commandId'] == _pending?['commandId']) {
          _pending = null;
          error = frame['accepted'] == true
              ? null
              : frame['message'] as String? ?? 'Action rejected';
        }
      }
      _sendPendingProfileEdit();
      _notify();
    } catch (_) {
      error = 'Online play returned an unexpected response';
      _notify();
    }
  }

  void _completeLegacyPlayers(Map<String, bool> statuses) {
    _legacyAvailablePlayers = List.unmodifiable(
      leaderboard
          .where(
            (player) =>
                player.name != _profile?.name && statuses[player.name] == true,
          )
          .map(
            (player) => OnlinePlayerSearchResult(
              name: player.name,
              avatarId: player.avatarId,
              level: player.level,
              online: true,
            ),
          ),
    );
    availablePlayers = List.unmodifiable(
      _legacyAvailablePlayers.take(_legacyVisiblePlayers),
    );
    _playersTimeout?.cancel();
    _legacyPresenceNames = const {};
    _legacyPlayersRequest = true;
    availablePlayersLoading = false;
    availablePlayersError = null;
  }

  void _applyCreditEnvelope(Map<String, dynamic> frame) {
    if (frame['creditPolicy'] case final Map policy) {
      creditPolicy = OnlineCreditPolicy.fromJson(
        policy.cast<String, dynamic>(),
      );
    }
    if (frame['account'] case final Map account) {
      creditAccount = OnlineCreditAccount.fromJson(
        account.cast<String, dynamic>(),
      );
      return;
    }
    if (frame['credits'] case final int balance) {
      final bonusCredits = frame['bonusCredits'] as int?;
      final purchasedCredits = frame['purchasedCredits'] as int?;
      creditAccount = creditAccount == null
          ? OnlineCreditAccount.balanceOnly(
              balance,
              bonusCredits: bonusCredits,
              purchasedCredits: purchasedCredits,
            )
          : creditAccount!.withBalance(
              balance,
              bonusCredits: bonusCredits,
              purchasedCredits: purchasedCredits,
            );
    }
  }

  void _send(Map<String, dynamic> frame) {
    try {
      _channel?.sink.add(jsonEncode(frame));
    } catch (_) {
      _lost(_generation);
    }
  }

  Future<void> _closeTransport() async {
    _retry?.cancel();
    _heartbeat?.cancel();
    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    await subscription?.cancel();
    if (channel != null) unawaited(channel.sink.close());
  }

  Future<void> disconnect() async {
    _clearAvailablePlayers();
    _cancelSharedInviteRequest();
    _stopped = true;
    ++_generation;
    connection = MatchConnection.disconnected;
    _notify();
    await _closeTransport();
  }

  Future<void> startAnotherGame() async {
    final endpoint = _endpoint;
    await disconnect();
    gameId = null;
    seat = null;
    _seatToken = null;
    _pending = null;
    _setupCommandId = null;
    _matchmaking = false;
    session.clear();
    error = null;
    if (endpoint != null) await connect(endpoint);
  }

  Future<void> openSavedGame({
    required String savedGameId,
    required String savedSeat,
    required String savedSeatToken,
  }) async {
    final endpoint = _endpoint;
    if (endpoint == null) return;
    await disconnect();
    gameId = savedGameId;
    seat = savedSeat;
    _seatToken = savedSeatToken;
    _pending = null;
    _setupCommandId = null;
    _matchmaking = false;
    session.clear();
    error = null;
    await connect(endpoint);
  }

  @override
  void dispose() {
    _disposed = true;
    gameArchive.removeListener(_notify);
    if (_ownsArchive) gameArchive.dispose();
    unawaited(disconnect());
    super.dispose();
  }
}
