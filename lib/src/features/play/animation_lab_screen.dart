import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'board_appearance.dart';

import '../../domain/game_session.dart';
import '../../domain/game_result_analysis.dart';
import '../../domain/piece_pack.dart';
import '../../services/theme_music.dart';
import '../../services/computer_player.dart';
import '../../services/last_game_storage.dart';
import 'chess_widgets.dart';
import 'capture_battle_overlay.dart';
import 'checkmate_dialog.dart';

class AnimationLabScreen extends StatefulWidget {
  const AnimationLabScreen({
    required this.pack,
    this.mode = PlayerMode.local,
    this.difficulty = ComputerDifficulty.medium,
    this.savedGame,
    this.computerPlayer,
    super.key,
  });
  final PiecePack pack;
  final PlayerMode mode;
  final ComputerDifficulty difficulty;
  final SavedGame? savedGame;
  final ComputerPlayer? computerPlayer;

  @override
  State<AnimationLabScreen> createState() => _AnimationLabScreenState();
}

class _AnimationLabScreenState extends State<AnimationLabScreen>
    with WidgetsBindingObserver {
  late final GameSession _game;
  ComputerPlayer? _computer;
  Timer? _clockTimer;
  Timer? _battleTimer;
  late BoardAppearance _appearance;

  Future<void> _customize() async {
    final next = await chooseBoardAppearance(context, _appearance);
    if (mounted && next != null) {
      setState(() => _appearance = next);
      unawaited(_saveOpenGame());
    }
  }

  Square? _selected;
  Set<Square> _legalTargets = const {};
  MoveResolution? _battle;
  late bool _fastBattles;
  bool _showTopBar = true;
  bool _computerThinking = false;
  bool _hintThinking = false;
  int _lifelinesRemaining = 3;
  String? _hintMessage;
  late ComputerDifficulty _difficulty;
  String? _computerError;
  late Duration _whiteTime;
  late Duration _blackTime;
  Side? _flagged;
  int _gameEpoch = 0;
  int _ticksSinceSave = 0;
  bool _resultShown = false;

  PiecePack _pack(PiecePackId id) =>
      piecePacks.firstWhere((pack) => pack.id == id);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final saved = widget.savedGame;
    _game = saved == null
        ? GameSession(mode: widget.mode)
        : GameSession.fromMoves(mode: saved.mode, moves: saved.moves);
    _appearance = saved == null
        ? BoardAppearance.forPack(widget.pack)
        : BoardAppearance(
            white: _pack(saved.whitePack),
            black: _pack(saved.blackPack),
            board: _pack(saved.boardPack),
          );
    _difficulty = saved?.difficulty ?? widget.difficulty;
    _lifelinesRemaining = saved?.lifelinesRemaining ?? 3;
    _fastBattles = saved?.fastBattles ?? false;
    _whiteTime = Duration(milliseconds: saved?.whiteMilliseconds ?? 600000);
    _blackTime = Duration(milliseconds: saved?.blackMilliseconds ?? 600000);
    if (widget.mode == PlayerMode.computer) {
      _computer = widget.computerPlayer ?? ReliableComputerPlayer();
    }
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (saved != null && widget.mode == PlayerMode.computer) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybePlayComputer());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_saveOpenGame());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_saveOpenGame());
    _clockTimer?.cancel();
    _battleTimer?.cancel();
    _computer?.dispose();
    super.dispose();
  }

  bool get _inputLocked =>
      _battle != null ||
      _computerThinking ||
      _hintThinking ||
      _flagged != null ||
      _game.position.isGameOver ||
      !_game.isHumanTurn;

  void _tick() {
    if (!mounted || _flagged != null || _game.position.isGameOver) return;
    setState(() {
      if (_game.position.turn == Side.white) {
        _whiteTime -= const Duration(seconds: 1);
        if (_whiteTime <= Duration.zero) {
          _whiteTime = Duration.zero;
          _flagged = Side.white;
        }
      } else {
        _blackTime -= const Duration(seconds: 1);
        if (_blackTime <= Duration.zero) {
          _blackTime = Duration.zero;
          _flagged = Side.black;
        }
      }
    });
    _ticksSinceSave++;
    if (_flagged != null) {
      unawaited(LastGameStorage.clear());
    } else if (_ticksSinceSave >= 5) {
      _ticksSinceSave = 0;
      unawaited(_saveOpenGame());
    }
  }

  Future<void> _saveOpenGame() {
    if (_game.uciMoves.isEmpty ||
        _flagged != null ||
        _game.position.isGameOver) {
      return LastGameStorage.clear();
    }
    return LastGameStorage.save(
      SavedGame(
        mode: widget.mode,
        homePack: widget.pack.id,
        difficulty: _difficulty,
        moves: _game.uciMoves,
        whiteMilliseconds: _whiteTime.inMilliseconds,
        blackMilliseconds: _blackTime.inMilliseconds,
        fastBattles: _fastBattles,
        whitePack: _appearance.white.id,
        blackPack: _appearance.black.id,
        boardPack: _appearance.board.id,
        updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        lifelinesRemaining: _lifelinesRemaining,
      ),
    );
  }

  Future<void> _tapSquare(Square square) async {
    if (_inputLocked) return;
    if (_hintMessage != null) setState(() => _hintMessage = null);
    final piece = _game.pieceAt(square);
    if (_selected == null ||
        (piece != null && piece.color == _game.position.turn)) {
      setState(() {
        _selected = piece?.color == _game.position.turn ? square : null;
        _legalTargets = _selected == null
            ? const {}
            : _game.legalDestinations(_selected!);
      });
      return;
    }
    if (!_legalTargets.contains(square)) return;
    var promotion = Role.queen;
    final movingPiece = _game.pieceAt(_selected!);
    if (movingPiece?.role == Role.pawn &&
        (square.rank == Rank.first || square.rank == Rank.eighth)) {
      promotion = await _choosePromotion() ?? Role.queen;
      if (!mounted) return;
    }
    _commitMove(_game.play(_selected!, square, promotion: promotion));
  }

  Future<Role?> _choosePromotion() => showModalBottomSheet<Role>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose your promoted warrior',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            if (_computer case ReliableComputerPlayer(reducedStrength: true))
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Computer is playing at reduced strength.'),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [Role.queen, Role.rook, Role.bishop, Role.knight].map((
                role,
              ) {
                final piece = Piece(color: _game.position.turn, role: role);
                return IconButton(
                  tooltip: role.name,
                  iconSize: 48,
                  onPressed: () => Navigator.pop(context, role),
                  icon: SizedBox.square(
                    dimension: 48,
                    child: CharacterPiece(
                      piece: piece,
                      pack: _appearance.army(piece.color),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    ),
  );

  void _commitMove(MoveResolution? resolution) {
    if (resolution == null) return;
    setState(() {
      _selected = null;
      _legalTargets = const {};
      _hintMessage = null;
      if (resolution.isCapture) _battle = resolution;
    });
    unawaited(_saveOpenGame());
    if (resolution.isCapture) {
      _battleTimer?.cancel();
      final reduced = MediaQuery.disableAnimationsOf(context);
      _battleTimer = Timer(
        captureBattleDuration(reduced: reduced, fast: _fastBattles) +
            Duration(milliseconds: reduced ? 25 : 100),
        _finishBattle,
      );
    } else {
      _finishTurn();
    }
  }

  void _finishBattle() {
    if (!mounted || _battle == null) return;
    _battleTimer?.cancel();
    setState(() => _battle = null);
    _finishTurn();
  }

  void _finishTurn() {
    if (_game.position.isCheckmate) {
      unawaited(_showCheckmateResult());
    } else {
      _maybePlayComputer();
    }
  }

  Future<void> _showCheckmateResult() async {
    if (!mounted || _resultShown || !_game.position.isCheckmate) return;
    _resultShown = true;
    await LastGameStorage.clear();
    if (!mounted) return;
    unawaited(MusicScope.of(context)?.playEffect(CinematicSound.finalStrike));
    final winner = _game.position.turn.opposite;
    final versusComputer = widget.mode == PlayerMode.computer;
    final userWon = !versusComputer || winner == Side.white;
    final message = analyzeUserGame(
      sanMoves: _game.sanMoves,
      uciMoves: _game.uciMoves,
      userSide: versusComputer ? Side.white : winner,
      userWon: userWon,
    );
    final startNew = await showCheckmateDialog(
      context: context,
      userWon: userWon,
      title: versusComputer
          ? (userWon ? 'You Win!' : 'Computer Wins')
          : '${winner == Side.white ? 'White' : 'Black'} Wins!',
      message: message,
    );
    if (mounted && startNew) await _reset();
  }

  Future<void> _maybePlayComputer() async {
    if (_computer == null ||
        _game.position.turn != Side.black ||
        _game.position.isGameOver ||
        _flagged != null ||
        _computerThinking) {
      return;
    }
    setState(() {
      _computerThinking = true;
      _computerError = null;
    });
    final requestEpoch = _gameEpoch;
    try {
      final move = await _computer!.bestMove(
        _game.position.fen,
        difficulty: _difficulty,
      );
      if (!mounted || requestEpoch != _gameEpoch) return;
      setState(() {
        _computerThinking = false;
        _computerError = move == null
            ? 'Computer engine did not return a move'
            : null;
      });
      if (move != null) {
        _commitMove(_game.playUci(move));
      }
    } catch (_) {
      if (!mounted || requestEpoch != _gameEpoch) return;
      setState(() {
        _computerThinking = false;
        _computerError = 'Computer engine unavailable on this device';
      });
    }
  }

  Future<void> _useComputerLifeline() async {
    if (_computer == null ||
        widget.mode != PlayerMode.computer ||
        _lifelinesRemaining <= 0 ||
        _inputLocked ||
        _game.position.turn != Side.white) {
      return;
    }
    final fen = _game.position.fen;
    final requestEpoch = _gameEpoch;
    setState(() {
      _hintThinking = true;
      _hintMessage = null;
    });
    try {
      final suggestion = await _computer!.bestMove(
        fen,
        difficulty: ComputerDifficulty.hard,
      );
      if (!mounted || requestEpoch != _gameEpoch || _game.position.fen != fen) {
        return;
      }
      final parsed = suggestion == null ? null : Move.parse(suggestion);
      if (parsed case final NormalMove move when _game.position.isLegal(move)) {
        setState(() {
          _hintThinking = false;
          _lifelinesRemaining--;
          _selected = move.from;
          _legalTargets = {move.to};
          _hintMessage = 'Suggested move: ${move.from.name} → ${move.to.name}';
        });
        unawaited(_saveOpenGame());
      } else {
        setState(() {
          _hintThinking = false;
          _hintMessage =
              'A suggestion is unavailable. Your lifeline was not used.';
        });
      }
    } catch (_) {
      if (!mounted || requestEpoch != _gameEpoch) return;
      setState(() {
        _hintThinking = false;
        _hintMessage =
            'A suggestion is unavailable. Your lifeline was not used.';
      });
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a new game?'),
        content: const Text(
          'The current position and its saved progress will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('New Game'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    _battleTimer?.cancel();
    setState(() {
      _gameEpoch++;
      _game.reset();
      _selected = null;
      _legalTargets = const {};
      _battle = null;
      _whiteTime = const Duration(minutes: 10);
      _blackTime = const Duration(minutes: 10);
      _flagged = null;
      _computerError = null;
      _computerThinking = false;
      _hintThinking = false;
      _lifelinesRemaining = 3;
      _hintMessage = null;
      _resultShown = false;
    });
    await LastGameStorage.clear();
  }

  void _undo() {
    if (_computerThinking || _battle != null || !_game.canUndo) return;
    setState(() {
      _game.undo();
      if (widget.mode == PlayerMode.computer && _game.canUndo) _game.undo();
      _selected = null;
      _legalTargets = const {};
      _hintMessage = null;
      _flagged = null;
    });
    unawaited(_saveOpenGame());
  }

  String get _status {
    if (_flagged != null) {
      return '${_flagged == Side.white ? 'White' : 'Black'} ran out of time';
    }
    if (_computerError != null) return _computerError!;
    if (_game.position.isCheckmate) {
      return 'Checkmate · ${_game.position.turn.opposite == Side.white ? 'White' : 'Black'} wins';
    }
    if (_game.position.isStalemate) return 'Draw by stalemate';
    if (_game.position.isInsufficientMaterial) {
      return 'Draw · insufficient material';
    }
    if (_computerThinking) return 'Computer is thinking…';
    final side = _game.position.turn == Side.white ? 'White' : 'Black';
    return '$side to move${_game.position.isCheck ? ' · CHECK' : ''}';
  }

  Widget _buildBoard(BuildContext context, Color accent) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Stack(
      children: [
        ChessBoard(
          appearance: _appearance,
          position: _game.position,
          selected: _selected,
          legalTargets: _legalTargets,
          accent: accent,
          hiddenPieceSquare: _battle?.move.to,
          onSquareTap: _tapSquare,
        ),
        if (_battle != null)
          CaptureBattleOverlay(
            appearance: _appearance,
            battle: _battle!,
            accent: accent,
            orientation: Side.white,
            reduced: MediaQuery.disableAnimationsOf(context),
            fast: _fastBattles,
            useCharacterAsset:
                widget.pack.id == PiecePackId.anime &&
                _battle!.attacker.role == Role.pawn &&
                _battle!.defender!.role == Role.pawn,
            onSkip: _finishBattle,
          ),
      ],
    ),
  );

  List<Widget> _buildMatchDetails(Color accent) => [
    if (!_showTopBar)
      Align(
        alignment: Alignment.centerRight,
        child: TopBarRestoreButton(
          accent: accent,
          onPressed: () => setState(() => _showTopBar = true),
        ),
      ),
    if (!_showTopBar) const SizedBox(height: 4),
    MatchHeader(
      status: _status,
      whiteTime: _whiteTime,
      blackTime: _blackTime,
      turn: _game.position.turn,
      accent: accent,
    ),
    const SizedBox(height: 12),
    if (_computerError != null && !_computerThinking)
      TextButton.icon(
        onPressed: _maybePlayComputer,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry computer move'),
      ),
    if (widget.mode == PlayerMode.computer)
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Icon(Icons.tune, color: accent),
        title: const Text('Computer difficulty'),
        subtitle: Text(_difficulty.description),
        trailing: DropdownButton<ComputerDifficulty>(
          key: const ValueKey('match-difficulty-selector'),
          value: _difficulty,
          underline: const SizedBox.shrink(),
          items: [
            for (final difficulty in ComputerDifficulty.values)
              DropdownMenuItem(
                value: difficulty,
                child: Text(difficulty.label),
              ),
          ],
          onChanged: _computerThinking
              ? null
              : (difficulty) {
                  if (difficulty != null) {
                    setState(() => _difficulty = difficulty);
                    unawaited(_saveOpenGame());
                  }
                },
        ),
      ),
    if (widget.mode == PlayerMode.computer)
      Card(
        key: const ValueKey('computer-lifelines'),
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
                      color: index < _lifelinesRemaining
                          ? Colors.amberAccent
                          : Colors.white24,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Highlights the best move. You still make the move.'),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                key: const ValueKey('use-computer-lifeline'),
                onPressed: _lifelinesRemaining > 0 && !_inputLocked
                    ? _useComputerLifeline
                    : null,
                icon: _hintThinking
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.psychology),
                label: Text(
                  _lifelinesRemaining == 0
                      ? 'No lifelines remaining'
                      : 'Suggest best move ($_lifelinesRemaining left)',
                ),
              ),
              if (_hintMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _hintMessage!,
                    key: const ValueKey('computer-hint-message'),
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
    SwitchListTile(
      value: _fastBattles,
      onChanged: (value) {
        setState(() => _fastBattles = value);
        unawaited(_saveOpenGame());
      },
      activeThumbColor: accent,
      title: const Text('Fast battle mode'),
      subtitle: const Text('Shortens capture cinematics; clocks keep running'),
    ),
    const SizedBox(height: 8),
    MoveStrip(moves: _game.sanMoves, accent: accent),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = _appearance.board.accent;
    return Scaffold(
      backgroundColor: _appearance.board.backdrop,
      appBar: _showTopBar
          ? AppBar(
              title: Text(
                widget.mode == PlayerMode.computer
                    ? '${widget.pack.name} · vs Computer'
                    : '${widget.pack.name} · Local Match',
              ),
              actions: [
                const MusicButton(),
                IconButton(
                  tooltip: 'Armies & board',
                  onPressed: _customize,
                  icon: const Icon(Icons.palette_outlined),
                ),
                IconButton(
                  tooltip: 'Undo',
                  onPressed: _game.canUndo ? _undo : null,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: 'New game',
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Hide top bar',
                  onPressed: () => setState(() => _showTopBar = false),
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
              ],
            )
          : null,
      body: WorldBackdrop(
        pack: _appearance.board,
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final landscape =
                      constraints.maxWidth > constraints.maxHeight;
                  if (landscape) {
                    return Padding(
                      padding: EdgeInsets.all(_showTopBar ? 12 : 8),
                      child: Row(
                        key: const ValueKey('landscape-match-layout'),
                        children: [
                          Expanded(
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: _buildBoard(context, accent),
                              ),
                            ),
                          ),
                          SizedBox(width: _showTopBar ? 16 : 8),
                          SizedBox(
                            width: (constraints.maxWidth * .36)
                                .clamp(280.0, 420.0)
                                .toDouble(),
                            child: ListView(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              children: _buildMatchDetails(accent),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final topCount =
                      2 +
                      (_showTopBar ? 0 : 2) +
                      (_computerError != null && !_computerThinking ? 1 : 0);
                  return ListView(
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
                        child: Column(
                          children: _buildMatchDetails(
                            accent,
                          ).take(topCount).toList(),
                        ),
                      ),
                      SizedBox(height: _showTopBar ? 2 : 0),
                      AspectRatio(
                        aspectRatio: 1,
                        child: _buildBoard(context, accent),
                      ),
                      SizedBox(height: _showTopBar ? 12 : 4),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: _showTopBar ? 0 : 8,
                        ),
                        child: Column(
                          children: _buildMatchDetails(
                            accent,
                          ).skip(topCount).toList(),
                        ),
                      ),
                    ],
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
