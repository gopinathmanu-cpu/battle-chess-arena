// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import '../play/game_header_ribbon.dart';
import 'dart:math' as math;
import '../../services/match_appearance_storage.dart';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import '../../domain/capture_threat.dart';
import '../play/threat_scan.dart';
import '../play/play_assist_style.dart';
import '../play/move_suggestion_button_content.dart';

import '../play/board_appearance.dart';
import '../../services/custom_chess_sets.dart';
import '../../services/custom_set_actions.dart';

import 'package:flutter/services.dart';

import '../../domain/game_session.dart';
import '../../domain/game_result_analysis.dart';
import '../../domain/cinematic_replay.dart';
import '../../domain/neon_live_action.dart';
import '../../domain/online_player_profile.dart';
import '../../domain/online_credits.dart';
import '../../domain/piece_pack.dart';
import '../../domain/player_progress.dart';
import '../../services/computer_player.dart';
import '../../services/game_display_settings.dart';
import '../../services/player_progress_controller.dart';
import '../../services/arena_credit_controller.dart';
import '../settings/game_settings_sheet.dart';
import '../settings/board_color_settings.dart';
import '../play/captured_pieces_panel.dart';
import '../../services/theme_music.dart';
import '../../services/online_match_client.dart';
import '../play/chess_widgets.dart';
import '../play/capture_battle_overlay.dart';
import '../play/checkmate_dialog.dart';
import '../play/neon_cinematic_screen.dart';
import '../play/neon_live_arena.dart';
import '../play/neon_live_game_layout.dart';
import '../play/match_opponent_panel.dart';
import '../play/animated_accepted_capture_cues.dart';
import 'online_avatar_image.dart';

