import 'dart:async';
import '../../domain/game_time_control.dart';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import 'board_appearance.dart';
import '../../services/custom_chess_sets.dart';
import '../../services/custom_set_actions.dart';
import '../../domain/bot_tournament.dart';
import '../../domain/capture_threat.dart';
import '../online/online_avatar_image.dart';
import '../tournaments/tournament_match_config.dart';
import '../tournaments/championship_celebration.dart';

import '../../domain/game_session.dart';
import '../../domain/game_result_analysis.dart';
import '../../domain/piece_pack.dart';
import '../../domain/player_progress.dart';
import '../../domain/online_credits.dart';
import '../../domain/online_player_profile.dart';
import '../../services/arena_credit_controller.dart';
import '../../services/theme_music.dart';
import '../../services/computer_player.dart';
import '../../services/last_game_storage.dart';
import '../../services/app_diagnostics.dart';
import '../../services/game_display_settings.dart';
import '../../services/player_progress_controller.dart';
import '../settings/game_settings_sheet.dart';
import '../settings/board_color_settings.dart';
import '../credits/arena_credit_header.dart';
import '../credits/credit_balance_chip.dart';
import 'captured_pieces_panel.dart';
import 'chess_widgets.dart';
import 'capture_battle_overlay.dart';
import 'checkmate_dialog.dart';
import 'threat_scan.dart';
import 'play_assist_style.dart';
import 'player_side_selector.dart';

class AnimationLabScreen extends StatefulWidget {
  /// Test-only virtual time. Release builds always use a monotonic stopwatch.
  @visibleForTesting
  static Stopwatch Function()? debugClockFactory;

  const AnimationLabScreen({
    required this.pack,
    this.mode = PlayerMode.local,
    this.humanSide = Side.white,
    this.timeControl = GameTimeControl.rapid,
    this.difficulty = ComputerDifficulty.medium,
    this.savedGame,
    this.computerPlayer,
    this.tournamentMatch,
    this.initialClassicPieces = false,
    this.initialClassicStyle = ClassicPieceStyle.magneticTeaching,
    super.key,
  });
  final PiecePack pack;
  final PlayerMode mode;
  final Side humanSide;
  final GameTimeControl timeControl;
  final ComputerDifficulty difficulty;
  final SavedGame? savedGame;
  final ComputerPlayer? computerPlayer;
  final TournamentMatchConfig? tournamentMatch;
  final bool initialClassicPieces;
  final ClassicPieceStyle initialClassicStyle;

  @override
  State<AnimationLabScreen> createState() => _AnimationLabScreenState();
}

