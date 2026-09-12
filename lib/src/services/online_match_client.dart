// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/online_game_session.dart';
import '../domain/online_game_state.dart';
import '../domain/online_player_profile.dart';
import '../domain/online_social.dart';
export '../domain/online_game_state.dart';

enum MatchConnection { disconnected, connecting, resuming, ready }

class OnlineMatchClient extends ChangeNotifier {
  OnlineMatchClient({
    WebSocketChannel Function(Uri)? channelFactory,
    OnlinePlayerProfile? profile,
    this.retryDelay = const Duration(seconds: 2),
    this.heartbeatInterval = const Duration(seconds: 5),
    this.connectionTimeout = const Duration(seconds: 8),
  }) : _channelFactory = channelFactory ?? WebSocketChannel.connect,
       _profile = profile;

  final WebSocketChannel Function(Uri) _channelFactory;
  final Duration retryDelay;
  final Duration heartbeatInterval;
  final Duration connectionTimeout;
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
  int _generation = 0;
  int _lastFrameAt = 0;
  bool _disposed = false;
  bool _stopped = false;
  bool _syncing = false;
  bool _matchmaking = false;
  OnlinePlayerProfile? _profile;
  List<OnlineLeaderboardEntry> leaderboard = const [];
  List<OnlinePointRecord> pointHistory = const [];
  List<OnlineInvitation> invitations = const [];
  List<OnlineInviteGame> activeGames = const [];
  bool activeGamesLoaded = false;
  Map<String, bool> presence = const {};
  OnlinePlayerSearchResult? playerSearchResult;
  bool playerSearchCompleted = false;

  MatchConnection connection = MatchConnection.disconnected;
  String? gameId;
  String? seat;
  String? error;
  OnlinePlayerProfile? get profile => _profile;
  String? get seatToken => _seatToken;
  bool get connected => connection == MatchConnection.ready && !_syncing;
  bool get busy => _pending != null || _setupCommandId != null;
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> connect(Uri endpoint) async {
    if (_disposed) return;
    if (!['ws', 'wss'].contains(endpoint.scheme) || endpoint.host.isEmpty) {
      error = 'Enter a valid ws:// or wss:// endpoint';
      _notify();
      return;
    }
    if (gameId != null && _endpoint != null && endpoint != _endpoint) {
      error = 'Leave this room before connecting to a different server';
      _notify();
      return;
    }
    _endpoint = endpoint;
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
    ++_generation; // Invalidates callbacks from the old socket immediately.
    connection = MatchConnection.disconnected;
    _syncing = true;
    if (_setupCommandId != null) {
      _setupCommandId = null;
      error =
          'Room connection interrupted. Reconnect and create or join again.';
    } else {
      error = 'Connection lost. Your game clock continues on the server.';
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

  void createGame({int baseMs = 600000, int incrementMs = 0}) {
    if (!connected || busy || gameId != null) return;
    _setupCommandId = _newId();
    _send({
      'type': 'create_game',
      'commandId': _setupCommandId,
      'baseMs': baseMs,
      'incrementMs': incrementMs,
    });
    _notify();
  }

  void quickMatch({int baseMs = 600000, int incrementMs = 0}) {
    if (!connected || busy || gameId != null) return;
    _matchmaking = true;
    _setupCommandId = _newId();
    _send({
      'type': 'quick_match',
      'commandId': _setupCommandId,
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

  void loadLeaderboard() {
    if (connected) _send(const {'type': 'leaderboard'});
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

  void loadActiveGames() {
    if (connected) _send(const {'type': 'list_games'});
  }

  void loadPresence(Iterable<String> names) {
    if (connected) _send({'type': 'presence', 'names': names.toList()});
  }

  void sendInvitation(String opponentName, {DateTime? scheduledAt}) {
    if (!connected) return;
    _send({
      'type': 'send_invite',
      'commandId': _newId(),
      'opponentName': opponentName,
      if (scheduledAt != null)
        'scheduledAt': scheduledAt.millisecondsSinceEpoch,
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

  void proposeInvitationTime(String inviteId, DateTime scheduledAt) {
    if (!connected) return;
    _send({
      'type': 'propose_invite_time',
      'commandId': _newId(),
      'inviteId': inviteId,
      'scheduledAt': scheduledAt.millisecondsSinceEpoch,
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
      if (type == 'pong') {
        // The frame timestamp above is the heartbeat acknowledgement.
      } else if (type == 'connected') {
        if (frame['protocolVersion'] != 2) {
          error = 'Update the match server to protocol version 2';
          unawaited(disconnect());
        } else if (_profile != null) {
          _profileCommandId = _newId();
          _send({
            'type': 'register_player',
            'commandId': _profileCommandId,
            'name': _profile!.name,
            'avatarId': _profile!.avatarId,
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
          avatarId: frame['avatarId'] as String,
          playerToken: frame['playerToken'] as String,
        );
        _profileCommandId = null;
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
        loadLeaderboard();
        loadPointHistory();
        loadInvitations();
        loadActiveGames();
      } else if (type == 'leaderboard') {
        leaderboard = List<OnlineLeaderboardEntry>.unmodifiable(
          (frame['leaders'] as List).map(
            (item) => OnlineLeaderboardEntry.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          ),
        );
      } else if (type == 'points_history') {
        pointHistory = List<OnlinePointRecord>.unmodifiable(
          (frame['matches'] as List).map(
            (item) => OnlinePointRecord.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          ),
        );
      } else if (type == 'player_found') {
        final player = frame['player'] as Map?;
        playerSearchResult = player == null
            ? null
            : OnlinePlayerSearchResult.fromJson(player.cast<String, dynamic>());
        playerSearchCompleted = true;
      } else if (type == 'active_games') {
        activeGames = List<OnlineInviteGame>.unmodifiable(
          (frame['games'] as List).map(
            (item) => OnlineInviteGame.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          ),
        );
        activeGamesLoaded = true;
      } else if (type == 'presence') {
        presence = {
          for (final item in frame['statuses'] as List)
            (item as Map)['name'] as String: item['online'] as bool,
        };
      } else if (type == 'invites') {
        invitations = List<OnlineInvitation>.unmodifiable(
          (frame['invites'] as List).map(
            (item) => OnlineInvitation.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          ),
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
        error = frame['message'] as String? ?? 'Server rejected the request';
        if (frame['commandId'] == _profileCommandId) {
          _profileCommandId = null;
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
      ].contains(type)) {
        final next = OnlineGameState.fromJson(
          frame['state'] as Map<String, dynamic>,
        );
        final nextSeat = frame['seat'] as String;
        if (!['w', 'b'].contains(nextSeat) ||
            frame['gameId'] != next.gameId ||
            (gameId != null && gameId != next.gameId)) {
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
        session.apply(next, animate: false);
        activeGames = List.unmodifiable([
          OnlineInviteGame(
            gameId: next.gameId,
            seat: nextSeat,
            seatToken: _seatToken!,
            state: next,
          ),
          ...activeGames.where((game) => game.gameId != next.gameId),
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
        session.apply(next, animate: connected && frame['synced'] != true);
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
      _notify();
    } catch (_) {
      error = 'Received an invalid server response';
      _notify();
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
    unawaited(disconnect());
    super.dispose();
  }
}