class OnlineGameScreen extends StatefulWidget {
  const OnlineGameScreen({
    required this.client,
    required this.pack,
    this.computerPlayer,
    this.initialClassicPieces = true,
    this.initialAnimatedArena,
    this.initialClassicStyle = ClassicPieceStyle.magneticTeaching,
    super.key,
  });
  final OnlineMatchClient client;
  final PiecePack pack;
  final ComputerPlayer? computerPlayer;
  final bool initialClassicPieces;
  final bool? initialAnimatedArena;
  final ClassicPieceStyle initialClassicStyle;

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen>
    with WidgetsBindingObserver {
  late BoardAppearance _appearance = BoardAppearance.forPack(widget.pack);
  late bool _classicPieces = widget.initialClassicPieces;
  late bool _animatedArena =
      widget.initialAnimatedArena ?? !widget.initialClassicPieces;
  late ClassicPieceStyle _classicStyle = widget.initialClassicStyle;
  final _threats = ThreatScanController();
  final _threatBoardKey = GlobalKey();
  final _boardScroll = ScrollController();
  final _displaySettings = GameDisplaySettings();
  ArenaCreditController? _creditHeader;
  OnlineCreditAccount? _publishedCreditAccount;

  void _refreshThreats() {
    if (mounted) {
      _syncLiveAppearance();
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _creditHeader = ArenaCreditScope.maybeOf(context);
    _syncCreditHeader();
    _threats.setReducedMotion(
      _reduceMotion || MediaQuery.disableAnimationsOf(context),
    );
    _syncLiveAppearance();
    if (_appearanceLoaded) {
      unawaited(_client.rememberGameAppearance(_displayAppearance));
    }
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
    if (identical(account, _publishedCreditAccount)) return;
    _publishedCreditAccount = account;
    header.acceptServerAccount(
      profileToken: profileToken,
      account: account,
      policy: _client.creditPolicy,
    );
  }

  void _analyseThreats() {
    final state = _client.state;
    if (!_inputEnabled || state == null) return;
    _clearLifelineHint();
    setState(() {
      _selected = null;
      _targets = const {};
      _liveAction = null;
    });
    final defender = _client.seat == 'b' ? Side.black : Side.white;
    _threats.start(
      immediateCaptureThreats(state.position, defender: defender),
      reducedMotion: _reduceMotion || MediaQuery.disableAnimationsOf(context),
    );
  }

  BoardAppearance get _displayAppearance {
    final base = BoardAppearance(
      white: _appearance.white,
      black: _appearance.black,
      board: _appearance.board,
      standardPieces: _classicPieces,
      animatedArena: _animatedArena,
      classicStyle: _classicStyle,
    );
    var result = base.withCustomSet(
      CustomChessSetScope.maybeOf(context)?.active,
    );
    if (_displaySettings.customBoardColorsEnabled) {
      result = result.withBoardColors(
        _displaySettings.boardLightSquare,
        _displaySettings.boardDarkSquare,
      );
    }
    return result;
  }

  List<String>? _cinematicSan;
  String? _cinematicFen;
  List<String>? _cinematicMoves;

  List<String>? _replayMoves(OnlineGameState state) {
    if (state.status != 'complete') return null;
    if (!identical(_cinematicSan, state.san) || _cinematicFen != state.fen) {
      _cinematicSan = state.san;
      _cinematicFen = state.fen;
      try {
        _cinematicMoves = replayUciMovesFromSan(
          state.san,
          expectedFen: state.fen,
        );
      } on FormatException {
        _cinematicMoves = null;
      }
    }
    return _cinematicMoves;
  }

  bool _canWatchCinematic(OnlineGameState state) {
    final appearance = _displayAppearance;
    return usesAnimatedLiveArena(appearance) && _replayMoves(state) != null;
  }

  Future<void> _watchCinematic(OnlineGameState state) async {
    final moves = _replayMoves(state);
    final theme = animatedArmyThemeForAppearance(_displayAppearance);
    if (moves == null || theme == null || !_canWatchCinematic(state)) return;
    final snapshot = List<String>.unmodifiable(moves);
    final playerSide = switch (_client.seat) {
      'w' => Side.white,
      'b' => Side.black,
      _ => null,
    };
    final winnerSide = switch (state.winner) {
      'w' => Side.white,
      'b' => Side.black,
      _ => null,
    };
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => NeonCinematicScreen(
          theme: theme,
          classicStyle: _classicStyle,
          moves: snapshot,
          resultTitle: state.statusLabel,
          playerSide: playerSide,
          winnerSide: winnerSide,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _toggleBoardColors() => unawaited(_displaySettings.toggleBoardColors());

  Future<void> _togglePieceStyle() async {
    if (!await restoreBuiltInChessSet(context) || !mounted) return;
    _threats.stop();
    setState(() {
      _animatedArena = !_animatedArena;
      _classicPieces = !_animatedArena;
    });
    await _rememberAppearance();
  }

  int _appearanceRevision = 0;
  bool _appearanceLoaded = false;
  String? _appearanceIdentity;
  String? get _currentAppearanceIdentity {
    final id = _client.gameId;
    final seat = _client.seat;
    final round = _client.state?.round;
    return id == null || seat == null || round == null
        ? null
        : '$id:$round:$seat';
  }

  Future<void> _loadAppearance() async {
    final id = _client.gameId;
    final seat = _client.seat;
    final round = _client.state?.round;
    final revision = ++_appearanceRevision;
    final newRound =
        _appearanceIdentity != null &&
        _appearanceIdentity != _currentAppearanceIdentity;
    _appearanceIdentity = _currentAppearanceIdentity;
    _appearanceLoaded = false;
    if (newRound) {
      _classicPieces = true;
      _animatedArena = false;
    }
    if (id == null || seat == null) return;
    try {
      final saved = newRound
          ? null
          : await MatchAppearanceStorage.load(id, seat);
      if (!mounted ||
          revision != _appearanceRevision ||
          id != _client.gameId ||
          seat != _client.seat ||
          round != _client.state?.round) {
        return;
      }
      if (saved != null) {
        setState(() {
          _appearance = saved;
          _classicPieces = saved.standardPieces;
          _animatedArena = saved.animatedArena;
          _classicStyle = saved.classicStyle;
          _syncLiveAppearance();
        });
      }
      _appearanceLoaded = true;
      // A room without a preference still needs its actual initial display
      // retained. Loading first avoids replacing an existing saved chess set.
      await _rememberAppearance();
    } catch (_) {
      /* A corrupt preference must not block a game. */
      if (mounted &&
          revision == _appearanceRevision &&
          id == _client.gameId &&
          seat == _client.seat &&
          round == _client.state?.round) {
        _appearanceLoaded = true;
        unawaited(_client.rememberGameAppearance(_displayAppearance));
      }
    }
  }

  Future<void> _rememberAppearance() async {
    _syncLiveAppearance();
    ++_appearanceRevision;
    final id = _client.gameId;
    final seat = _client.seat;
    if (id == null || seat == null) return;
    _appearanceLoaded = true;
    final appearance = _displayAppearance;
    unawaited(_client.rememberGameAppearance(appearance));
    try {
      await MatchAppearanceStorage.save(id, seat, appearance);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chess set changed, but could not save it. Please try again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _swipeChessSet(int direction) async {
    if (_battle != null || _battleQueue.isNotEmpty) return;
    if (!await restoreBuiltInChessSet(context) || !mounted) return;
    _threats.stop();
    setState(() {
      if (_animatedArena) {
        _classicPieces = !_classicPieces;
      } else {
        _classicPieces = true;
        _classicStyle =
            ClassicPieceStyle.values[(_classicStyle.index + direction) %
                ClassicPieceStyle.values.length];
      }
    });
    await _rememberAppearance();
  }

  Future<void> _customize() async {
    _threats.stop();
    final next = await chooseBoardAppearance(context, _displayAppearance);
    if (mounted && next != null) {
      if (!await restoreBuiltInChessSet(context) || !mounted) return;
      setState(() {
        _appearance = next;
        _classicPieces = next.standardPieces;
        _classicStyle = next.classicStyle;
      });
      await _rememberAppearance();
    }
  }

  Future<void> _applyChessSet(ChessSetSelection selection) async {
    if (!await restoreBuiltInChessSet(context) || !mounted) return;
    _threats.stop();
    setState(() {
      _appearance = BoardAppearance.forPack(selection.pack);
      _classicPieces = !selection.animatedArena;
      _animatedArena = selection.animatedArena;
      _classicStyle = selection.classicStyle;
    });
    await _rememberAppearance();
  }

  void _openSettings() {
    _threats.stop();
    unawaited(
      showGameSettings(
        context: context,
        display: _displaySettings,
        onCustomize: _customize,
        chessSetSelector: (refresh) => SettingsChessSetPicker(
          animatedArena: _animatedArena,
          pack: _appearance.white,
          classicStyle: _classicStyle,
          onSelected: (selection) async {
            await _applyChessSet(selection);
            refresh();
          },
        ),
        onReset: () async {
          if (!mounted) return;
          setState(() {
            _appearance = BoardAppearance.forPack(piecePacks.first);
            _classicPieces = true;
            _animatedArena = false;
            _classicStyle = ClassicPieceStyle.magneticTeaching;
            _battlesEnabled = true;
            _fastBattles = false;
            _showTopBar = true;
            _reduceMotion = false;
            _threats.setReducedMotion(MediaQuery.disableAnimationsOf(context));
          });
          await _rememberAppearance();
        },
        controls: (refresh) => [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy Game ID'),
            onTap: () => copyGameId(context, _client.gameId),
          ),
          SwitchListTile(
            value: _battlesEnabled,
            title: const Text('Capture battles'),
            onChanged: (value) {
              setState(() => _battlesEnabled = value);
              if (!value) {
                _battleQueue.clear();
                _battleGapTimer?.cancel();
                _battleGapActive = false;
                _finishBattle(showNext: false);
              }
              refresh();
            },
          ),
          SwitchListTile(
            value: _fastBattles,
            title: const Text('Fast battles'),
            onChanged: (value) {
              setState(() => _fastBattles = value);
              refresh();
            },
          ),
          SwitchListTile(
            value: _reduceMotion || MediaQuery.disableAnimationsOf(context),
            title: const Text('Reduced motion'),
            subtitle: const Text('Fade only. Game clocks always keep running.'),
            onChanged: MediaQuery.disableAnimationsOf(context)
                ? null
                : (value) {
                    setState(() {
                      _reduceMotion = value;
                      _threats.setReducedMotion(value);
                    });
                    refresh();
                  },
          ),
        ],
      ),
    );
  }

  Square? _selected;
  bool _swipeHintDismissed = false;
  Set<Square> _targets = const {};
  NeonLiveAction? _liveAction;
  String? _pendingLiveMoveIdentity;
  String? _pendingLiveMoveFen;
  OnlineGameState? _liveAcceptedState;
  String? _liveMatchIdentity;
  String? _liveAppearanceIdentity;

  String? _liveIdentity(OnlineGameState? state) =>
      state == null ? null : '${state.gameId}:${state.round}:${_client.seat}';

  void _syncLiveAppearance() {
    final appearance = _displayAppearance;
    // Classic board sprites and their style retain the same Animated armies and
    // accepted action. Replacing an army, custom set or board clears it.
    final identity =
        '${appearance.white.id.name}:${appearance.black.id.name}:'
        '${appearance.board.id.name}:${appearance.customSet?.id}:${appearance.animatedArena}:'
        '${appearance.lightSquare.toARGB32()}:${appearance.darkSquare.toARGB32()}';
    if (identity != _liveAppearanceIdentity) {
      _liveAppearanceIdentity = identity;
      _liveAction = null;
      _pendingLiveMoveIdentity = null;
      _pendingLiveMoveFen = null;
    }
  }

  void _syncLiveAcceptedAction(OnlineGameState? next) {
    final previous = _liveAcceptedState;
    final identity = _liveIdentity(next);
    final changedMatch = identity != _liveMatchIdentity;
    if (_pendingLiveMoveIdentity != null) {
      final invalid =
          identity != _pendingLiveMoveIdentity ||
          next == null ||
          !_client.connected ||
          next.status != 'active' ||
          !usesAnimatedLiveArena(_displayAppearance);
      final rejected = !_client.busy && _client.error != null;
      if (invalid || rejected) {
        if (_liveAction?.isSelection == true) _liveAction = null;
        _pendingLiveMoveIdentity = null;
        _pendingLiveMoveFen = null;
      } else if (next.fen != _pendingLiveMoveFen) {
        // Preserve the actor's selected pose until the verified move below
        // replaces it. A successful ACK can precede this accepted position.
        _pendingLiveMoveIdentity = null;
        _pendingLiveMoveFen = null;
      }
    }
    _liveMatchIdentity = identity;
    _liveAcceptedState = _client.connected ? next : null;
    if (changedMatch ||
        next == null ||
        !_client.connected ||
        !usesAnimatedLiveArena(_displayAppearance)) {
      _liveAction = null;
      return;
    }
    if (previous == null || identical(previous, next)) return;
    if (next.status != 'active' && _liveAction?.isSelection == true) {
      _liveAction = null;
    }
    final historyChanged =
        previous.san.length != next.san.length ||
        Iterable<int>.generate(
          previous.san.length,
        ).any((i) => i >= next.san.length || previous.san[i] != next.san[i]);
    if (previous.fen == next.fen && !historyChanged) return;
    // The client supplies a move only for a verified, accepted single ply.
    // Clock updates, retries and reconnect gaps must never invent an action.
    final resolution = _client.session.committedMove;
    _liveAction = resolution == null || next.sequence <= previous.sequence
        ? null
        : NeonLiveAction.move(
            before: previous.position,
            after: next.position,
            resolution: resolution,
            viewerSide: _client.seat == 'b' ? Side.black : Side.white,
          );
  }

  MoveResolution? _battle;
  final List<MoveResolution> _battleQueue = [];
  Timer? _battleTimer;
  Timer? _battleGapTimer;
  Timer? _displayTimer;
  Timer? _hintTimer;
  late final ComputerPlayer _computer;
  int _lastCapture = -1;
  String? _lastFen;
  int? _round;
  bool _promotionOpen = false;
  bool _battlesEnabled = true;
  bool _fastBattles = false;
  bool _showTopBar = true;
  bool _reduceMotion = false;
  int? _resultScheduledRound;
  int? _resultShownRound;
  int _lastLifelineRequests = 0;
  int _hintRequestEpoch = 0;
  bool _hintThinking = false;
  Square? _hintFrom;
  Square? _hintTo;
  String? _hintMessage;
  Square? _lastOpponentFrom;
  Square? _lastOpponentTo;
  String? _cachedHintFen;
  Square? _cachedHintFrom;
  Square? _cachedHintTo;
  DateTime? _lastBattleEndedAt;
  bool _battleGapActive = false;
  OnlineMatchClient get _client => widget.client;
  bool get _inputEnabled =>
      _client.canAct &&
      _client.session.canMove(_client.seat) &&
      _battle == null &&
      _battleQueue.isEmpty &&
      !_battleGapActive &&
      !_hintThinking &&
      !_promotionOpen &&
      _pendingLiveMoveIdentity == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _threats.addListener(_refreshThreats);
    _displaySettings.addListener(_refreshThreats);
    _computer = widget.computerPlayer ?? ReliableComputerPlayer();
    _lastCapture = _client.session.captureSequence;
    _lastFen = _client.state?.fen;
    _round = _client.state?.round;
    _liveAcceptedState = _client.state;
    _liveMatchIdentity = _liveIdentity(_client.state);
    _lastLifelineRequests =
        _client.state?.lifelineRequestsFor(_client.seat) ?? 0;
    final initialState = _client.state;
    if (initialState != null) _restoreOpponentMove(initialState);
    _client.addListener(_refresh);
    unawaited(_loadAppearance());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = _client.state;
      if (state != null) _scheduleResult(state);
    });
    _displayTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _restoreOpponentMove(OnlineGameState state) {
    if (state.san.isEmpty || state.turn != _client.seat) return;
    final replay = GameSession();
    NormalMove? lastMove;
    for (final san in state.san) {
      final move = replay.position.parseSan(san);
      if (move is! NormalMove ||
          replay.play(
                move.from,
                move.to,
                promotion: move.promotion ?? Role.queen,
              ) ==
              null) {
        return;
      }
      lastMove = move;
    }
    if (lastMove != null && replay.position.fen == state.position.fen) {
      _lastOpponentFrom = lastMove.from;
      _lastOpponentTo = lastMove.to;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _threats.stop();
    if (state == AppLifecycleState.resumed) {
      if (_client.connected) {
        _client.sync();
      } else {
        _client.reconnect();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _threats.removeListener(_refreshThreats);
    _threats.dispose();
    _boardScroll.dispose();
    _displaySettings.removeListener(_refreshThreats);
    _displaySettings.dispose();
    _client.removeListener(_refresh);
    _displayTimer?.cancel();
    _battleTimer?.cancel();
    _battleGapTimer?.cancel();
    _hintTimer?.cancel();
    _computer.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    final state = _client.state;
    final identity = _currentAppearanceIdentity;
    if (_appearanceIdentity != identity) {
      unawaited(_loadAppearance());
    }
    _syncCreditHeader();
    final matchChanged = _liveIdentity(state) != _liveMatchIdentity;
    _syncLiveAcceptedAction(state);
    final roundChanged = _round != state?.round;
    if (roundChanged || matchChanged) _swipeHintDismissed = false;
    if (state?.san.isNotEmpty == true) _swipeHintDismissed = true;
    final fenChanged = _lastFen != state?.fen;
    final enteredActiveCheck =
        fenChanged &&
        !roundChanged &&
        state?.status == 'active' &&
        state?.position.isCheck == true;
    if (fenChanged ||
        roundChanged ||
        state?.status != 'active' ||
        !_client.canAct) {
      _threats.stop();
    }
    if (_lastFen != state?.fen ||
        !_client.connected ||
        roundChanged ||
        matchChanged ||
        state?.status != 'active') {
      _selected = null;
      _targets = const {};
    }
    if (fenChanged || roundChanged || state?.status != 'active') {
      _hintRequestEpoch++;
      _hintTimer?.cancel();
      _hintThinking = false;
      _hintFrom = null;
      _hintTo = null;
      _hintMessage = null;
      _cachedHintFen = null;
      _cachedHintFrom = null;
      _cachedHintTo = null;
    }
    final requests = state?.lifelineRequestsFor(_client.seat) ?? 0;
    final lifelineRequested =
        state != null && !roundChanged && requests > _lastLifelineRequests;
    _lastLifelineRequests = requests;
    if (roundChanged) {
      _lastOpponentFrom = null;
      _lastOpponentTo = null;
      _battleQueue.clear();
      _battleGapTimer?.cancel();
      _battleGapActive = false;
      _lastBattleEndedAt = null;
      _finishBattle(showNext: false);
    }
    _round = state?.round;
    _lastFen = state?.fen;
    final capture = _client.session.committedCapture;
    final committedMove = _client.session.committedMove;
    final playerSide = _client.seat == 'b' ? Side.black : Side.white;
    if (committedMove != null && committedMove.attacker.color != playerSide) {
      _lastOpponentFrom = committedMove.move.from;
      _lastOpponentTo = committedMove.move.to;
    }
    if (_client.session.captureSequence != _lastCapture) {
      _lastCapture = _client.session.captureSequence;
      if (_battlesEnabled && capture != null) {
        _queueOrShowBattle(capture);
      }
    }
    setState(() {});
    if (enteredActiveCheck && state != null) {
      unawaited(
        MusicScope.of(context)?.announceCheck(
          voice: avatarVoice(state.opponentFor(_client.seat ?? 'w').avatarId),
        ),
      );
    }
    if (lifelineRequested) unawaited(_generateLifelineHint(state));
    if (state != null) _scheduleResult(state);
  }

  Future<void> _generateLifelineHint(OnlineGameState requestedState) async {
    _threats.stop();
    final fen = requestedState.fen;
    final round = requestedState.round;
    if (_cachedHintFen == fen &&
        _cachedHintFrom != null &&
        _cachedHintTo != null) {
      _displayHint(_cachedHintFrom!, _cachedHintTo!, fen);
      return;
    }
    final requestEpoch = ++_hintRequestEpoch;
    setState(() {
      _hintThinking = true;
      _hintFrom = null;
      _hintTo = null;
      _hintMessage = 'Finding the best move…';
    });
    try {
      final suggestion = await _computer.bestAssistanceMove(fen);
      if (!mounted ||
          requestEpoch != _hintRequestEpoch ||
          _client.state?.fen != fen ||
          _client.state?.round != round) {
        return;
      }
      final parsed = suggestion == null ? null : Move.parse(suggestion);
      if (parsed case final NormalMove move
          when requestedState.position.isLegal(move)) {
        _displayHint(move.from, move.to, fen);
      } else {
        setState(() {
          _hintThinking = false;
          _hintMessage = 'A move suggestion is unavailable for this position.';
        });
      }
    } catch (_) {
      if (!mounted || requestEpoch != _hintRequestEpoch) return;
      setState(() {
        _hintThinking = false;
        _hintMessage = 'A move suggestion is unavailable on this device.';
      });
    }
  }

  void _displayHint(Square from, Square to, String fen) {
    final displayEpoch = ++_hintRequestEpoch;
    _hintTimer?.cancel();
    setState(() {
      _hintThinking = false;
      _hintFrom = from;
      _hintTo = to;
      _hintMessage =
          'Suggested move: ${from.name} → ${to.name} · highlighted for 10 seconds';
      _cachedHintFen = fen;
      _cachedHintFrom = from;
      _cachedHintTo = to;
    });
    _hintTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted || displayEpoch != _hintRequestEpoch) return;
      setState(() {
        _hintFrom = null;
        _hintTo = null;
        _hintMessage = null;
      });
    });
  }

  void _useOnlineLifeline() {
    if (!_inputEnabled) return;
    _threats.stop();
    _client.useLifeline();
  }

  void _clearLifelineHint() {
    if (!_hintThinking &&
        _hintFrom == null &&
        _hintTo == null &&
        _hintMessage == null) {
      return;
    }
    _hintRequestEpoch++;
    _hintTimer?.cancel();
    setState(() {
      _hintThinking = false;
      _hintFrom = null;
      _hintTo = null;
      _hintMessage = null;
    });
  }

  void _queueOrShowBattle(MoveResolution capture) {
    if (_battle != null || _battleGapActive) {
      _battleQueue.add(capture);
      return;
    }
    final elapsed = _lastBattleEndedAt == null
        ? const Duration(seconds: 2)
        : DateTime.now().difference(_lastBattleEndedAt!);
    if (elapsed < const Duration(seconds: 2)) {
      _battleQueue.add(capture);
      _scheduleNextBattle(const Duration(seconds: 2) - elapsed);
      return;
    }
    _showBattle(capture);
  }

  void _showBattle(MoveResolution capture) {
    if (!mounted) return;
    _battle = capture;
    _battleGapActive = false;
    _battleTimer?.cancel();
    final reduced = _reduceMotion || MediaQuery.disableAnimationsOf(context);
    _battleTimer = Timer(
      captureBattleDuration(reduced: reduced, fast: _fastBattles) +
          Duration(milliseconds: reduced ? 25 : 100),
      _finishBattle,
    );
  }

  void _scheduleNextBattle(Duration delay) {
    _battleGapTimer?.cancel();
    _battleGapActive = true;
    _battleGapTimer = Timer(delay, () {
      if (!mounted) return;
      if (!_battlesEnabled || _battleQueue.isEmpty) {
        setState(() => _battleGapActive = false);
        return;
      }
      final next = _battleQueue.removeAt(0);
      setState(() => _showBattle(next));
    });
  }

  void _finishBattle({bool showNext = true}) {
    _battleTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _battle = null;
      _lastBattleEndedAt = DateTime.now();
    });
    MusicScope.of(context)?.resumeBackground();
    if (showNext && _battleQueue.isNotEmpty && _battlesEnabled) {
      _scheduleNextBattle(const Duration(seconds: 2));
      return;
    }
    final state = _client.state;
    if (state != null) _scheduleResult(state);
  }

  void _scheduleResult(OnlineGameState state) {
    if (state.status != 'complete' ||
        _resultShownRound == state.round ||
        _resultScheduledRound == state.round ||
        _battle != null ||
        _battleQueue.isNotEmpty ||
        _battleGapActive) {
      return;
    }
    _resultScheduledRound = state.round;
    final delay =
        usesAnimatedLiveArena(_displayAppearance) && _liveAction != null
        ? neonLiveMoveAnimationDuration
        : const Duration(milliseconds: 250);
    Future.delayed(delay, () {
      if (!mounted) return;
      final latest = _client.state;
      if (latest?.status == 'complete' && latest?.round == state.round) {
        unawaited(_showOnlineResult(latest!));
      } else {
        _resultScheduledRound = null;
      }
    });
  }

  Future<void> _showOnlineResult(OnlineGameState state) async {
    if (!mounted || _resultShownRound == state.round) return;
    _resultShownRound = state.round;
    final draw = state.winner == null;
    final userWon = state.winner == _client.seat;
    final outcome = draw
        ? GameResultOutcome.draw
        : userWon
        ? GameResultOutcome.victory
        : GameResultOutcome.defeat;
    final heading = switch (state.resultReason) {
      'checkmate' => 'CHECKMATE',
      'timeout' => 'WINNER BY TIMEOUT',
      'resignation' => 'RESIGNATION',
      _ when draw => 'DRAW',
      _ => 'GAME OVER',
    };
    final message = state.resultReason == 'timeout'
        ? userWon
              ? const GameResultMessage(
                  sentiment: 'Victory on the clock! You held your nerve.',
                  comment:
                      'You managed the pressure and kept enough time to claim the arena.',
                )
              : const GameResultMessage(
                  sentiment: 'Time ran out, but the next battle awaits.',
                  comment:
                      'Play the critical positions a little faster and keep time for the finish.',
                )
        : draw
        ? const GameResultMessage(
            sentiment: 'A hard-fought draw.',
            comment:
                'Both players held their ground. Review the board and prepare for the rematch.',
          )
        : userWon
        ? const GameResultMessage(
            sentiment: 'Outstanding victory! You conquered the arena.',
            comment:
                'You kept control when it mattered and converted the game with confidence.',
          )
        : const GameResultMessage(
            sentiment: 'A brave fight. Your next victory starts here.',
            comment:
                'Review the decisive position, regroup, and challenge your opponent again.',
          );
    final voice = avatarVoice(state.opponentFor(_client.seat ?? 'w').avatarId);
    unawaited(
      userWon
          ? MusicScope.of(context)?.announceVictory(
              voice: voice,
              checkmate: state.resultReason == 'checkmate',
            )
          : state.resultReason == 'checkmate'
          ? MusicScope.of(context)?.announceCheckmateLoss(voice: voice)
          : MusicScope.of(context)?.playEffect(CinematicSound.finalStrike),
    );
    final progressAward = await _recordProgress(state, userWon);
    bool resultCurrent() =>
        mounted &&
        _client.state?.status == 'complete' &&
        _client.state?.round == state.round &&
        _client.state?.gameId == state.gameId;
    if (!mounted || !resultCurrent()) return;
    if (state.resultReason == 'checkmate') {
      await showCheckmateAnimation(
        context: context,
        winner: state.winner == 'b' ? Side.black : Side.white,
        appearance: _displayAppearance,
      );
      if (!mounted || !resultCurrent()) return;
    }
    final startNew = await showGameResultDialog(
      context: context,
      appearance: _displayAppearance,
      outcome: outcome,
      heading: heading,
      title: draw ? 'Game Drawn' : (userWon ? 'You Win!' : 'You Lost'),
      message: message,
      progressAward: progressAward,
      onWatchCinematic: _canWatchCinematic(state)
          ? () => _watchCinematic(state)
          : null,
    );
    if (mounted && startNew) {
      await _client.startAnotherGame();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<ProgressAward?> _recordProgress(
    OnlineGameState state,
    bool won,
  ) async {
    final controller = PlayerProgressScope.maybeOf(context);
    if (controller == null) return null;
    final credits = ArenaCreditScope.maybeOf(context);
    final award = await controller.recordCompletion(
      completionId: 'online:${state.gameId}:${state.round}',
      moveCount: state.san.length,
      won: won,
    );
    final unlocked = award.unlockedBadge;
    if (unlocked == null || credits == null) return award;
    final reward = await credits.grantBadgeUpgradeCredits(unlocked);
    return award.withBadgeCredits(reward);
  }

  Future<void> _tapSquare(Square square) async {
    _threats.stop();
    _clearLifelineHint();
    if (!_inputEnabled) return;
    final state = _client.state!;
    final piece = state.position.board.pieceAt(square);
    if (_selected == null || piece?.color == state.position.turn) {
      setState(() {
        _selected = piece?.color == state.position.turn ? square : null;
        if (_selected != null) _swipeHintDismissed = true;
        _targets = _selected == null
            ? const {}
            : _client.session.legalDestinations(_selected!, _client.seat);
        _liveAction =
            _selected == null || !usesAnimatedLiveArena(_displayAppearance)
            ? null
            : NeonLiveAction.selection(
                position: state.position,
                source: _selected!,
                viewerSide: _client.seat == 'b' ? Side.black : Side.white,
              );
      });
      return;
    }
    if (!_targets.contains(square)) return;
    final from = _selected!;
    var promotion = Role.queen;
    if (state.position.board.pieceAt(from)?.role == Role.pawn &&
        (square.rank == Rank.first || square.rank == Rank.eighth)) {
      _promotionOpen = true;
      final choice = await showModalBottomSheet<Role>(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Choose your promoted warrior'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [Role.queen, Role.rook, Role.bishop, Role.knight]
                      .map(
                        (role) => IconButton(
                          tooltip: role.name,
                          onPressed: () => Navigator.pop(context, role),
                          icon: SizedBox.square(
                            dimension: 48,
                            child: CharacterPiece(
                              piece: Piece(
                                color: state.position.turn,
                                role: role,
                              ),
                              pack: _displayAppearance.army(
                                state.position.turn,
                              ),
                              standard: _displayAppearance.standardPieces,
                              classicStyle: _displayAppearance.classicStyle,
                              customSet: _displayAppearance.customSet,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      );
      _promotionOpen = false;
      if (!mounted || choice == null) return;
      promotion = choice;
    }
    if (!_inputEnabled ||
        _client.state?.fen != state.fen ||
        _client.state?.round != state.round) {
      return;
    }
    final selection = _liveAction;
    if (usesAnimatedLiveArena(_displayAppearance) &&
        selection?.isSelection == true &&
        selection?.source == from) {
      _pendingLiveMoveIdentity = _liveIdentity(state);
      _pendingLiveMoveFen = state.fen;
    }
    _client.requestMove(from: from, to: square, promotion: promotion);
    setState(() {
      _selected = null;
      _targets = const {};
      if (_pendingLiveMoveIdentity == null || !_client.busy) {
        _pendingLiveMoveIdentity = null;
        _pendingLiveMoveFen = null;
        _liveAction = null;
      }
    });
  }

  Future<void> _resign() async {
    _threats.stop();
    final round = _client.state?.round;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resign this game?'),
        content: const Text('Your opponent will win this game.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resign'),
          ),
        ],
      ),
    );
    if (mounted &&
        confirmed == true &&
        _client.state?.round == round &&
        _client.state?.status == 'active') {
      _client.resign();
    }
  }

  Widget _buildBoard(
    BuildContext context,
    OnlineGameState state,
    Side side,
    Color accent,
  ) {
    return ZoomableChessBoard(
      key: _threatBoardKey,
      builder: (context, zoomed) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            ChessBoard(
              onSetSwipe: zoomed ? null : _swipeChessSet,
              swipeHint: !_swipeHintDismissed && state.san.isEmpty
                  ? (_animatedArena
                        ? 'Swipe left or right to toggle between classic and animated chess pieces'
                        : 'Swipe left or right to change classic chess pieces')
                  : null,
              showCoordinates: usesAnimatedLiveArena(_displayAppearance),
              animateMoves: usesAnimatedLiveArena(_displayAppearance),
              animatedMove: _client.session.committedMove?.move,
              reducedMotion:
                  _reduceMotion || MediaQuery.disableAnimationsOf(context),
              appearance: _displayAppearance,
              position: state.position,
              selected: _selected,
              legalTargets: _targets,
              accent: accent,
              orientation: side,
              hiddenPieceSquare: usesAnimatedLiveArena(_displayAppearance)
                  ? null
                  : _battle?.move.to,
              suggestedFrom: _hintFrom,
              suggestedTo: _hintTo,
              lastMoveFrom: _lastOpponentFrom,
              lastMoveTo: _lastOpponentTo,
              threatFrom: _threats.current?.from,
              threatTarget: _threats.current?.targetSquare,
              threatLanding: _threats.current?.enPassant == true
                  ? _threats.current?.to
                  : null,
              threatLit: _threats.lit,
              onSquareTap: _tapSquare,
            ),
            if (_battle != null)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, box) => Padding(
                    padding: EdgeInsets.all(
                      usesAnimatedLiveArena(_displayAppearance)
                          ? ChessBoard.coordinateInset(
                              math.min(box.maxWidth, box.maxHeight),
                            )
                          : 0,
                    ),
                    child: Stack(
                      children: [
                        CaptureBattleOverlay(
                          liveArena: usesAnimatedLiveArena(_displayAppearance),
                          appearance: _displayAppearance,
                          key: ValueKey(_lastCapture),
                          battle: _battle!,
                          accent: accent,
                          orientation: side,
                          reduced:
                              _reduceMotion ||
                              MediaQuery.disableAnimationsOf(context),
                          fast: _fastBattles,
                          useCharacterAsset:
                              !_classicPieces &&
                              _appearance.white.id == PiecePackId.anime &&
                              _appearance.black.id == PiecePackId.anime &&
                              _battle!.attacker.role == Role.pawn &&
                              _battle!.defender?.role == Role.pawn,
                          onSkip: _finishBattle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpponentProfile(OnlineGameState state) {
    final opponent = state.opponentFor(_client.seat ?? 'w');
    return MatchOpponentPanel(
      key: const ValueKey('online-opponent-profile'),
      name: opponent.name,
      details:
          '${onlinePlayerLevel(opponent.level).label}${opponent.computer && opponent.botLevel != null ? ' · Level ${opponent.botLevel}' : ''} · ${opponent.computer ? 'Computer' : 'Online player'} · ${state.timed ? 'Timed game' : 'No timer'}',
      avatarBuilder: (size) =>
          OnlineAvatarImage(avatarId: opponent.avatarId, size: size),
    );
  }

  List<Widget> _buildStatus(OnlineGameState state, Side side, Color accent) => [
    if (!_showTopBar)
      Align(
        alignment: Alignment.centerRight,
        child: GameHeaderWrap(
          icons: [
            PieceStyleToggleButton(
              key: const ValueKey('online-quick-piece-style-toggle'),
              classic: _classicPieces,
              cycleClassicSets: false,
              classicStyle: _classicStyle,
              themedPack: _appearance.white,
              onPressed: _togglePieceStyle,
            ),
            IconButton(
              key: const ValueKey('online-quick-board-color-toggle'),
              tooltip: _displaySettings.customBoardColorsEnabled
                  ? 'Use chess set board colours'
                  : 'Use saved board colours',
              onPressed: _toggleBoardColors,
              icon: ChessboardPaintIcon(
                active: _displaySettings.customBoardColorsEnabled,
              ),
            ),
            IconButton(
              tooltip: 'Game settings',
              onPressed: _openSettings,
              icon: const Icon(
                Icons.settings_outlined,
                color: Color(0xFF64D8CB),
              ),
            ),
            const MusicButton(),
            TopBarRestoreButton(
              accent: accent,
              onPressed: () => setState(() => _showTopBar = true),
            ),
          ],
        ),
      ),
    if (!_showTopBar) const SizedBox(height: 4),
    if (!_client.connected)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                _client.connectionLabel,
                key: const ValueKey('connection-status'),
              ),
              const Text('Moves are disabled until your game is synchronized.'),
              TextButton(
                onPressed: _client.connection == MatchConnection.disconnected
                    ? _client.reconnect
                    : null,
                child: const Text('Reconnect now'),
              ),
            ],
          ),
        ),
      ),
    if (state.tossForColors)
      Text(
        'Colour toss: You play ${_client.seat == 'b' ? 'Black' : 'White'} · White moves first',
        key: const ValueKey('colour-toss-result'),
        textAlign: TextAlign.center,
      ),
    MatchHeader(
      status: state.clockMode == 'daily'
          ? 'Daily · 24h per move · ${state.statusLabel}'
          : state.statusLabel,
      whiteTime: Duration(milliseconds: _client.session.clockMs('w')),
      blackTime: Duration(milliseconds: _client.session.clockMs('b')),
      turn: state.position.turn,
      accent: accent,
      timed: state.timed,
    ),
    const SizedBox(height: 12),
    TurnIndicator(
      isPlayerTurn: state.turn == _client.seat,
      playerLabel: 'YOUR TURN · PLAY NOW',
      opponentLabel: 'OPPONENT’S TURN · PLEASE WAIT',
    ),
    const SizedBox(height: 12),
    Text(
      'You are ${side == Side.white ? 'White' : 'Black'} · Round ${state.round}',
      key: const ValueKey('assigned-seat'),
      textAlign: TextAlign.center,
    ),
    if (_client.busy || _pendingLiveMoveIdentity != null)
      const Padding(
        padding: EdgeInsets.all(8),
        child: Text('Confirming move…', textAlign: TextAlign.center),
      ),
    if (_client.error != null)
      Text(_client.error!, style: const TextStyle(color: Colors.redAccent)),
    if (_client.historySaveError case final String historyError)
      Card(
        key: const ValueKey('online-history-save-error'),
        child: ListTile(
          leading: const Icon(Icons.history),
          title: Text(historyError),
          trailing: TextButton(
            onPressed: () => unawaited(_client.retryHistorySave()),
            child: const Text('Retry'),
          ),
        ),
      ),
    const SizedBox(height: 8),
  ];

  Widget? _buildQuickActions(OnlineGameState state) {
    if (state.status != 'active') return null;
    final computer = state.whitePlayer.computer || state.blackPlayer.computer;
    return Padding(
      key: ValueKey(
        computer ? 'online-computer-lifelines' : 'online-human-threat-scan',
      ),
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (computer) ...[
            Expanded(
              child: FilledButton.tonalIcon(
                key: const ValueKey('use-online-computer-lifeline'),
                style: playAssistButtonStyle.copyWith(
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                onPressed: _inputEnabled ? _useOnlineLifeline : null,
                icon: MoveSuggestionActionIcon(loading: _hintThinking),
                label: MoveSuggestionLabel(
                  cost: _client.creditPolicy.onlineMoveSuggestionCost,
                  priceKey: const ValueKey('online-suggestion-credit-cost'),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: ThreatScanButton(
              scan: _threats,
              enabled: _inputEnabled,
              onScan: _analyseThreats,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildControls(
    BuildContext context,
    OnlineGameState state,
    Side side,
    Color accent, {
    bool includeQuickActions = true,
  }) => [
    if (includeQuickActions && state.status == 'active')
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: IntrinsicHeight(child: _buildQuickActions(state)),
      ),
    if (_hintMessage != null)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _hintMessage!,
            key: const ValueKey('online-computer-hint-message'),
            style: TextStyle(color: accent, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    if (_displaySettings.showCapturedPieces)
      CapturedPiecesPanel(
        pieces: state.capturedPieces,
        appearance: _displayAppearance,
        playerSide: side,
      ),
    if (state.drawOfferSide != null)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                state.drawOfferSide == _client.seat
                    ? 'Draw offer sent'
                    : 'Your opponent offers a draw',
              ),
              if (state.drawOfferSide != _client.seat)
                Wrap(
                  spacing: 12,
                  children: [
                    FilledButton(
                      onPressed: _client.canAct
                          ? () => _client.respondDraw(true)
                          : null,
                      child: const Text('Accept draw'),
                    ),
                    OutlinedButton(
                      onPressed: _client.canAct
                          ? () => _client.respondDraw(false)
                          : null,
                      child: const Text('Decline'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    if (state.status == 'active')
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        children: [
          OutlinedButton(
            onPressed: _client.canAct && state.drawOfferId == null
                ? _client.offerDraw
                : null,
            child: const Text('Offer draw'),
          ),
          TextButton(
            onPressed: _client.canAct ? _resign : null,
            child: const Text('Resign'),
          ),
        ],
      ),
    if (state.status == 'complete')
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_canWatchCinematic(state)) ...[
            CinematicSummaryButton(
              key: const ValueKey('online-finished-match-cinematic'),
              onPressed: () => _watchCinematic(state),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed:
                _client.canAct && !state.rematchOffers.contains(_client.seat)
                ? _client.requestRematch
                : null,
            child: Text(
              state.rematchOffers.contains(_client.seat)
                  ? 'Waiting for opponent’s rematch agreement'
                  : state.rematchOffers.isEmpty
                  ? 'Request rematch'
                  : 'Accept rematch',
            ),
          ),
        ],
      ),
    MoveStrip(moves: state.san, accent: accent),
  ];

  Widget _compactStatus(OnlineGameState state) => NeonLiveStatusBar(
    status: state.clockMode == 'daily'
        ? 'Daily · 24h per move · ${state.statusLabel}'
        : state.statusLabel,
    whiteTime: Duration(milliseconds: _client.session.clockMs('w')),
    blackTime: Duration(milliseconds: _client.session.clockMs('b')),
    turn: state.position.turn,
    timed: state.timed,
  );

  @override
  Widget build(BuildContext context) {
    final state = _client.state;
    final accent = _appearance.board.accent;
    final side = _client.seat == 'b' ? Side.black : Side.white;
    return Scaffold(
      backgroundColor: _appearance.board.backdrop,
      appBar: _showTopBar
          ? AppBar(
              titleSpacing: 12,
              actionsPadding: const EdgeInsets.only(right: 12),
              title: null,
              actions: [
                GameHeaderRibbon(
                  scrollKey: const ValueKey('online-header-icons'),
                  icons: [
                    PieceStyleToggleButton(
                      key: const ValueKey('online-quick-piece-style-toggle'),
                      classic: _classicPieces,
                      cycleClassicSets: false,
                      classicStyle: _classicStyle,
                      themedPack: _appearance.white,
                      onPressed: _togglePieceStyle,
                    ),
                    IconButton(
                      key: const ValueKey('online-quick-board-color-toggle'),
                      tooltip: _displaySettings.customBoardColorsEnabled
                          ? 'Use chess set board colours'
                          : 'Use saved board colours',
                      onPressed: _toggleBoardColors,
                      icon: ChessboardPaintIcon(
                        active: _displaySettings.customBoardColorsEnabled,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Game settings',
                      onPressed: _openSettings,
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: Color(0xFF64D8CB),
                      ),
                    ),
                    const MusicButton(),
                    IconButton(
                      tooltip: 'Hide top bar',
                      onPressed: () => setState(() => _showTopBar = false),
                      icon: const Icon(
                        Icons.keyboard_arrow_up,
                        color: Color(0xFFBA8CFF),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : null,
      body: state == null
          ? const Center(child: Text('Waiting for game state…'))
          : WorldBackdrop(
              pack: _appearance.board,
              customSet: _displayAppearance.customSet,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: AnimatedAcceptedCaptureCues(
                      position: state.position,
                      action: _liveAction,
                      enabled: usesAnimatedLiveArena(_displayAppearance),
                      reducedMotion:
                          _reduceMotion ||
                          MediaQuery.disableAnimationsOf(context),
                    ),
                  ),
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final status = _buildStatus(state, side, accent);
                        final controls = _buildControls(
                          context,
                          state,
                          side,
                          accent,
                          includeQuickActions: false,
                        );
                        return NeonLiveGameLayout(
                          arena: _buildOpponentProfile(state),
                          compactPortraitArena: true,
                          quickActions: _buildQuickActions(state),
                          board: _buildBoard(context, state, side, accent),
                          header: _compactStatus(state),
                          details: [
                            ...status.where((widget) => widget is! MatchHeader),
                            ...controls,
                          ],
                          boardFooter: ThreatScanBanner(scan: _threats),
                          scrollController: _boardScroll,
                          portraitScrollKey: const ValueKey(
                            'portrait-online-match-scroll',
                          ),
                          landscapeScrollKey: const ValueKey(
                            'landscape-online-match-scroll',
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

Future<void> copyGameId(BuildContext context, String? gameId) async {
  if (gameId == null) return;
  await Clipboard.setData(ClipboardData(text: gameId));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Game ID copied. Share it with your opponent.'),
      ),
    );
  }
}