class _AnimationLabScreenState extends State<AnimationLabScreen>
    with WidgetsBindingObserver {
  late final GameSession _game;
  late GameTimeControl _timeControl;
  ComputerPlayer? _computer;
  Timer? _clockTimer;
  late final Stopwatch _clockElapsed;
  int _lastClockElapsedMs = 0;
  Timer? _battleTimer;
  Timer? _computerReplyTimer;
  late BoardAppearance _appearance;
  bool _classicPieces = false;
  late ClassicPieceStyle _classicStyle;
  final _threats = ThreatScanController();
  final _threatBoardKey = GlobalKey();
  final _boardScroll = ScrollController();
  final _displaySettings = GameDisplaySettings();
  bool get _isConquest => widget.tournamentMatch?.cup.isConquest == true;
  PiecePack get _conquestOpponent => widget.pack;

  AvatarVoice get _opponentVoice =>
      avatarVoice(widget.tournamentMatch?.opponent.avatarId);

  void _refreshThreats() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _threats.setReducedMotion(MediaQuery.disableAnimationsOf(context));
  }

  void _analyseThreats() {
    if (_inputLocked || _game.isRuleDraw) return;
    setState(() {
      _selected = null;
      _legalTargets = const {};
      _hintMessage = null;
      _hintFrom = null;
      _hintTo = null;
    });
    _threats.start(
      immediateCaptureThreats(_game.position, defender: _game.position.turn),
      reducedMotion: MediaQuery.disableAnimationsOf(context),
    );
  }

  BoardAppearance get _displayAppearance {
    final base = BoardAppearance(
      white: _appearance.white,
      black: _isConquest ? _conquestOpponent : _appearance.black,
      board: _appearance.board,
      standardPieces: _classicPieces,
      classicStyle: _classicStyle,
    );
    // Conquests begin with their army artwork, never a global custom-set override.
    var result = _isConquest
        ? base
        : base.withCustomSet(CustomChessSetScope.maybeOf(context)?.active);
    if (_displaySettings.customBoardColorsEnabled) {
      result = result.withBoardColors(
        _displaySettings.boardLightSquare,
        _displaySettings.boardDarkSquare,
      );
    }
    return result;
  }

  void _toggleBoardColors() => unawaited(_displaySettings.toggleBoardColors());

  Future<void> _togglePieceStyle() async {
    if (!await restoreBuiltInChessSet(context) || !mounted) return;
    _threats.stop();
    setState(() => _classicPieces = !_classicPieces);
    unawaited(_saveOpenGame());
  }

  Future<void> _swipeChessSet(int direction) async {
    if (_battle != null) return;
    if (!await restoreBuiltInChessSet(context) || !mounted) return;
    _threats.stop();
    setState(() {
      if (_classicPieces) {
        const styles = ClassicPieceStyle.values;
        _classicStyle =
            styles[(styles.indexOf(_classicStyle) + direction) % styles.length];
      } else {
        final index = piecePacks.indexWhere(
          (p) => p.id == _appearance.white.id,
        );
        final next = piecePacks[(index + direction) % piecePacks.length];
        _appearance = _isConquest
            ? BoardAppearance(
                white: next,
                black: _conquestOpponent,
                board: _appearance.board,
              )
            : BoardAppearance.forPack(next);
      }
    });
    await _saveOpenGame();
  }

  Future<void> _customize() async {
    _threats.stop();
    final next = await chooseBoardAppearance(
      context,
      _displayAppearance,
      lockedBlack: _isConquest ? _conquestOpponent : null,
      lockedBlackReason: _isConquest
          ? '${_conquestOpponent.name} is fixed for this conquest round. Change only your White themed army, or use Classic pieces.'
          : null,
    );
    if (mounted && next != null) {
      if (!await restoreBuiltInChessSet(context) || !mounted) return;
      setState(() {
        _appearance = _isConquest
            ? BoardAppearance(
                white: next.white,
                black: _conquestOpponent,
                board: next.board,
              )
            : next;
        _classicPieces = next.standardPieces;
        _classicStyle = next.classicStyle;
      });
      unawaited(_saveOpenGame());
    }
  }

  void _openSettings() {
    _threats.stop();
    unawaited(
      showGameSettings(
        context: context,
        display: _displaySettings,
        onCustomize: _customize,
        onReset: () async {
          if (!mounted) return;
          setState(() {
            _appearance = _isConquest
                ? BoardAppearance(
                    white: piecePacks.first,
                    black: _conquestOpponent,
                    board: _conquestOpponent,
                  )
                : BoardAppearance.forPack(piecePacks.first);
            _classicPieces = false;
            _classicStyle = ClassicPieceStyle.magneticTeaching;
            _fastBattles = false;
            _showTopBar = true;
            if (widget.tournamentMatch == null) {
              _difficulty = ComputerDifficulty.medium;
            }
          });
          await _saveOpenGame();
        },
        controls: (refresh) => [
          if (widget.mode == PlayerMode.computer) ...[
            if (widget.tournamentMatch == null)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('New game'),
                onTap: () {
                  Navigator.pop(context);
                  _reset();
                },
              ),
            ListTile(
              leading: const Icon(Icons.fullscreen),
              title: const Text('Hide top bar'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _showTopBar = false);
              },
            ),
          ],
          if (widget.mode == PlayerMode.computer &&
              widget.tournamentMatch == null)
            SettingsChoiceTile<ComputerDifficulty>(
              key: const ValueKey('match-difficulty-selector'),
              title: 'Computer difficulty',
              icon: Icons.psychology_outlined,
              value: _difficulty,
              values: ComputerDifficulty.values,
              optionLabel: (difficulty) => difficulty.label,
              enabled: !_computerThinking,
              onSelected: (difficulty) {
                setState(() => _difficulty = difficulty);
                refresh();
                unawaited(_saveOpenGame());
              },
            ),
          if (widget.tournamentMatch != null)
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(
                widget.tournamentMatch!.cup.isConquest
                    ? 'Conquest difficulty (fixed for this game)'
                    : 'Tournament difficulty',
              ),
              subtitle: Text(widget.tournamentMatch!.opponent.difficultyLabel),
            ),
          SwitchListTile(
            value: _fastBattles,
            onChanged: (value) {
              setState(() => _fastBattles = value);
              refresh();
              unawaited(_saveOpenGame());
            },
            title: const Text('Fast battle mode'),
            subtitle: const Text(
              'Shortens capture cinematics; clocks keep running',
            ),
          ),
          SwitchListTile(
            key: const ValueKey('classic-pieces-toggle'),
            value: _classicPieces,
            onChanged: (value) async {
              if (!await restoreBuiltInChessSet(context) || !mounted) return;
              setState(() => _classicPieces = value);
              refresh();
              unawaited(_saveOpenGame());
            },
            secondary: const Icon(Icons.castle_outlined),
            title: const Text('Classic chess pieces'),
            subtitle: Text(_classicStyle.label),
          ),
          if (_classicPieces)
            SettingsChoiceTile<ClassicPieceStyle>(
              key: const ValueKey('classic-piece-style-selector'),
              title: 'Classic set',
              icon: Icons.castle_outlined,
              value: _classicStyle,
              values: ClassicPieceStyle.values,
              optionLabel: (style) => style.label,
              optionDescription: (style) => style.subtitle,
              onSelected: (style) async {
                if (!await restoreBuiltInChessSet(context) || !mounted) {
                  return;
                }
                setState(() => _classicStyle = style);
                refresh();
                unawaited(_saveOpenGame());
              },
            ),
        ],
      ),
    );
  }

  Square? _selected;
  Set<Square> _legalTargets = const {};
  Square? _hintFrom;
  Square? _hintTo;
  MoveResolution? _battle;
  late bool _fastBattles;
  bool _showTopBar = true;
  bool _computerThinking = false;
  bool _computerReplyDelay = false;
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
  bool _resigned = false;
  bool _tournamentPaused = false;
  bool _leavingTournament = false;
  bool _canLeaveTournament = false;
  String? _tournamentSaveError;
  late String _progressGameId;

  TournamentRoundResult? get _tournamentResult {
    if (widget.tournamentMatch == null) return null;
    if (_resigned || _flagged == _game.humanSide) {
      return TournamentRoundResult.loss;
    }
    if (_flagged == _game.humanSide.opposite) return TournamentRoundResult.win;
    if (_game.position.isCheckmate) {
      return _game.position.turn == _game.humanSide.opposite
          ? TournamentRoundResult.win
          : TournamentRoundResult.loss;
    }
    if (_game.position.isGameOver || _game.isRuleDraw) {
      return TournamentRoundResult.draw;
    }
    return null;
  }

  PiecePack _pack(PiecePackId id) =>
      piecePacks.firstWhere((pack) => pack.id == id);

  @override
  void initState() {
    super.initState();
    var clock = Stopwatch();
    assert(() {
      clock = AnimationLabScreen.debugClockFactory?.call() ?? clock;
      return true;
    }());
    _clockElapsed = clock;
    WidgetsBinding.instance.addObserver(this);
    _threats.addListener(_refreshThreats);
    _displaySettings.addListener(_refreshThreats);
    final saved = widget.savedGame;
    _progressGameId =
        saved?.progressGameId ??
        'offline-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
    _classicPieces = saved?.classicPieces ?? widget.initialClassicPieces;
    _classicStyle = saved?.classicStyle ?? widget.initialClassicStyle;
    _game = saved == null
        ? GameSession(mode: widget.mode, humanSide: widget.humanSide)
        : GameSession.fromMoves(
            mode: saved.mode,
            humanSide: saved.humanSide,
            moves: saved.moves,
          );
    _appearance = saved == null
        ? (_isConquest
              ? BoardAppearance(
                  white: piecePacks.first,
                  black: _conquestOpponent,
                  board: _conquestOpponent,
                )
              : BoardAppearance.forPack(widget.pack))
        : BoardAppearance(
            white: _pack(saved.whitePack),
            black: _isConquest ? _conquestOpponent : _pack(saved.blackPack),
            board: _pack(saved.boardPack),
          );
    _difficulty = widget.tournamentMatch == null
        ? saved?.difficulty ?? widget.difficulty
        : tournamentDifficulty(widget.tournamentMatch!.opponent.level);
    _lifelinesRemaining = saved?.lifelinesRemaining ?? 3;
    _fastBattles = saved?.fastBattles ?? false;
    _timeControl =
        saved?.timeControl ??
        (widget.tournamentMatch == null
            ? widget.timeControl
            : GameTimeControl(
                baseMs: widget.tournamentMatch!.minutesPerSide * 60000,
              ));
    final initialMs = _timeControl.baseMs;
    _whiteTime = Duration(milliseconds: saved?.whiteMilliseconds ?? initialMs);
    _blackTime = Duration(milliseconds: saved?.blackMilliseconds ?? initialMs);
    if (widget.mode == PlayerMode.computer) {
      _computer = widget.computerPlayer ?? ReliableComputerPlayer();
    }
    _clockElapsed.start();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (widget.mode == PlayerMode.computer) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybePlayComputer());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _threats.stop();
    if (widget.tournamentMatch != null) {
      _tick();
      _tournamentPaused = state != AppLifecycleState.resumed;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_saveOpenGame());
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
    unawaited(_saveOpenGame());
    _clockTimer?.cancel();
    _clockElapsed.stop();
    _battleTimer?.cancel();
    _computerReplyTimer?.cancel();
    _computer?.dispose();
    super.dispose();
  }

  bool get _inputLocked =>
      _battle != null ||
      _computerReplyDelay ||
      _computerThinking ||
      _hintThinking ||
      _leavingTournament ||
      _resigned ||
      _tournamentResult != null ||
      _flagged != null ||
      _game.position.isGameOver ||
      !_game.isHumanTurn;

  void _tick() {
    final now = _clockElapsed.elapsedMilliseconds;
    final elapsed = Duration(milliseconds: now - _lastClockElapsedMs);
    _lastClockElapsedMs = now;
    if (!mounted ||
        !_timeControl.timed ||
        _flagged != null ||
        _game.position.isGameOver ||
        _resigned ||
        _tournamentResult != null ||
        _tournamentPaused ||
        _leavingTournament) {
      return;
    }
    setState(() {
      if (_game.position.turn == Side.white) {
        _whiteTime -= elapsed;
        if (_whiteTime <= Duration.zero) {
          _whiteTime = Duration.zero;
          _flagged = Side.white;
        }
      } else {
        _blackTime -= elapsed;
        if (_blackTime <= Duration.zero) {
          _blackTime = Duration.zero;
          _flagged = Side.black;
        }
      }
    });
    _ticksSinceSave++;
    if (_flagged != null) {
      _threats.stop();
      if (widget.tournamentMatch != null) {
        _gameEpoch++;
        unawaited(_showTournamentResult());
      } else {
        unawaited(LastGameStorage.clear());
        unawaited(_showTimeoutResult());
      }
    } else if (_ticksSinceSave >= 5) {
      _ticksSinceSave = 0;
      unawaited(_saveOpenGame());
    }
  }

  Future<void> _saveOpenGame() async {
    if (widget.tournamentMatch == null &&
        (_game.uciMoves.isEmpty ||
            _flagged != null ||
            _game.position.isGameOver)) {
      return LastGameStorage.clear();
    }
    final saved = SavedGame(
      mode: widget.mode,
      humanSide: _game.humanSide,
      homePack: widget.pack.id,
      difficulty: _difficulty,
      moves: _game.uciMoves,
      whiteMilliseconds: _whiteTime.inMilliseconds,
      blackMilliseconds: _blackTime.inMilliseconds,
      fastBattles: _fastBattles,
      whitePack: _appearance.white.id,
      blackPack: (_isConquest ? _conquestOpponent : _appearance.black).id,
      boardPack: _appearance.board.id,
      updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      lifelinesRemaining: _lifelinesRemaining,
      classicPieces: _classicPieces,
      classicStyle: _classicStyle,
      timeControl: _timeControl,
      progressGameId: _progressGameId,
    );
    final tournament = widget.tournamentMatch;
    if (tournament == null) return LastGameStorage.save(saved);
    try {
      await tournament.save(saved, _tournamentResult);
      if (mounted && _tournamentSaveError != null) {
        setState(() => _tournamentSaveError = null);
      }
    } catch (error, stack) {
      AppDiagnostics.instance.record(
        DiagnosticSource.tournamentSave,
        error,
        stack,
      );
      if (mounted) {
        setState(
          () => _tournamentSaveError =
              'Could not save tournament progress. Please retry.',
        );
      }
    }
  }

  Future<void> _leaveTournament() async {
    _threats.stop();
    if (_leavingTournament) return;
    setState(() => _leavingTournament = true);
    await _saveOpenGame();
    if (!mounted) return;
    if (_tournamentSaveError != null) {
      setState(() => _leavingTournament = false);
      return;
    }
    // Allow the PopScope to rebuild before popping the saved match.
    setState(() => _canLeaveTournament = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _resignTournamentRound() async {
    _threats.stop();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resign this round?'),
        content: const Text(
          'Your earlier wins stay saved. You can retry this opponent at any time.',
        ),
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
    if (!mounted || confirmed != true || _tournamentResult != null) return;
    setState(() {
      _resigned = true;
      _gameEpoch++;
    });
    await _showTournamentResult();
  }

  Future<void> _showTournamentResult() async {
    final result = _tournamentResult;
    if (!mounted || _resultShown || _leavingTournament || result == null) {
      return;
    }
    _resultShown = true;
    await _saveOpenGame();
    if (!mounted) return;
    if (_tournamentSaveError != null) {
      _resultShown = false;
      return;
    }
    final won = result == TournamentRoundResult.win;
    final draw = result == TournamentRoundResult.draw;
    final match = widget.tournamentMatch!;
    final progressAward = await _recordProgress(won: won);
    if (!mounted) return;
    if (won && match.isFinal) {
      final returnToCup = await showChampionshipCelebration(
        context: context,
        cup: match.cup,
        voice: _opponentVoice,
        checkmate: _game.position.isCheckmate,
        progressAward: progressAward,
      );
      if (mounted && returnToCup) await _leaveTournament();
      return;
    }
    final checkmate = _game.position.isCheckmate;
    if (won) {
      unawaited(
        MusicScope.of(
          context,
        )?.announceVictory(voice: _opponentVoice, checkmate: checkmate),
      );
    } else if (checkmate) {
      unawaited(
        MusicScope.of(context)?.announceCheckmateLoss(voice: _opponentVoice),
      );
    }
    final returnToCup = await showGameResultDialog(
      context: context,
      outcome: won
          ? GameResultOutcome.victory
          : draw
          ? GameResultOutcome.draw
          : GameResultOutcome.defeat,
      heading: _flagged != null
          ? 'TIMEOUT'
          : _resigned
          ? 'RESIGNED'
          : draw
          ? 'DRAW'
          : 'CHECKMATE',
      title: won
          ? 'Round won!'
          : draw
          ? 'Round drawn'
          : '${widget.tournamentMatch!.opponent.name} wins',
      message: GameResultMessage(
        sentiment: won
            ? '+${match.cup.pointsPerWin} points added to your ${match.cup.isConquest ? "conquest" : "tournament"} total!'
            : 'Your ${match.cup.isConquest ? "conquest" : "tournament"} journey continues.',
        comment: won
            ? '${(match.roundIndex + 1) * match.cup.pointsPerWin} cup points earned. Your next opponent awaits on the trophy trail.'
            : 'Retry this round against the same opponent now or whenever you return. Your earlier wins are safe.',
      ),
      primaryLabel: match.cup.isConquest ? 'Conquest' : 'Tournament',
      progressAward: progressAward,
    );
    if (mounted && returnToCup) await _leaveTournament();
  }

  Future<void> _tapSquare(Square square) async {
    if (_inputLocked) return;
    _threats.stop();
    if (_hintMessage != null || _hintFrom != null || _hintTo != null) {
      setState(() {
        _hintMessage = null;
        _hintFrom = null;
        _hintTo = null;
      });
    }
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
    _tick();
    if (_flagged != null) return;
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
                      pack: _displayAppearance.army(piece.color),
                      standard: _displayAppearance.standardPieces,
                      classicStyle: _displayAppearance.classicStyle,
                      customSet: _displayAppearance.customSet,
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
    if (_timeControl.timed) {
      final increment = Duration(milliseconds: _timeControl.incrementMs);
      if (_game.position.turn == Side.black) {
        _whiteTime += increment;
      } else {
        _blackTime += increment;
      }
    }
    _threats.stop();
    setState(() {
      _selected = null;
      _legalTargets = const {};
      _hintMessage = null;
      _hintFrom = null;
      _hintTo = null;
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
    MusicScope.of(context)?.resumeBackground();
    if (widget.mode == PlayerMode.computer &&
        _game.position.turn == _game.humanSide.opposite &&
        _tournamentResult == null &&
        !_game.position.isGameOver) {
      _computerReplyTimer?.cancel();
      setState(() => _computerReplyDelay = true);
      _computerReplyTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _computerReplyDelay = false);
        _finishTurn();
      });
      return;
    }
    _finishTurn();
  }

  void _finishTurn() {
    if (_tournamentResult != null) {
      unawaited(_showTournamentResult());
      return;
    }
    if (_game.position.isCheckmate) {
      unawaited(_showCheckmateResult());
    } else if (_game.position.isGameOver || _game.isRuleDraw) {
      unawaited(_showDrawResult());
    } else {
      if (_game.position.isCheck) {
        unawaited(MusicScope.of(context)?.announceCheck(voice: _opponentVoice));
      }
      _maybePlayComputer();
    }
  }

  Future<void> _showDrawResult() async {
    if (!mounted || _resultShown) return;
    _resultShown = true;
    await LastGameStorage.clear();
    if (!mounted) return;
    final progressAward = await _recordProgress(won: false);
    if (!mounted) return;
    final startNew = await showGameResultDialog(
      context: context,
      outcome: GameResultOutcome.draw,
      heading: 'DRAW',
      title: 'Game Drawn',
      message: const GameResultMessage(
        sentiment: 'A hard-fought draw. Experience still counts.',
        comment:
            'Both sides held their ground. Review the final position and prepare for the next battle.',
      ),
      progressAward: progressAward,
    );
    if (mounted && startNew) await _reset();
  }

  Future<void> _showCheckmateResult() async {
    if (!mounted || _resultShown || !_game.position.isCheckmate) return;
    _resultShown = true;
    await LastGameStorage.clear();
    if (!mounted) return;
    final winner = _game.position.turn.opposite;
    final versusComputer = widget.mode == PlayerMode.computer;
    final userWon = !versusComputer || winner == _game.humanSide;
    unawaited(
      userWon
          ? MusicScope.of(
              context,
            )?.announceVictory(voice: _opponentVoice, checkmate: true)
          : MusicScope.of(
              context,
            )?.announceCheckmateLoss(voice: _opponentVoice),
    );
    final message = analyzeUserGame(
      sanMoves: _game.sanMoves,
      uciMoves: _game.uciMoves,
      userSide: versusComputer ? _game.humanSide : winner,
      userWon: userWon,
    );
    final progressAward = await _recordProgress(won: userWon);
    if (!mounted) return;
    final startNew = await showCheckmateDialog(
      context: context,
      userWon: userWon,
      title: versusComputer
          ? (userWon ? 'You Win!' : 'Computer Wins')
          : '${winner == Side.white ? 'White' : 'Black'} Wins!',
      message: message,
      progressAward: progressAward,
    );
    if (mounted && startNew) await _reset();
  }

  Future<void> _showTimeoutResult() async {
    final flagged = _flagged;
    if (!mounted || _resultShown || flagged == null) return;
    _resultShown = true;
    await LastGameStorage.clear();
    if (!mounted) return;
    final winner = flagged.opposite;
    final versusComputer = widget.mode == PlayerMode.computer;
    final userWon = !versusComputer || winner == _game.humanSide;
    unawaited(
      userWon
          ? MusicScope.of(context)?.announceVictory(voice: _opponentVoice)
          : MusicScope.of(context)?.playEffect(CinematicSound.finalStrike),
    );
    final message = userWon
        ? const GameResultMessage(
            sentiment: 'Victory on the clock! You held your nerve.',
            comment:
                'You managed the pressure and kept enough time to claim the arena.',
          )
        : const GameResultMessage(
            sentiment: 'Time ran out, but the next battle awaits.',
            comment:
                'Play the critical positions a little faster and keep time for the finish.',
          );
    final progressAward = await _recordProgress(won: userWon);
    if (!mounted) return;
    final startNew = await showGameResultDialog(
      context: context,
      outcome: userWon ? GameResultOutcome.victory : GameResultOutcome.defeat,
      heading: 'WINNER BY TIMEOUT',
      title: versusComputer
          ? (userWon ? 'You Win!' : 'Computer Wins')
          : '${winner == Side.white ? 'White' : 'Black'} Wins!',
      message: message,
      progressAward: progressAward,
    );
    if (mounted && startNew) await _reset();
  }

  Future<void> _maybePlayComputer() async {
    if (!mounted ||
        _computer == null ||
        _game.position.turn != _game.humanSide.opposite ||
        _game.position.isGameOver ||
        _flagged != null ||
        _resigned ||
        _leavingTournament ||
        _tournamentResult != null ||
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
        botLevel: widget.tournamentMatch?.opponent.botLevel,
      );
      if (!mounted ||
          requestEpoch != _gameEpoch ||
          _flagged != null ||
          _leavingTournament) {
        return;
      }
      setState(() {
        _computerThinking = false;
        _computerError = move == null
            ? 'Computer engine did not return a move'
            : null;
      });
      if (move != null) {
        _tick();
        if (_flagged != null) return;
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
        _inputLocked ||
        _game.position.turn != _game.humanSide) {
      return;
    }
    final fen = _game.position.fen;
    final requestEpoch = _gameEpoch;
    _threats.stop();
    setState(() {
      _hintThinking = true;
      _hintMessage = null;
      _hintFrom = null;
      _hintTo = null;
    });
    try {
      final suggestion = await _computer!.bestMove(
        fen,
        difficulty: suggestionDifficulty,
      );
      if (!mounted || requestEpoch != _gameEpoch || _game.position.fen != fen) {
        return;
      }
      final parsed = suggestion == null ? null : Move.parse(suggestion);
      if (parsed case final NormalMove move when _game.position.isLegal(move)) {
        final wallet = ArenaCreditScope.maybeOf(context);
        if (wallet != null &&
            !wallet.trySpendLocal(
              cost: _suggestionCreditCost,
              reason: 'move_suggestion',
            )) {
          setState(() {
            _hintThinking = false;
            _hintMessage =
                'You need $_suggestionCreditCost credit${_suggestionCreditCost == 1 ? '' : 's'} for a move suggestion.';
          });
          return;
        }
        setState(() {
          _hintThinking = false;
          _selected = null;
          _legalTargets = const {};
          _hintFrom = move.from;
          _hintTo = move.to;
          _hintMessage = 'Suggested move: ${move.from.name} → ${move.to.name}';
        });
        unawaited(_saveOpenGame());
      } else {
        setState(() {
          _hintThinking = false;
          _hintMessage = 'A suggestion is unavailable. Please try again.';
        });
      }
    } catch (_) {
      if (!mounted || requestEpoch != _gameEpoch) return;
      setState(() {
        _hintThinking = false;
        _hintMessage = 'A suggestion is unavailable. Please try again.';
      });
    }
  }

  int get _suggestionCreditCost =>
      ArenaCreditScope.maybeOf(context)?.policy.onlineMoveSuggestionCost ??
      defaultOnlineCreditPolicy.onlineMoveSuggestionCost;

  Future<void> _reset() async {
    _threats.stop();
    var humanSide = _game.humanSide;
    var nextTimeControl = GameTimeControl.rapid;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          scrollable: true,
          title: const Text('Start a new game?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'The current position and its saved progress will be permanently deleted.',
              ),
              if (widget.mode == PlayerMode.computer) ...[
                const SizedBox(height: 16),
                PlayerSideSelector(
                  side: humanSide,
                  onChanged: (side) => update(() => humanSide = side),
                ),
                DropdownButtonFormField<GameTimeControl>(
                  isExpanded: true,
                  initialValue: nextTimeControl,
                  decoration: const InputDecoration(labelText: 'Game clock'),
                  items: const [
                    DropdownMenuItem(
                      value: GameTimeControl.rapid,
                      child: Text('Rapid · 15 + 10 sec'),
                    ),
                    DropdownMenuItem(
                      value: GameTimeControl.practice,
                      child: Text('Untimed Practice'),
                    ),
                  ],
                  onChanged: (value) => update(() => nextTimeControl = value!),
                ),
              ],
            ],
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
      ),
    );
    if (!mounted || confirmed != true) return;
    _battleTimer?.cancel();
    _computerReplyTimer?.cancel();
    setState(() {
      _gameEpoch++;
      _progressGameId =
          'offline-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
      _game.reset();
      _timeControl = nextTimeControl;
      _lastClockElapsedMs = _clockElapsed.elapsedMilliseconds;
      _game.humanSide = humanSide;
      _selected = null;
      _legalTargets = const {};
      _battle = null;
      _computerReplyDelay = false;
      _whiteTime = Duration(milliseconds: _timeControl.baseMs);
      _blackTime = Duration(milliseconds: _timeControl.baseMs);
      _flagged = null;
      _computerError = null;
      _computerThinking = false;
      _hintThinking = false;
      _lifelinesRemaining = 3;
      _hintMessage = null;
      _hintFrom = null;
      _hintTo = null;
      _resultShown = false;
    });
    await LastGameStorage.clear();
    if (mounted) await _maybePlayComputer();
  }

  Future<ProgressAward?> _recordProgress({required bool won}) async {
    final controller = PlayerProgressScope.maybeOf(context);
    if (controller == null) return null;
    final credits = ArenaCreditScope.maybeOf(context);
    final award = await controller.recordCompletion(
      completionId: _progressGameId,
      moveCount: _game.uciMoves.length,
      won: won,
    );
    final unlocked = award.unlockedBadge;
    if (unlocked == null || credits == null) return award;
    final reward = await credits.grantBadgeUpgradeCredits(unlocked);
    return award.withBadgeCredits(reward);
  }

  void _undo() {
    if (_computerThinking || _hintThinking || _battle != null || !_canUndo) {
      return;
    }
    _threats.stop();
    setState(() {
      _undoMoveAndIncrement();
      if (widget.mode == PlayerMode.computer &&
          !_game.isHumanTurn &&
          _game.canUndo) {
        _undoMoveAndIncrement();
      }
      _selected = null;
      _legalTargets = const {};
      _hintMessage = null;
      _hintFrom = null;
      _hintTo = null;
      _flagged = null;
    });
    unawaited(_saveOpenGame());
    unawaited(_maybePlayComputer());
  }

  // Undo revokes increments without refunding thinking time.
  void _undoMoveAndIncrement() {
    _game.undo();
    if (!_timeControl.timed) return;
    final increment = _timeControl.incrementMs;
    if (_game.position.turn == Side.white) {
      _whiteTime = Duration(
        milliseconds: (_whiteTime.inMilliseconds - increment).clamp(0, 1 << 53),
      );
    } else {
      _blackTime = Duration(
        milliseconds: (_blackTime.inMilliseconds - increment).clamp(0, 1 << 53),
      );
    }
  }

  bool get _canUndo =>
      _game.canUndo &&
      !(widget.mode == PlayerMode.computer &&
          _game.humanSide == Side.black &&
          _game.uciMoves.length == 1);

  String get _status {
    if (_resigned) return 'Round resigned · retry from your tournament';
    if (_tournamentResult == TournamentRoundResult.draw) {
      return 'Round drawn · replay from your tournament';
    }
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

  NormalMove? get _lastOpponentMove {
    if (_game.uciMoves.isEmpty) return null;
    final index = widget.mode == PlayerMode.computer
        ? (_game.position.turn == _game.humanSide
              ? _game.uciMoves.length - 1
              : _game.uciMoves.length - 2)
        : _game.uciMoves.length - 1;
    if (index < 0) return null;
    final parsed = Move.parse(_game.uciMoves[index]);
    if (parsed is! NormalMove) return null;
    return parsed;
  }

  Widget _buildBoard(BuildContext context, Color accent) {
    return ZoomableChessBoard(
      key: _threatBoardKey,
      builder: (context, zoomed) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            ChessBoard(
              onSetSwipe: zoomed ? null : _swipeChessSet,
              orientation: widget.mode == PlayerMode.computer
                  ? _game.humanSide
                  : Side.white,
              appearance: _displayAppearance,
              position: _game.position,
              selected: _selected,
              legalTargets: _legalTargets,
              accent: accent,
              hiddenPieceSquare: _battle?.move.to,
              suggestedFrom: _hintFrom,
              suggestedTo: _hintTo,
              lastMoveFrom: _lastOpponentMove?.from,
              lastMoveTo: _lastOpponentMove?.to,
              threatFrom: _threats.current?.from,
              threatTarget: _threats.current?.targetSquare,
              threatLanding: _threats.current?.enPassant == true
                  ? _threats.current?.to
                  : null,
              threatLit: _threats.lit,
              onSquareTap: _tapSquare,
            ),
            if (_battle != null)
              CaptureBattleOverlay(
                appearance: _displayAppearance,
                battle: _battle!,
                accent: accent,
                orientation: widget.mode == PlayerMode.computer
                    ? _game.humanSide
                    : Side.white,
                reduced: MediaQuery.disableAnimationsOf(context),
                fast: _fastBattles,
                useCharacterAsset:
                    !_classicPieces &&
                    _appearance.white.id == PiecePackId.anime &&
                    _appearance.black.id == PiecePackId.anime &&
                    _battle!.attacker.role == Role.pawn &&
                    _battle!.defender!.role == Role.pawn,
                onSkip: _finishBattle,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpponentProfile() {
    final tournament = widget.tournamentMatch;
    final isComputer = widget.mode == PlayerMode.computer;
    final title =
        tournament?.opponent.name ??
        (isComputer ? 'Computer opponent' : 'Player 2');
    final subtitle = tournament != null
        ? '${tournament.opponent.difficultyLabel} · Computer · You play ${_game.humanSide == Side.white ? 'White' : 'Black'}'
        : isComputer
        ? '${widget.difficulty.label} · Computer · You play ${_game.humanSide == Side.white ? 'White' : 'Black'}'
        : 'Local player · Black pieces · ${_timeControl.timed ? 'Timed game' : 'No timer'}';
    final leading = tournament == null
        ? CircleAvatar(
            backgroundColor: widget.pack.accent.withValues(alpha: .16),
            child: Icon(
              isComputer ? Icons.smart_toy_outlined : Icons.person_outline,
              color: widget.pack.accent,
            ),
          )
        : tournament.cup.isConquest
        ? CircleAvatar(
            backgroundColor: widget.pack.accent.withValues(alpha: .16),
            child: Icon(widget.pack.icon, color: widget.pack.accent),
          )
        : OnlineAvatarImage(avatarId: tournament.opponent.avatarId, size: 48);
    return Card(
      key: const ValueKey('opponent-profile'),
      child: ListTile(
        key: tournament == null
            ? const ValueKey('local-opponent-profile')
            : const ValueKey('tournament-opponent'),
        leading: leading,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
      ),
    );
  }

  List<Widget> _buildMatchDetails(Color accent) => [
    if (!_showTopBar)
      Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          alignment: WrapAlignment.end,
          children: [
            PieceStyleToggleButton(
              // Also available when the large toolbar is hidden.
              key: const ValueKey('quick-piece-style-toggle'),
              classic: _classicPieces,
              themedPack: _appearance.white,
              onPressed: _togglePieceStyle,
            ),
            IconButton(
              key: const ValueKey('quick-board-color-toggle'),
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
            const MusicButton(compact: true),
            TopBarRestoreButton(
              accent: accent,
              onPressed: () => setState(() => _showTopBar = true),
            ),
            const ArenaCreditHeader(compact: true),
          ],
        ),
      ),
    if (!_showTopBar) const SizedBox(height: 4),
    MatchHeader(
      timed: _timeControl.timed,
      status: _status,
      whiteTime: _whiteTime,
      blackTime: _blackTime,
      turn: _game.position.turn,
      accent: accent,
    ),
    const SizedBox(height: 12),
    TurnIndicator(
      isPlayerTurn:
          _game.position.turn ==
          (widget.mode == PlayerMode.computer ? _game.humanSide : Side.white),
      playerLabel: widget.mode == PlayerMode.computer
          ? 'YOUR TURN · ${_game.humanSide.name.toUpperCase()}'
          : 'WHITE TO PLAY',
      opponentLabel: widget.mode == PlayerMode.computer
          ? 'COMPUTER’S TURN · ${_game.humanSide.opposite.name.toUpperCase()}'
          : 'BLACK TO PLAY',
    ),
    const SizedBox(height: 12),
    _buildOpponentProfile(),
    const SizedBox(height: 8),
    if (widget.mode == PlayerMode.computer)
      Card(
        key: const ValueKey('computer-lifelines'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Play assists',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  CreditCostBadge(
                    key: const ValueKey('computer-suggestion-credit-cost'),
                    cost: _suggestionCreditCost,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('use-computer-lifeline'),
                        style: playAssistButtonStyle,
                        onPressed: !_inputLocked ? _useComputerLifeline : null,
                        icon: _hintThinking
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const MoveSuggestionIcon(),
                        label: const Text(
                          'Suggest move',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ThreatScanButton(
                        scan: _threats,
                        enabled: !_inputLocked && !_game.isRuleDraw,
                        onScan: _analyseThreats,
                      ),
                    ),
                  ],
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
    if (_computerError != null && !_computerThinking)
      TextButton.icon(
        onPressed: _maybePlayComputer,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry computer move'),
      ),
    if (widget.mode != PlayerMode.computer)
      ThreatScanControls(
        scan: _threats,
        enabled: !_inputLocked && !_game.isRuleDraw,
        onScan: _analyseThreats,
      ),
    if (_displaySettings.showCapturedPieces)
      CapturedPiecesPanel(
        pieces: _game.capturedPieces,
        appearance: _displayAppearance,
        playerSide: widget.mode == PlayerMode.computer ? _game.humanSide : null,
      ),
    if (widget.tournamentMatch case final tournament?) ...[
      if (_tournamentSaveError != null)
        TextButton.icon(
          onPressed: () async {
            await _saveOpenGame();
            if (mounted && _tournamentResult != null) {
              await _showTournamentResult();
            }
          },
          icon: const Icon(Icons.sync_problem_outlined),
          label: Text(_tournamentSaveError!),
        ),
      TextButton.icon(
        key: const ValueKey('return-to-tournament'),
        onPressed: _leaveTournament,
        icon: const Icon(Icons.emoji_events_outlined),
        label: Text(
          tournament.cup.isConquest
              ? 'Return to conquest'
              : 'Return to tournament',
        ),
      ),
      if (_tournamentResult == null)
        TextButton(
          onPressed: _resignTournamentRound,
          child: const Text('Resign round'),
        ),
    ],
    const SizedBox(height: 8),
    MoveStrip(moves: _game.sanMoves, accent: accent),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = _appearance.board.accent;
    return PopScope(
      canPop: widget.tournamentMatch == null || _canLeaveTournament,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.tournamentMatch != null) {
          unawaited(_leaveTournament());
        }
      },
      child: Scaffold(
        backgroundColor: _appearance.board.backdrop,
        appBar: _showTopBar
            ? AppBar(
                title: widget.mode == PlayerMode.computer
                    ? null
                    : Text(
                        widget.tournamentMatch?.title ??
                            (widget.mode == PlayerMode.computer
                                ? '${widget.pack.name} · vs Computer'
                                : '${widget.pack.name} · Local Match'),
                      ),
                actions: [
                  PieceStyleToggleButton(
                    key: const ValueKey('quick-piece-style-toggle'),
                    classic: _classicPieces,
                    themedPack: _appearance.white,
                    compact: true,
                    onPressed: _togglePieceStyle,
                  ),
                  IconButton(
                    key: const ValueKey('quick-board-color-toggle'),
                    tooltip: _displaySettings.customBoardColorsEnabled
                        ? 'Use chess set board colours'
                        : 'Use saved board colours',
                    onPressed: _toggleBoardColors,
                    visualDensity: VisualDensity.compact,
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
                  const MusicButton(compact: true),
                  if (widget.tournamentMatch == null)
                    IconButton(
                      tooltip: 'Undo',
                      onPressed: _canUndo ? _undo : null,
                      icon: const Icon(Icons.undo, color: Color(0xFFFFB74D)),
                    ),
                  if (widget.tournamentMatch == null &&
                      widget.mode != PlayerMode.computer)
                    IconButton(
                      tooltip: 'New game',
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh),
                    ),
                  if (widget.mode != PlayerMode.computer)
                    IconButton(
                      tooltip: 'Hide top bar',
                      onPressed: () => setState(() => _showTopBar = false),
                      icon: const Icon(Icons.keyboard_arrow_up),
                    ),
                  const ArenaCreditHeader(compact: true),
                ],
              )
            : null,
        body: WorldBackdrop(
          pack: _appearance.board,
          customSet: _displayAppearance.customSet,
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
                                key: const ValueKey('landscape-match-scroll'),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                children: _buildMatchDetails(accent),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final topCount = 6 + (_showTopBar ? 0 : 2);
                    return ListView(
                      key: const ValueKey('portrait-match-scroll'),
                      controller: _boardScroll,
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
                        ThreatScanBanner(scan: _threats),
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
      ),
    );
  }
}
