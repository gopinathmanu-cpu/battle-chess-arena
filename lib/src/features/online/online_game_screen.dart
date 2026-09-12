// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import '../play/board_appearance.dart';
import 'package:flutter/services.dart';

import '../../domain/game_session.dart';
import '../../domain/game_result_analysis.dart';
import '../../domain/online_player_profile.dart';
import '../../domain/piece_pack.dart';
import '../../services/computer_player.dart';
import '../../services/theme_music.dart';
import '../../services/online_match_client.dart';
import '../play/chess_widgets.dart';
import '../play/capture_battle_overlay.dart';
import '../play/checkmate_dialog.dart';
import 'online_avatar_image.dart';

class OnlineGameScreen extends StatefulWidget {
  const OnlineGameScreen({
    required this.client,
    required this.pack,
    this.computerPlayer,
    super.key,
  });
  final OnlineMatchClient client;
  final PiecePack pack;
  final ComputerPlayer? computerPlayer;

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen>
    with WidgetsBindingObserver {
  late BoardAppearance _appearance = BoardAppearance.forPack(widget.pack);

  Future<void> _customize() async {
    final next = await chooseBoardAppearance(context, _appearance);
    if (mounted && next != null) setState(() => _appearance = next);
  }

  Square? _selected;
  Set<Square> _targets = const {};
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
      !_promotionOpen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _computer = widget.computerPlayer ?? ReliableComputerPlayer();
    _lastCapture = _client.session.captureSequence;
    _lastFen = _client.state?.fen;
    _round = _client.state?.round;
    _lastLifelineRequests =
        _client.state?.lifelineRequestsFor(_client.seat) ?? 0;
    _client.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = _client.state;
      if (state != null) _scheduleResult(state);
    });
    _displayTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
    final roundChanged = _round != state?.round;
    final fenChanged = _lastFen != state?.fen;
    if (_lastFen != state?.fen || !_client.connected || roundChanged) {
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
      _battleQueue.clear();
      _battleGapTimer?.cancel();
      _battleGapActive = false;
      _lastBattleEndedAt = null;
      _finishBattle(showNext: false);
    }
    _round = state?.round;
    _lastFen = state?.fen;
    final capture = _client.session.committedCapture;
    if (_client.session.captureSequence != _lastCapture) {
      _lastCapture = _client.session.captureSequence;
      if (_battlesEnabled && capture != null) {
        _queueOrShowBattle(capture);
      }
    }
    setState(() {});
    if (lifelineRequested) unawaited(_generateLifelineHint(state));
    if (state != null) _scheduleResult(state);
  }

  Future<void> _generateLifelineHint(OnlineGameState requestedState) async {
    final fen = requestedState.fen;
    final round = requestedState.round;
    final requestEpoch = ++_hintRequestEpoch;
    setState(() {
      _hintThinking = true;
      _hintFrom = null;
      _hintTo = null;
      _hintMessage = 'Finding the best move…';
    });
    try {
      final suggestion = await _computer.bestMove(
        fen,
        difficulty: ComputerDifficulty.hard,
      );
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
    final state = _client.state;
    if (state == null) return;
    if (_cachedHintFen == state.fen &&
        _cachedHintFrom != null &&
        _cachedHintTo != null) {
      _displayHint(_cachedHintFrom!, _cachedHintTo!, state.fen);
      return;
    }
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
    const delay = Duration(milliseconds: 250);
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
      'timeout' => 'TIME',
      'resignation' => 'RESIGNATION',
      _ when draw => 'DRAW',
      _ => 'GAME OVER',
    };
    final message = draw
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
    unawaited(
      MusicScope.of(context)?.playEffect(
        userWon ? CinematicSound.victoryApplause : CinematicSound.finalStrike,
      ),
    );
    final startNew = await showGameResultDialog(
      context: context,
      outcome: outcome,
      heading: heading,
      title: draw ? 'Game Drawn' : (userWon ? 'You Win!' : 'You Lost'),
      message: message,
    );
    if (mounted && startNew) {
      await _client.startAnotherGame();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _tapSquare(Square square) async {
    _clearLifelineHint();
    if (!_inputEnabled) return;
    final state = _client.state!;
    final piece = state.position.board.pieceAt(square);
    if (_selected == null || piece?.color == state.position.turn) {
      setState(() {
        _selected = piece?.color == state.position.turn ? square : null;
        _targets = _selected == null
            ? const {}
            : _client.session.legalDestinations(_selected!, _client.seat);
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
                              pack: _appearance.army(state.position.turn),
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
    _client.requestMove(from: from, to: square, promotion: promotion);
    setState(() {
      _selected = null;
      _targets = const {};
    });
  }

  Future<void> _resign() async {
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
  ) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Stack(
      children: [
        ChessBoard(
          appearance: _appearance,
          position: state.position,
          selected: _selected,
          legalTargets: _targets,
          accent: accent,
          orientation: side,
          hiddenPieceSquare: _battle?.move.to,
          suggestedFrom: _hintFrom,
          suggestedTo: _hintTo,
          onSquareTap: _tapSquare,
        ),
        if (_battle != null)
          CaptureBattleOverlay(
            appearance: _appearance,
            key: ValueKey(_lastCapture),
            battle: _battle!,
            accent: accent,
            orientation: side,
            reduced: _reduceMotion || MediaQuery.disableAnimationsOf(context),
            fast: _fastBattles,
            useCharacterAsset:
                widget.pack.id == PiecePackId.anime &&
                _battle!.attacker.role == Role.pawn &&
                _battle!.defender?.role == Role.pawn,
            onSkip: _finishBattle,
          ),
      ],
    ),
  );

  List<Widget> _buildStatus(OnlineGameState state, Side side, Color accent) => [
    if (!_showTopBar)
      Align(
        alignment: Alignment.centerRight,
        child: TopBarRestoreButton(
          accent: accent,
          onPressed: () => setState(() => _showTopBar = true),
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
    MatchHeader(
      status: state.statusLabel,
      whiteTime: Duration(milliseconds: _client.session.clockMs('w')),
      blackTime: Duration(milliseconds: _client.session.clockMs('b')),
      turn: state.position.turn,
      accent: accent,
      timed: state.timed,
    ),
    const SizedBox(height: 12),
    Builder(
      builder: (context) {
        final opponent = state.opponentFor(_client.seat ?? 'w');
        return Card(
          key: const ValueKey('online-opponent-profile'),
          child: ListTile(
            leading: OnlineAvatarImage(avatarId: opponent.avatarId, size: 48),
            title: Text(
              opponent.name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              '${onlinePlayerLevel(opponent.level).label} · ${state.timed ? 'Timed game' : 'No timer'}',
            ),
          ),
        );
      },
    ),
    const SizedBox(height: 8),
  ];

  List<Widget> _buildControls(
    BuildContext context,
    OnlineGameState state,
    Side side,
    Color accent,
  ) => [
    Text(
      'You are ${side == Side.white ? 'White' : 'Black'} · Round ${state.round}',
      key: const ValueKey('assigned-seat'),
      textAlign: TextAlign.center,
    ),
    if (_client.busy)
      const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'Waiting for server confirmation…',
          textAlign: TextAlign.center,
        ),
      ),
    if (_client.error != null)
      Text(_client.error!, style: const TextStyle(color: Colors.redAccent)),
    if (state.status == 'active')
      Card(
        key: const ValueKey('online-computer-lifelines'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Computer Lifelines',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  for (var index = 0; index < 3; index++)
                    Icon(
                      Icons.lightbulb,
                      color: index < state.lifelinesFor(_client.seat)
                          ? Colors.amberAccent
                          : Colors.white24,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Highlights the best move for 10 seconds. You still make the move.',
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                key: const ValueKey('use-online-computer-lifeline'),
                onPressed:
                    _inputEnabled &&
                        (state.lifelinesFor(_client.seat) > 0 ||
                            (_cachedHintFen == state.fen &&
                                _cachedHintFrom != null &&
                                _cachedHintTo != null))
                    ? _useOnlineLifeline
                    : null,
                icon: _hintThinking
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.psychology),
                label: Text(
                  state.lifelinesFor(_client.seat) == 0
                      ? 'No lifelines remaining'
                      : 'Suggest best move (${state.lifelinesFor(_client.seat)} left)',
                ),
              ),
              if (_hintMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _hintMessage!,
                    key: const ValueKey('online-computer-hint-message'),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
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
      FilledButton(
        onPressed: _client.canAct && !state.rematchOffers.contains(_client.seat)
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
      },
    ),
    SwitchListTile(
      value: _fastBattles,
      title: const Text('Fast battles'),
      onChanged: (value) => setState(() => _fastBattles = value),
    ),
    SwitchListTile(
      value: _reduceMotion || MediaQuery.disableAnimationsOf(context),
      title: const Text('Reduced motion'),
      subtitle: const Text('Fade only. Game clocks always keep running.'),
      onChanged: MediaQuery.disableAnimationsOf(context)
          ? null
          : (value) => setState(() => _reduceMotion = value),
    ),
    MoveStrip(moves: state.san, accent: accent),
  ];

  @override
  Widget build(BuildContext context) {
    final state = _client.state;
    final accent = _appearance.board.accent;
    final side = _client.seat == 'b' ? Side.black : Side.white;
    return Scaffold(
      backgroundColor: _appearance.board.backdrop,
      appBar: _showTopBar
          ? AppBar(
              title: const Text('Online Match'),
              actions: [
                const MusicButton(),
                IconButton(
                  tooltip: 'Armies & board',
                  onPressed: _customize,
                  icon: const Icon(Icons.palette_outlined),
                ),
                IconButton(
                  tooltip: 'Copy Game ID',
                  icon: const Icon(Icons.copy),
                  onPressed: () => copyGameId(context, _client.gameId),
                ),
                IconButton(
                  tooltip: 'Hide top bar',
                  onPressed: () => setState(() => _showTopBar = false),
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
              ],
            )
          : null,
      body: state == null
          ? const Center(child: Text('Waiting for game state…'))
          : WorldBackdrop(
              pack: _appearance.board,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final landscape =
                            constraints.maxWidth > constraints.maxHeight;
                        final status = _buildStatus(state, side, accent);
                        final controls = _buildControls(
                          context,
                          state,
                          side,
                          accent,
                        );
                        if (landscape) {
                          return Padding(
                            padding: EdgeInsets.all(_showTopBar ? 12 : 8),
                            child: Row(
                              key: const ValueKey('landscape-online-layout'),
                              children: [
                                Expanded(
                                  child: Center(
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: _buildBoard(
                                        context,
                                        state,
                                        side,
                                        accent,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: _showTopBar ? 16 : 8),
                                SizedBox(
                                  width: (constraints.maxWidth * .38)
                                      .clamp(280.0, 440.0)
                                      .toDouble(),
                                  child: ListView(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    children: [...status, ...controls],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: ListView(
                              padding: EdgeInsets.fromLTRB(
                                _showTopBar ? 16 : 8,
                                _showTopBar ? 16 : 8,
                                _showTopBar ? 16 : 8,
                                0,
                              ),
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: _showTopBar ? 0 : 8,
                                  ),
                                  child: Column(children: status),
                                ),
                                AspectRatio(
                                  aspectRatio: 1,
                                  child: _buildBoard(
                                    context,
                                    state,
                                    side,
                                    accent,
                                  ),
                                ),
                                SizedBox(height: _showTopBar ? 8 : 4),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: _showTopBar ? 0 : 8,
                                  ),
                                  child: Column(children: controls),
                                ),
                              ],
                            ),
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
