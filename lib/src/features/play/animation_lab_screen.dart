import 'dart:async';
import 'game_header_ribbon.dart';
import 'dart:math' as math;
import '../../domain/game_time_control.dart';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import 'board_appearance.dart';
import '../../services/custom_chess_sets.dart';
import '../../services/custom_set_actions.dart';
import '../../domain/bot_tournament.dart';
import '../../domain/capture_threat.dart';
import '../../domain/neon_live_action.dart';
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
import '../../services/move_commentary.dart';
import '../../services/audio_preference_storage.dart';
import '../../services/last_game_storage.dart';
import '../../services/game_history_storage.dart';
import '../../services/player_identity_controller.dart';
import '../../services/app_diagnostics.dart';
import '../../services/game_display_settings.dart';
import '../../services/player_progress_controller.dart';
import '../settings/game_settings_sheet.dart';
import '../settings/board_color_settings.dart';
import '../credits/credit_balance_chip.dart';
import 'captured_pieces_panel.dart';
import 'chess_widgets.dart';
import 'capture_battle_overlay.dart';
import 'checkmate_dialog.dart';
import 'neon_cinematic_screen.dart';
import 'neon_live_arena.dart';
import 'neon_live_game_layout.dart';
import 'match_opponent_panel.dart';
import 'animated_accepted_capture_cues.dart';
import 'threat_scan.dart';
import 'play_assist_style.dart';
import 'move_suggestion_button_content.dart';
import 'player_side_selector.dart';
import 'piece_type_choice.dart';

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
    this.moveCommentary,
    this.tournamentMatch,
    this.initialClassicPieces = false,
    this.initialAnimatedArena,
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
  final MoveCommentary? moveCommentary;
  final TournamentMatchConfig? tournamentMatch;
  final bool initialClassicPieces;
  final bool? initialAnimatedArena;
  final ClassicPieceStyle initialClassicStyle;

  @override
  State<AnimationLabScreen> createState() => _AnimationLabScreenState();
}

class _AnimationLabScreenState extends State<AnimationLabScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final GameSession _game;
  late GameTimeControl _timeControl;
  ComputerPlayer? _computer;
  Timer? _clockTimer;
  late final Stopwatch _clockElapsed;
  int _lastClockElapsedMs = 0;
  Timer? _battleTimer;
  Timer? _computerReplyTimer;
  Timer? _turnAnimationTimer;
  bool _turnAnimationDelay = false;
  bool _liveMoveAnimationPending = false;
  bool _autoPlay = false;
  bool _autoConfirmationOpen = false;
  double _autoSpeed = 1;
  bool _commentaryEnabled = true;
  bool _commentaryPreferenceLoaded = false;
  int _commentaryPreferenceRevision = 0;
  String? _commentaryText;
  late final MoveCommentary _moveCommentary;
  bool _autoWaiting = false;
  int _autoRequest = 0;
  NormalMove? _previewMove;
  NormalMove? _highlightMove;
  Square? _blinkingSquare;
  bool _previewLit = true;
  late final AnimationController _movePacer;
  Duration _pendingDelay = Duration.zero;
  bool _blinkingDelay = false;
  bool _pacingPaused = false;
  Completer<void>? _moveDelay;
  Completer<void>? _previewBattle;
  bool _previewCommitted = false;

  String get _autoSpeedLabel => _autoSpeed == _autoSpeed.roundToDouble()
      ? _autoSpeed.toInt().toString()
      : _autoSpeed.toStringAsFixed(1);

  Duration _pacedDuration(Duration duration) => Duration(
    microseconds: (duration.inMicroseconds / (_autoPlay ? _autoSpeed : 1))
        .round(),
  );

  void _updatePacing() {
    if (_movePacer.isAnimating) {
      _movePacer.duration = _pacedDuration(_pendingDelay);
      _movePacer.forward();
    }
  }

  Future<void> _waitMoveDelay(Duration duration, {bool blink = false}) {
    final completion = Completer<void>();
    _moveDelay = completion;
    _pendingDelay = duration;
    _blinkingDelay = blink;
    _movePacer.duration = _pacedDuration(duration);
    _movePacer.value = 0;
    if (!_pacingPaused) _movePacer.forward();
    return completion.future;
  }

  void _cancelMoveDelay() {
    _movePacer.stop();
    final completion = _moveDelay;
    if (completion != null && !completion.isCompleted) completion.complete();
  }

  void _cancelPreviewBattle() {
    final completion = _previewBattle;
    _previewBattle = null;
    if (completion != null && !completion.isCompleted) completion.complete();
  }

  Widget _autoPlayButton() => IconButton(
    key: const ValueKey('auto-play-toggle'),
    tooltip: _autoPlay ? 'Stop auto-play' : 'Enable auto-play (2 second gap)',
    color: _autoPlay ? Colors.greenAccent : null,
    icon: Icon(
      _autoPlay ? Icons.pause_circle_outline : Icons.play_circle_outline,
    ),
    onPressed: _hintThinking || _autoConfirmationOpen || _matchFinished
        ? null
        : _toggleAutoPlay,
  );

  Future<void> _toggleAutoPlay() async {
    if (_autoConfirmationOpen || _matchFinished || _savingForReset) return;
    if (!_autoPlay) {
      final epoch = _gameEpoch;
      setState(() => _autoConfirmationOpen = true);
      final accepted = await confirmAutoPlay(context);
      if (!mounted) return;
      setState(() => _autoConfirmationOpen = false);
      if (!accepted ||
          epoch != _gameEpoch ||
          _matchFinished ||
          _savingForReset) {
        return;
      }
    }
    setState(() {
      _autoPlay = !_autoPlay;
      _autoRequest++;
      _commentaryText = null;
    });
    if (!_autoPlay) unawaited(_moveCommentary.stop());
    if (!_autoPlay && _game.isHumanTurn && !_previewCommitted) {
      _cancelMoveDelay();
    } else {
      _updatePacing();
    }
    if (_autoPlay) unawaited(_maybePlayComputer());
  }

  Widget _autoSpeedControl(Color accent) => Card(
    key: const ValueKey('auto-play-speed-control'),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.speed, color: accent, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text('Auto-play speed')),
              Text(
                '$_autoSpeedLabel×',
                style: TextStyle(color: accent, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Free auto-play · strongest assistance'),
          ),
          Slider(
            key: const ValueKey('auto-play-speed'),
            value: _autoSpeed,
            min: .5,
            max: 3,
            divisions: 5,
            label: '$_autoSpeedLabel×',
            semanticFormatterCallback: (value) =>
                '${value.toStringAsFixed(1)} times speed',
            onChanged: (value) {
              setState(() => _autoSpeed = value);
              _updatePacing();
            },
          ),
          if (_commentaryEnabled && _commentaryText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
              child: Text(
                _commentaryText!,
                key: const ValueKey('auto-play-commentary-caption'),
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
        ],
      ),
    ),
  );

  Future<void> _loadCommentaryPreference() async {
    final revision = ++_commentaryPreferenceRevision;
    final enabled = await AudioPreferenceStorage.loadCommentaryEnabled();
    if (!mounted || revision != _commentaryPreferenceRevision) return;
    setState(() {
      _commentaryEnabled = enabled;
      _commentaryPreferenceLoaded = true;
    });
    if (!enabled) unawaited(_moveCommentary.stop());
  }

  Future<void> _saveCommentaryPreference(bool enabled) async {
    try {
      await AudioPreferenceStorage.saveCommentaryEnabled(enabled);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save the commentary preference. Please try again.',
            ),
          ),
        );
      }
    }
  }

  Widget _commentaryButton() => IconButton(
    key: const ValueKey('auto-play-commentary-toggle'),
    tooltip: _commentaryEnabled
        ? 'Disable move commentary'
        : 'Enable move commentary',
    color: _commentaryEnabled ? Colors.greenAccent : null,
    icon: Icon(
      _commentaryEnabled ? Icons.record_voice_over : Icons.voice_over_off,
    ),
    onPressed: () {
      _commentaryPreferenceRevision++;
      setState(() {
        _commentaryEnabled = !_commentaryEnabled;
        _commentaryPreferenceLoaded = true;
      });
      unawaited(_saveCommentaryPreference(_commentaryEnabled));
      if (!_commentaryEnabled) unawaited(_moveCommentary.stop());
    },
  );

  bool _moveRequestValid(int epoch, String fen) =>
      mounted &&
      !_pacingPaused &&
      epoch == _gameEpoch &&
      _game.position.fen == fen &&
      _flagged == null &&
      !_resigned &&
      !_leavingTournament &&
      _tournamentResult == null &&
      !_game.isRuleDraw;

  Future<bool> _previewAutomaticMove(
    String uci,
    int epoch,
    String fen, {
    int? autoRequest,
  }) async {
    final move = Move.parse(uci);
    if (move is! NormalMove) return false;
    bool valid() =>
        _moveRequestValid(epoch, fen) &&
        (autoRequest == null || (_autoPlay && autoRequest == _autoRequest));
    if (!valid()) return false;
    setState(() {
      final piece = _game.pieceAt(move.from);
      final castle =
          piece?.role == Role.king &&
          _game.pieceAt(move.to)?.color == piece?.color &&
          move.from != move.to;
      _previewMove = castle
          ? NormalMove(
              from: move.from,
              to: Square.fromCoords(
                move.to.file > move.from.file ? File.g : File.c,
                move.from.rank,
              ),
            )
          : move;
      _selected = null;
      _legalTargets = const {};
      _blinkingSquare = move.from;
      _previewLit = true;
    });
    return _blinkMoveSquare(valid);
  }

  Future<bool> _blinkMoveSquare(bool Function() valid) async {
    await _waitMoveDelay(const Duration(milliseconds: 1200), blink: true);
    return valid();
  }

  void _clearMovePreview() {
    _previewMove = null;
    _blinkingSquare = null;
    _previewLit = true;
    _previewCommitted = false;
  }

  late BoardAppearance _appearance;
  bool _classicPieces = false;
  bool _animatedArena = true;
  late ClassicPieceStyle _classicStyle;
  final _threats = ThreatScanController();
  final _threatBoardKey = GlobalKey();
  final _boardScroll = ScrollController();
  final _displaySettings = GameDisplaySettings();
  bool get _isClassicDefaultTournament =>
      widget.tournamentMatch != null && !_isConquest;

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
    // Restored move facts are ready in initState, but presentation depends on
    // the inherited custom-set scope, which is safe to read only now.
    final restoredMove = _pendingRestoredLiveMove;
    _pendingRestoredLiveMove = null;
    if (restoredMove != null) _rememberLiveMove(restoredMove);
    _threats.setReducedMotion(MediaQuery.disableAnimationsOf(context));
    _historyPlayerName =
        PlayerIdentityScope.maybeOf(context)?.nickname ?? 'You';
    final custom = CustomChessSetScope.maybeOf(context)?.active;
    _historyCustomSetId = custom?.id;
    _historyCustomSetName = custom?.name;
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
      black: _appearance.black,
      board: _appearance.board,
      standardPieces: _classicPieces,
      animatedArena: _animatedArena,
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

  bool get _canWatchCinematic => usesAnimatedLiveArena(_displayAppearance);

  bool get _matchFinished =>
      _resigned ||
      _flagged != null ||
      _game.position.isGameOver ||
      _game.isRuleDraw;

  String get _cinematicResultTitle {
    if (_resigned) {
      return '${widget.tournamentMatch!.opponent.name} wins · Resignation';
    }
    if (_flagged == null && !_game.position.isCheckmate) return 'Game Drawn';
    final winner = _flagged?.opposite ?? _game.position.turn.opposite;
    final title = widget.mode == PlayerMode.computer
        ? winner == _game.humanSide
              ? 'You Win!'
              : widget.tournamentMatch?.opponent.name != null
              ? '${widget.tournamentMatch!.opponent.name} wins'
              : 'Computer Wins'
        : '${winner == Side.white ? 'White' : 'Black'} Wins!';
    return '$title · ${_flagged != null ? 'Timeout' : 'Checkmate'}';
  }

  Future<void> _watchCinematic() async {
    if (!_matchFinished || !_canWatchCinematic) return;
    final moves = List<String>.unmodifiable(_game.uciMoves);
    final resultTitle = _cinematicResultTitle;
    final theme = animatedArmyThemeForAppearance(_displayAppearance)!;
    final winner = _resigned
        ? _game.humanSide.opposite
        : _flagged?.opposite ??
              (_game.position.isCheckmate
                  ? _game.position.turn.opposite
                  : null);
    final playerSide = widget.mode == PlayerMode.computer
        ? _game.humanSide
        : null;
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => NeonCinematicScreen(
          moves: moves,
          classicStyle: _classicStyle,
          theme: theme,
          resultTitle: resultTitle,
          playerSide: playerSide,
          winnerSide: winner,
        ),
        fullscreenDialog: true,
      ),
    );
    if (mounted) await _loadCommentaryPreference();
  }

  void _toggleBoardColors() => unawaited(_displaySettings.toggleBoardColors());

  Future<void> _togglePieceStyle() async {
    if (!_animatedArena && !_isClassicDefaultTournament) {
      return _swipeChessSet(1);
    }
    if (!await restoreBuiltInChessSet(context) || !mounted) return;
    _threats.stop();
    setState(() {
      if (_isClassicDefaultTournament) {
        _animatedArena = !_animatedArena;
        _classicPieces = !_animatedArena;
      } else {
        _classicPieces = !_classicPieces;
      }
    });
    unawaited(_saveOpenGame());
  }

  Future<void> _swipeChessSet(int direction) async {
    if (_battle != null) return;
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
    await _saveOpenGame();
  }

  Future<void> _customize() async {
    _threats.stop();
    final next = await chooseBoardAppearance(
      context,
      _displayAppearance,
      lockedBlack: _isConquest ? _conquestOpponent : null,
      lockedBlackReason: _isConquest
          ? '${_conquestOpponent.name} is fixed for this conquest round. Change only your White animated army, or use Classic pieces.'
          : null,
    );
    if (mounted && next != null) {
      if (!await restoreBuiltInChessSet(context) || !mounted) return;
      final previousTheme = animatedArmyThemeForAppearance(_displayAppearance);
      final keepLiveAction =
          previousTheme != null &&
          previousTheme == animatedArmyThemeForAppearance(next);
      setState(() {
        if (!keepLiveAction) _clearLiveAction();
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

  Future<void> _applyChessSet(ChessSetSelection selection) async {
    if (!await restoreBuiltInChessSet(context) || !mounted) return;
    _threats.stop();
    setState(() {
      _clearLiveAction();
      _appearance = BoardAppearance.forPack(selection.pack);
      _classicPieces = !selection.animatedArena;
      _animatedArena = selection.animatedArena;
      _classicStyle = selection.classicStyle;
    });
    await _saveOpenGame();
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
            _clearLiveAction();
            _appearance = _isConquest
                ? BoardAppearance(
                    white: piecePacks.first,
                    black: _conquestOpponent,
                    board: _conquestOpponent,
                  )
                : BoardAppearance.forPack(piecePacks.first);
            _classicPieces = _isClassicDefaultTournament;
            _animatedArena = !_isClassicDefaultTournament;
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
        ],
      ),
    );
  }

  Square? _selected;
  bool _swipeHintDismissed = false;
  NeonLiveAction? _liveMoveAction, _liveSelectionAction;
  NormalMove? _animatedBoardMove;
  MoveResolution? _pendingRestoredLiveMove;
  String? _liveMoveFen, _liveSelectionKey;

  Side get _liveViewerSide =>
      widget.mode == PlayerMode.computer ? _game.humanSide : Side.white;

  NeonLiveAction? get _liveAction {
    if (!usesAnimatedLiveArena(_displayAppearance)) return null;
    if (_selected != null) {
      final key = '${_game.position.fen}|${_selected!.name}';
      if (_liveSelectionKey != key) {
        _liveSelectionKey = key;
        _liveSelectionAction = NeonLiveAction.selection(
          position: _game.position,
          source: _selected!,
          viewerSide: _liveViewerSide,
        );
      }
      return _liveSelectionAction;
    }
    return _liveMoveFen == _game.position.fen ? _liveMoveAction : null;
  }

  void _rememberLiveMove(MoveResolution resolution) {
    if (!usesAnimatedLiveArena(_displayAppearance)) {
      _clearLiveAction();
      return;
    }
    final before = _game.positionBeforeLastMove;
    _animatedBoardMove = resolution.move;
    _liveSelectionAction = null;
    _liveSelectionKey = null;
    _liveMoveFen = _game.position.fen;
    _liveMoveAction = before == null
        ? null
        : NeonLiveAction.move(
            before: before,
            after: _game.position,
            resolution: resolution,
            viewerSide: _liveViewerSide,
          );
  }

  void _clearLiveAction() {
    _animatedBoardMove = null;
    _liveMoveAction = null;
    _liveSelectionAction = null;
    _liveMoveFen = null;
    _liveSelectionKey = null;
  }

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
  final _gameHistory = GameHistoryStorage();
  String _historyPlayerName = 'You';
  String? _historySaveError;
  String? _historyCustomSetId, _historyCustomSetName;
  late String _historyGameId;
  bool _savingForReset = false;

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
    _moveCommentary = widget.moveCommentary ?? NativeMoveCommentary();
    unawaited(_loadCommentaryPreference());
    _movePacer =
        AnimationController(
            vsync: this,
            animationBehavior: AnimationBehavior.preserve,
          )
          ..addListener(() {
            if (!_blinkingDelay || _blinkingSquare == null || !mounted) return;
            final lit = (_movePacer.value * 6 + .000001).floor().isEven;
            if (_previewLit != lit) setState(() => _previewLit = lit);
          })
          ..addStatusListener((status) {
            final completion = _moveDelay;
            if (status == AnimationStatus.completed &&
                completion != null &&
                !completion.isCompleted) {
              completion.complete();
            }
          });
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
        (saved == null
            ? 'offline-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}'
            : GameHistoryRecord.idForSavedGame(saved));
    _historyGameId = saved == null
        ? _progressGameId
        : GameHistoryRecord.idForSavedGame(saved);
    _classicPieces =
        saved?.classicPieces ??
        ((_isClassicDefaultTournament && widget.initialAnimatedArena == null) ||
            widget.initialClassicPieces);
    _animatedArena = saved != null
        ? saved.animatedArena ?? true
        : widget.initialAnimatedArena ??
              (!_isClassicDefaultTournament && !widget.initialClassicPieces);
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
            black: _pack(saved.blackPack),
            board: _pack(saved.boardPack),
          );
    if (_game.positionBeforeLastMove case final before?) {
      final resolution = GameSession(
        position: before,
      ).playUci(_game.uciMoves.last);
      _pendingRestoredLiveMove = resolution;
    }
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
    final pendingResult = saved?.historyResultTitle?.toLowerCase();
    if (pendingResult != null) {
      _resigned = pendingResult.contains('resign');
      if (pendingResult.contains('timeout')) {
        _flagged = _whiteTime <= Duration.zero ? Side.white : Side.black;
      }
    }
    if (widget.mode == PlayerMode.computer) {
      _computer = widget.computerPlayer ?? ReliableComputerPlayer();
    }
    _clockElapsed.start();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (widget.tournamentMatch != null && pendingResult != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showTournamentResult(),
      );
    } else if (widget.mode == PlayerMode.computer) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybePlayComputer());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _threats.stop();
      _pacingPaused = true;
      _movePacer.stop();
      _computerReplyTimer?.cancel();
      _turnAnimationTimer?.cancel();
      unawaited(_moveCommentary.stop());
    } else if (_pacingPaused) {
      _pacingPaused = false;
      if (_turnAnimationDelay) {
        _waitForLiveMoveAnimation();
      } else if (_computerReplyDelay) {
        _scheduleComputerReply();
      } else if (_moveDelay != null && !_moveDelay!.isCompleted) {
        _movePacer.duration = _pacedDuration(_pendingDelay);
        _movePacer.forward();
      } else {
        unawaited(_maybePlayComputer());
      }
      if (_liveMoveAnimationPending &&
          !(_turnAnimationTimer?.isActive ?? false)) {
        _startLiveMoveAnimation();
      }
    }
    if (widget.tournamentMatch != null) {
      _tick();
      _tournamentPaused = state != AppLifecycleState.resumed;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_saveOpenGame(archiveUnfinished: true));
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
    unawaited(_saveOpenGame(archiveUnfinished: true));
    _clockTimer?.cancel();
    _clockElapsed.stop();
    _battleTimer?.cancel();
    _computerReplyTimer?.cancel();
    _turnAnimationTimer?.cancel();
    _cancelPreviewBattle();
    _cancelMoveDelay();
    _movePacer.dispose();
    unawaited(_moveCommentary.dispose());
    _computer?.dispose();
    super.dispose();
  }

  bool get _inputLocked =>
      _autoPlay ||
      _autoWaiting ||
      _previewMove != null ||
      _battle != null ||
      _turnAnimationDelay ||
      _computerReplyDelay ||
      _computerThinking ||
      _hintThinking ||
      _leavingTournament ||
      _savingForReset ||
      _resigned ||
      _tournamentResult != null ||
      _flagged != null ||
      _game.position.isGameOver ||
      _game.isRuleDraw ||
      !_game.isHumanTurn;

  void _tick() {
    final now = _clockElapsed.elapsedMilliseconds;
    final elapsed = Duration(milliseconds: now - _lastClockElapsedMs);
    _lastClockElapsedMs = now;
    if (!mounted ||
        !_timeControl.timed ||
        _flagged != null ||
        _game.position.isGameOver ||
        _game.isRuleDraw ||
        _resigned ||
        _tournamentResult != null ||
        _tournamentPaused ||
        _savingForReset ||
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
      setState(() {
        _gameEpoch++;
        _autoPlay = false;
        _autoRequest++;
        _autoWaiting = false;
        _computerThinking = false;
        _clearMovePreview();
      });
      _cancelMoveDelay();
      _cancelPreviewBattle();
      unawaited(_moveCommentary.stop());
      _threats.stop();
      if (widget.tournamentMatch != null) {
        unawaited(_showTournamentResult());
      } else {
        unawaited(_showTimeoutResult());
      }
    } else if (_ticksSinceSave >= 5) {
      _ticksSinceSave = 0;
      unawaited(_saveOpenGame());
    }
  }

  SavedGame _savedSnapshot() => SavedGame(
    mode: widget.mode,
    humanSide: _game.humanSide,
    homePack: widget.pack.id,
    difficulty: _difficulty,
    moves: List<String>.unmodifiable(_game.uciMoves),
    whiteMilliseconds: _whiteTime.inMilliseconds,
    blackMilliseconds: _blackTime.inMilliseconds,
    fastBattles: _fastBattles,
    whitePack: _appearance.white.id,
    blackPack: _appearance.black.id,
    boardPack: _appearance.board.id,
    updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    lifelinesRemaining: _lifelinesRemaining,
    classicPieces: _classicPieces,
    animatedArena: _animatedArena,
    classicStyle: _classicStyle,
    timeControl: _timeControl,
    progressGameId: _progressGameId,
    historyGameId: _historyGameId,
    historyResultTitle: _matchFinished ? _historyResultTitle : null,
  );

  String get _historyResultTitle {
    if (!_matchFinished) return 'Game unfinished';
    final winner = _resigned
        ? _game.humanSide.opposite
        : _flagged?.opposite ??
              (_game.position.isCheckmate
                  ? _game.position.turn.opposite
                  : null);
    if (winner == null) {
      if (_game.position.isStalemate) return 'Draw by stalemate';
      if (_game.position.isInsufficientMaterial) {
        return 'Draw by insufficient material';
      }
      return 'Game drawn';
    }
    final reason = _resigned
        ? 'resignation'
        : _flagged != null
        ? 'timeout'
        : 'checkmate';
    return '${winner == Side.white ? 'White' : 'Black'} wins by $reason';
  }

  Future<bool> _archiveSnapshot(
    SavedGame saved, {
    required bool completed,
    required String resultTitle,
  }) async {
    if (saved.moves.isEmpty && !completed) return true;
    final tournament = widget.tournamentMatch;
    final computerName = tournament?.opponent.name ?? 'Computer';
    final versusComputer = widget.mode == PlayerMode.computer;
    final record = GameHistoryRecord.fromSavedGame(
      saved,
      mode: tournament != null
          ? GameHistoryMode.tournament
          : versusComputer
          ? GameHistoryMode.computer
          : GameHistoryMode.local,
      status: completed
          ? GameHistoryStatus.completed
          : GameHistoryStatus.unfinished,
      resultTitle: resultTitle,
      whiteName: versusComputer
          ? (saved.humanSide == Side.white ? _historyPlayerName : computerName)
          : 'White player',
      blackName: versusComputer
          ? (saved.humanSide == Side.black ? _historyPlayerName : computerName)
          : 'Black player',
      tournamentTitle: tournament?.title,
      whiteCustomSetId: saved.classicPieces || _isConquest
          ? null
          : _historyCustomSetId,
      blackCustomSetId: saved.classicPieces || _isConquest
          ? null
          : _historyCustomSetId,
      whiteCustomName: saved.classicPieces || _isConquest
          ? null
          : _historyCustomSetName,
      blackCustomName: saved.classicPieces || _isConquest
          ? null
          : _historyCustomSetName,
    );
    return _persistHistoryRecord(record);
  }

  Future<bool> _persistHistoryRecord(GameHistoryRecord record) async {
    try {
      await _gameHistory.save(record);
      _historySaveError = null;
      return true;
    } catch (error, stack) {
      AppDiagnostics.instance.record(
        DiagnosticSource.asynchronous,
        error,
        stack,
      );
      if (mounted && _historySaveError == null) {
        _historySaveError = 'Could not save this game to history.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_historySaveError!),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_persistHistoryRecord(record)),
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<bool> _saveOpenGame({bool archiveUnfinished = false}) async {
    // Capture every fact before storage yields: reset, Undo, the next move or
    // leaving this route must not change the meaning of a queued recording.
    final saved = _savedSnapshot();
    final completed = _matchFinished;
    final resultTitle = _historyResultTitle;
    final tournament = widget.tournamentMatch;
    final tournamentResult = _tournamentResult;
    if (tournament != null) {
      // Preserve the full terminal source until the archive succeeds; finishing
      // a tournament round normally drops its resumable move list.
      final persistence = _saveTournamentSnapshot(
        saved,
        completed ? null : tournamentResult,
      );
      final archived = completed || archiveUnfinished
          ? await _archiveSnapshot(
              saved,
              completed: completed,
              resultTitle: resultTitle,
            )
          : true;
      await persistence;
      if (completed && archived) {
        await _saveTournamentSnapshot(saved, tournamentResult);
      }
      return archived;
    }
    if (completed) {
      // A failed archive keeps a recoverable terminal source. The ticket is
      // reserved immediately and only clears this source, never a newer game.
      final source = LastGameStorage.saveHistorySource(saved).then<int?>(
        (ticket) => ticket,
        onError: (Object error, StackTrace stack) {
          AppDiagnostics.instance.record(
            DiagnosticSource.asynchronous,
            error,
            stack,
          );
          return null;
        },
      );
      final archived = await _archiveSnapshot(
        saved,
        completed: true,
        resultTitle: resultTitle,
      );
      final ticket = await source;
      if (archived && ticket != null) {
        await LastGameStorage.clear(expectedRevision: ticket);
      }
      return archived;
    }
    // Reserve the resume write now, before an archive can delay it behind a
    // new screen's writes. LastGameStorage also guards delayed clear calls.
    final persistence = saved.moves.isEmpty
        ? LastGameStorage.clear()
        : LastGameStorage.save(saved);
    final archived = archiveUnfinished
        ? await _archiveSnapshot(
            saved,
            completed: false,
            resultTitle: resultTitle,
          )
        : true;
    await persistence;
    return archived;
  }

  Future<void> _saveTournamentSnapshot(
    SavedGame saved,
    TournamentRoundResult? result,
  ) async {
    try {
      await widget.tournamentMatch!.save(saved, result);
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
    _cancelMoveDelay();
    _cancelPreviewBattle();
    unawaited(_moveCommentary.stop());
    final archived = await _saveOpenGame(archiveUnfinished: true);
    if (!mounted) return;
    if (_tournamentSaveError != null || !archived) {
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
      _cancelMoveDelay();
      _cancelPreviewBattle();
      unawaited(_moveCommentary.stop());
      _clearMovePreview();
      _autoPlay = false;
      _autoWaiting = false;
      _computerThinking = false;
    });
    await _showTournamentResult();
  }

  Future<void> _showTournamentResult() async {
    final result = _tournamentResult;
    if (!mounted || _resultShown || _leavingTournament || result == null) {
      return;
    }
    final resultEpoch = _gameEpoch;
    _resultShown = true;
    await _saveOpenGame();
    if (!mounted || resultEpoch != _gameEpoch) return;
    if (_tournamentSaveError != null || _historySaveError != null) {
      _resultShown = false;
      return;
    }
    final won = result == TournamentRoundResult.win;
    final draw = result == TournamentRoundResult.draw;
    final match = widget.tournamentMatch!;
    final progressAward = await _recordProgress(won: won);
    if (!mounted || resultEpoch != _gameEpoch) return;
    if (_game.position.isCheckmate) {
      await showCheckmateAnimation(
        context: context,
        winner: _game.position.turn.opposite,
        appearance: _displayAppearance,
      );
      if (!mounted || resultEpoch != _gameEpoch) return;
    }
    if (won && match.isFinal) {
      final returnToCup = await showChampionshipCelebration(
        context: context,
        cup: match.cup,
        appearance: _displayAppearance,
        voice: _opponentVoice,
        checkmate: _game.position.isCheckmate,
        progressAward: progressAward,
        onWatchCinematic: _canWatchCinematic ? _watchCinematic : null,
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
      appearance: _displayAppearance,
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
      onWatchCinematic: _canWatchCinematic ? _watchCinematic : null,
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
        if (_selected != null) _swipeHintDismissed = true;
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
    if (resolution != null) _swipeHintDismissed = true;
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
      _rememberLiveMove(resolution);
      _highlightMove = resolution.san.startsWith('O-O')
          ? NormalMove(
              from: resolution.move.from,
              to: Square.fromCoords(
                resolution.san.startsWith('O-O-O') ? File.c : File.g,
                resolution.move.from.rank,
              ),
            )
          : resolution.move;
      _selected = null;
      _legalTargets = const {};
      _hintMessage = null;
      _hintFrom = null;
      _hintTo = null;
      if (resolution.isCapture) {
        _battle = resolution;
        if (_previewMove != null) _previewBattle = Completer<void>();
      }
    });
    unawaited(_saveOpenGame());
    if (usesAnimatedLiveArena(_displayAppearance)) _startLiveMoveAnimation();
    if (resolution.isCapture) {
      _battleTimer?.cancel();
      final reduced = MediaQuery.disableAnimationsOf(context);
      _battleTimer = Timer(
        captureBattleDuration(reduced: reduced, fast: _fastBattles) +
            Duration(milliseconds: reduced ? 25 : 100),
        _finishBattle,
      );
    } else if (_previewMove == null &&
        usesAnimatedLiveArena(_displayAppearance) &&
        (widget.mode == PlayerMode.computer || _game.position.isCheckmate)) {
      _waitForLiveMoveAnimation();
    } else {
      _finishTurn();
    }
  }

  void _finishBattle() {
    if (!mounted || _battle == null) return;
    _battleTimer?.cancel();
    setState(() => _battle = null);
    MusicScope.of(context)?.resumeBackground();
    if (_previewBattle != null) {
      _cancelPreviewBattle();
      return;
    }
    if (_liveMoveAnimationPending) {
      _waitForLiveMoveAnimation();
    } else {
      _finishTurn();
    }
  }

  void _waitForLiveMoveAnimation() {
    setState(() => _turnAnimationDelay = true);
    if (!(_turnAnimationTimer?.isActive ?? false)) _startLiveMoveAnimation();
  }

  void _startLiveMoveAnimation() {
    _turnAnimationTimer?.cancel();
    _liveMoveAnimationPending = true;
    if (_pacingPaused) return;
    final epoch = _gameEpoch;
    final fen = _game.position.fen;
    final reduced = MediaQuery.disableAnimationsOf(context);
    _turnAnimationTimer = Timer(
      reduced ? Duration.zero : neonLiveMoveAnimationDuration,
      () {
        if (!mounted || epoch != _gameEpoch || _game.position.fen != fen) {
          return;
        }
        final finishTurn = _turnAnimationDelay;
        setState(() {
          _liveMoveAnimationPending = false;
          _turnAnimationDelay = false;
        });
        if (finishTurn) _finishTurn();
      },
    );
  }

  void _scheduleComputerReply() {
    unawaited(_maybePlayComputer());
  }

  void _finishTurn() {
    if (_previewMove != null ||
        _turnAnimationDelay ||
        _computerReplyDelay ||
        _computerThinking ||
        _autoWaiting ||
        _savingForReset) {
      return;
    }
    if (_liveMoveAnimationPending &&
        (widget.mode == PlayerMode.computer || _game.position.isCheckmate)) {
      _waitForLiveMoveAnimation();
      return;
    }
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
      if (widget.mode == PlayerMode.computer &&
          !_game.isHumanTurn &&
          !_autoPlay) {
        _scheduleComputerReply();
      } else {
        unawaited(_maybePlayComputer());
      }
    }
  }

  Future<void> _showDrawResult() async {
    if (!mounted || _resultShown) return;
    final resultEpoch = _gameEpoch;
    _resultShown = true;
    await _saveOpenGame();
    if (!mounted || resultEpoch != _gameEpoch) return;
    final progressAward = await _recordProgress(won: false);
    if (!mounted) return;
    final startNew = await showGameResultDialog(
      context: context,
      appearance: _displayAppearance,
      outcome: GameResultOutcome.draw,
      heading: 'DRAW',
      title: 'Game Drawn',
      message: const GameResultMessage(
        sentiment: 'A hard-fought draw. Experience still counts.',
        comment:
            'Both sides held their ground. Review the final position and prepare for the next battle.',
      ),
      progressAward: progressAward,
      onWatchCinematic: _canWatchCinematic ? _watchCinematic : null,
    );
    if (mounted && startNew) await _reset();
  }

  Future<void> _showCheckmateResult() async {
    if (!mounted || _resultShown || !_game.position.isCheckmate) return;
    final resultEpoch = _gameEpoch;
    _resultShown = true;
    await _saveOpenGame();
    if (!mounted || resultEpoch != _gameEpoch) return;
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
    if (!mounted || resultEpoch != _gameEpoch) return;
    await showCheckmateAnimation(
      context: context,
      winner: winner,
      appearance: _displayAppearance,
    );
    if (!mounted || resultEpoch != _gameEpoch) return;
    final startNew = await showCheckmateDialog(
      context: context,
      appearance: _displayAppearance,
      userWon: userWon,
      title: versusComputer
          ? (userWon ? 'You Win!' : 'Computer Wins')
          : '${winner == Side.white ? 'White' : 'Black'} Wins!',
      message: message,
      progressAward: progressAward,
      onWatchCinematic: _canWatchCinematic ? _watchCinematic : null,
    );
    if (mounted && startNew) await _reset();
  }

  Future<void> _showTimeoutResult() async {
    final flagged = _flagged;
    if (!mounted || _resultShown || flagged == null) return;
    final resultEpoch = _gameEpoch;
    _resultShown = true;
    await _saveOpenGame();
    if (!mounted || resultEpoch != _gameEpoch) return;
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
      appearance: _displayAppearance,
      outcome: userWon ? GameResultOutcome.victory : GameResultOutcome.defeat,
      heading: 'WINNER BY TIMEOUT',
      title: versusComputer
          ? (userWon ? 'You Win!' : 'Computer Wins')
          : '${winner == Side.white ? 'White' : 'Black'} Wins!',
      message: message,
      progressAward: progressAward,
      onWatchCinematic: _canWatchCinematic ? _watchCinematic : null,
    );
    if (mounted && startNew) await _reset();
  }

  Future<void> _maybePlayComputer() async {
    if (!mounted ||
        _computer == null ||
        _pacingPaused ||
        _savingForReset ||
        (_game.isHumanTurn && !_autoPlay) ||
        _matchFinished ||
        _leavingTournament ||
        _tournamentResult != null ||
        _computerThinking ||
        _autoWaiting ||
        _battle != null ||
        _turnAnimationDelay ||
        _computerReplyDelay ||
        _hintThinking) {
      return;
    }
    final automaticHuman = _game.isHumanTurn;
    final autoRequest = _autoRequest;
    final requestEpoch = _gameEpoch;
    final requestFen = _game.position.fen;
    var committed = false;
    bool beforeValid() =>
        _moveRequestValid(requestEpoch, requestFen) &&
        (!automaticHuman || (_autoPlay && autoRequest == _autoRequest));
    setState(() {
      _computerThinking = true;
      _computerError = null;
    });
    try {
      if (_autoPlay) {
        setState(() => _autoWaiting = true);
        await _waitMoveDelay(const Duration(seconds: 2));
        if (!beforeValid()) return;
        setState(() => _autoWaiting = false);
      }
      if (!beforeValid()) return;
      final move = automaticHuman
          ? await _computer!.bestAssistanceMove(requestFen)
          : await _computer!.bestMove(
              requestFen,
              difficulty: _difficulty,
              botLevel: widget.tournamentMatch?.opponent.botLevel,
            );
      if (!beforeValid()) return;
      if (move == null) {
        setState(
          () => _computerError = 'Computer engine did not return a move',
        );
        return;
      }
      if (!await _previewAutomaticMove(
        move,
        requestEpoch,
        requestFen,
        autoRequest: automaticHuman ? autoRequest : null,
      )) {
        return;
      }
      if (!beforeValid()) return;
      _tick();
      if (_flagged != null) return;
      final resolution = _game.playUci(move);
      if (resolution == null) {
        setState(
          () => _computerError = 'Computer engine returned an invalid move',
        );
        return;
      }
      committed = true;
      _previewCommitted = true;
      final afterFen = _game.position.fen;
      bool afterValid() =>
          mounted &&
          requestEpoch == _gameEpoch &&
          _game.position.fen == afterFen &&
          _flagged == null &&
          !_resigned &&
          !_leavingTournament;
      _commitMove(resolution);
      if (_autoPlay && _commentaryEnabled && _commentaryPreferenceLoaded) {
        final text = moveCommentaryText(resolution);
        setState(() => _commentaryText = text);
        unawaited(_moveCommentary.speak(text));
      }
      setState(() {
        _blinkingSquare = null;
        _previewLit = true;
      });
      final battle = _previewBattle;
      if (battle != null) await battle.future;
      if (!afterValid()) return;
      setState(() {
        _blinkingSquare = _previewMove!.to;
        _previewLit = true;
      });
      await _blinkMoveSquare(afterValid);
    } catch (_) {
      if (mounted && requestEpoch == _gameEpoch) {
        setState(
          () => _computerError = 'Computer engine unavailable on this device',
        );
      }
    } finally {
      if (mounted && requestEpoch == _gameEpoch) {
        setState(() {
          _computerThinking = false;
          _autoWaiting = false;
          _clearMovePreview();
        });
        if (committed && _battle == null) {
          _finishTurn();
        } else if (!committed &&
            _autoPlay &&
            autoRequest != _autoRequest &&
            _computerError == null) {
          unawaited(_maybePlayComputer());
        }
      }
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
      final suggestion = await _computer!.bestAssistanceMove(fen);
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
    if (_savingForReset) return;
    _threats.stop();
    var humanSide = _game.humanSide;
    var nextTimeControl = widget.mode == PlayerMode.computer
        ? GameTimeControl.practice
        : GameTimeControl.rapid;
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
                'Start a fresh game. The moves you have already played stay in Game history.',
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
                      value: GameTimeControl.practice,
                      child: Text('Unlimited (No timer limit)'),
                    ),
                    DropdownMenuItem(
                      value: GameTimeControl.rapid,
                      child: Text('15 min · Rapid'),
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
    final nextClassicPieces = _classicPieces;
    setState(() {
      _savingForReset = true;
      _gameEpoch++;
      _computerReplyTimer?.cancel();
      _turnAnimationTimer?.cancel();
      _computerReplyDelay = false;
      _turnAnimationDelay = false;
      _liveMoveAnimationPending = false;
      _autoPlay = false;
      _autoRequest++;
      _autoWaiting = false;
      _cancelPreviewBattle();
      _cancelMoveDelay();
      _clearMovePreview();
      _computerThinking = false;
    });
    unawaited(_moveCommentary.stop());
    final archived = await _saveOpenGame(archiveUnfinished: true);
    if (!mounted) return;
    if (!archived) {
      setState(() => _savingForReset = false);
      unawaited(_maybePlayComputer());
      return;
    }
    if (nextClassicPieces && !await restoreBuiltInChessSet(context)) {
      if (mounted) {
        setState(() => _savingForReset = false);
        unawaited(_maybePlayComputer());
      }
      return;
    }
    if (!mounted) return;
    _battleTimer?.cancel();
    _computerReplyTimer?.cancel();
    _turnAnimationTimer?.cancel();
    setState(() {
      _gameEpoch++;
      _autoPlay = false;
      _autoRequest++;
      _autoWaiting = false;
      _cancelPreviewBattle();
      _cancelMoveDelay();
      _clearMovePreview();
      _commentaryText = null;
      unawaited(_moveCommentary.stop());
      _highlightMove = null;
      _progressGameId =
          'offline-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
      _historyGameId = _progressGameId;
      _savingForReset = false;
      _game.reset();
      _swipeHintDismissed = false;
      _classicPieces = nextClassicPieces;
      _clearLiveAction();
      _timeControl = nextTimeControl;
      _lastClockElapsedMs = _clockElapsed.elapsedMilliseconds;
      _game.humanSide = humanSide;
      _selected = null;
      _legalTargets = const {};
      _battle = null;
      _computerReplyDelay = false;
      _turnAnimationDelay = false;
      _liveMoveAnimationPending = false;
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
      _resigned = false;
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
    if (_autoPlay ||
        _autoWaiting ||
        _previewMove != null ||
        _computerThinking ||
        _hintThinking ||
        _battle != null ||
        !_canUndo) {
      return;
    }
    _threats.stop();
    if (_matchFinished) {
      _historyGameId =
          'continuation-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
    }
    setState(() {
      _gameEpoch++;
      _computerReplyTimer?.cancel();
      _turnAnimationTimer?.cancel();
      _computerReplyDelay = false;
      _turnAnimationDelay = false;
      _liveMoveAnimationPending = false;
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
      _resigned = false;
      _resultShown = false;
    });
    unawaited(_saveOpenGame());
    unawaited(_maybePlayComputer());
  }

  // Undo revokes increments without refunding thinking time.
  void _undoMoveAndIncrement() {
    _clearLiveAction();
    _highlightMove = null;
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
      !_savingForReset &&
      _game.canUndo &&
      !(widget.mode == PlayerMode.computer &&
          _game.humanSide == Side.black &&
          _game.uciMoves.length == 1);

  String get _status {
    if (_previewMove != null) {
      return '${_previewCommitted ? 'Move played' : 'Move preview'} · ${_previewMove!.from.name} → ${_previewMove!.to.name}';
    }
    if (_autoWaiting) {
      return 'Auto-play · ${(2 / _autoSpeed).toStringAsFixed(1)} second gap · $_autoSpeedLabel×';
    }
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
    if (_computerReplyDelay) return 'Computer replies in 2 seconds…';
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
              swipeHint: !_swipeHintDismissed && _game.uciMoves.isEmpty
                  ? (_animatedArena
                        ? 'Swipe left or right to toggle between classic and animated chess pieces'
                        : 'Swipe left or right to change classic chess pieces')
                  : null,
              showCoordinates: usesAnimatedLiveArena(_displayAppearance),
              animateMoves: usesAnimatedLiveArena(_displayAppearance),
              animatedMove: _animatedBoardMove,
              reducedMotion: MediaQuery.disableAnimationsOf(context),
              orientation: widget.mode == PlayerMode.computer
                  ? _game.humanSide
                  : Side.white,
              appearance: _displayAppearance,
              position: _game.position,
              selected: _selected,
              legalTargets: _legalTargets,
              accent: accent,
              hiddenPieceSquare: usesAnimatedLiveArena(_displayAppearance)
                  ? null
                  : _battle?.move.to,
              suggestedFrom: _hintFrom,
              suggestedTo: _hintTo,
              lastMoveFrom: _highlightMove?.from ?? _lastOpponentMove?.from,
              previewFrom: _previewMove?.from,
              previewTo: _previewMove?.to,
              blinkingSquare: _blinkingSquare,
              previewLit: _previewLit,
              lastMoveTo: _highlightMove?.to ?? _lastOpponentMove?.to,
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
                          ? ChessBoard.coordinateInset(box.biggest.shortestSide)
                          : 0,
                    ),
                    child: Stack(
                      children: [
                        CaptureBattleOverlay(
                          liveArena: usesAnimatedLiveArena(_displayAppearance),
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
                ),
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

  bool get _showTournamentOpponentPanel =>
      widget.tournamentMatch != null && !widget.tournamentMatch!.cup.isConquest;

  Widget _buildTournamentOpponentPanel() {
    final match = widget.tournamentMatch!;
    return KeyedSubtree(
      key: const ValueKey('opponent-profile'),
      child: MatchOpponentPanel(
        key: const ValueKey('tournament-opponent'),
        name: match.opponent.name,
        details:
            '${match.opponent.difficultyLabel} · Computer · You play ${_game.humanSide == Side.white ? 'White' : 'Black'}',
        avatarBuilder: (size) =>
            OnlineAvatarImage(avatarId: match.opponent.avatarId, size: size),
      ),
    );
  }

  Widget _quickPlayAssists() => IntrinsicHeight(
    child: Row(
      key: const ValueKey('quick-play-assists'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.mode == PlayerMode.computer) ...[
          Expanded(
            child: FilledButton.tonalIcon(
              key: const ValueKey('use-computer-lifeline'),
              style: playAssistButtonStyle.copyWith(
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
              onPressed: !_inputLocked ? _useComputerLifeline : null,
              icon: MoveSuggestionActionIcon(loading: _hintThinking),
              label: MoveSuggestionLabel(
                cost: _suggestionCreditCost,
                priceKey: const ValueKey('computer-suggestion-credit-cost'),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: ThreatScanButton(
            scan: _threats,
            enabled: !_inputLocked && !_game.isRuleDraw,
            onScan: _analyseThreats,
          ),
        ),
      ],
    ),
  );

  List<Widget> _buildMatchDetails(
    Color accent, {
    bool includeAssists = true,
    bool includeOpponent = true,
  }) => [
    if (!_showTopBar)
      Align(
        alignment: Alignment.centerRight,
        child: GameHeaderWrap(
          icons: [
            PieceStyleToggleButton(
              // Also available when the large toolbar is hidden.
              key: const ValueKey('quick-piece-style-toggle'),
              classic: _classicPieces,
              cycleClassicSets: !_animatedArena && !_isClassicDefaultTournament,
              classicStyle: _classicStyle,
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
            if (widget.mode == PlayerMode.computer) _autoPlayButton(),
            if (_autoPlay) _commentaryButton(),
            const MusicButton(),
            TopBarRestoreButton(
              accent: accent,
              onPressed: () => setState(() => _showTopBar = true),
            ),
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
    if (includeOpponent) ...[
      _buildOpponentProfile(),
      const SizedBox(height: 8),
    ],
    if (includeAssists && widget.mode == PlayerMode.computer)
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
    if (!includeAssists && _hintMessage != null)
      Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          _hintMessage!,
          key: const ValueKey('computer-hint-message'),
          style: TextStyle(color: accent, fontWeight: FontWeight.w800),
        ),
      ),
    if (includeAssists && widget.mode != PlayerMode.computer)
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
    if (_matchFinished && _canWatchCinematic)
      CinematicSummaryButton(
        key: const ValueKey('finished-match-cinematic'),
        onPressed: _watchCinematic,
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
                titleSpacing: 12,
                actionsPadding: const EdgeInsets.only(right: 12),
                title: widget.mode == PlayerMode.computer
                    ? null
                    : Text(
                        widget.tournamentMatch?.title ??
                            (widget.mode == PlayerMode.computer
                                ? '${widget.pack.name} · vs Computer'
                                : '${widget.pack.name} · Local Match'),
                      ),
                actions: [
                  GameHeaderRibbon(
                    hasTitle: widget.mode != PlayerMode.computer,
                    scrollKey: const ValueKey('game-header-icons'),
                    icons: [
                      if (widget.mode == PlayerMode.computer) _autoPlayButton(),
                      if (_autoPlay) _commentaryButton(),
                      PieceStyleToggleButton(
                        key: const ValueKey('quick-piece-style-toggle'),
                        classic: _classicPieces,
                        cycleClassicSets:
                            !_animatedArena && !_isClassicDefaultTournament,
                        classicStyle: _classicStyle,
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
                      const MusicButton(),
                      if (widget.tournamentMatch == null)
                        IconButton(
                          tooltip: 'Undo',
                          onPressed: _canUndo ? _undo : null,
                          icon: const Icon(
                            Icons.undo,
                            color: Color(0xFFFFB74D),
                          ),
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
                    ],
                  ),
                ],
              )
            : null,
        body: WorldBackdrop(
          pack: _appearance.board,
          customSet: _displayAppearance.customSet,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: AnimatedAcceptedCaptureCues(
                  key: const ValueKey('tournament-accepted-capture-cues'),
                  position: _game.position,
                  action: _liveAction,
                  enabled:
                      _showTournamentOpponentPanel &&
                      usesAnimatedLiveArena(_displayAppearance),
                  reducedMotion: MediaQuery.disableAnimationsOf(context),
                ),
              ),
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tournamentOpponent = _showTournamentOpponentPanel;
                    if (tournamentOpponent ||
                        usesAnimatedLiveArena(_displayAppearance)) {
                      return NeonLiveGameLayout(
                        compactPortraitArena: tournamentOpponent,
                        arena: tournamentOpponent
                            ? _buildTournamentOpponentPanel()
                            : NeonLiveArena(
                                theme: animatedArmyThemeForAppearance(
                                  _displayAppearance,
                                )!,
                                action: _liveAction,
                                viewerSide: _liveViewerSide,
                                position: _game.position,
                                reducedMotion: MediaQuery.disableAnimationsOf(
                                  context,
                                ),
                              ),
                        board: _buildBoard(context, accent),
                        quickActions: _quickPlayAssists(),
                        header: NeonLiveStatusBar(
                          status: _status,
                          whiteTime: _whiteTime,
                          blackTime: _blackTime,
                          turn: _game.position.turn,
                          timed: _timeControl.timed,
                        ),
                        details: _buildMatchDetails(
                          accent,
                          includeAssists: false,
                          includeOpponent: !tournamentOpponent,
                        ).where((item) => item is! MatchHeader).toList(),
                        boardFooter: Column(
                          children: [
                            if (_autoPlay && !_matchFinished)
                              _autoSpeedControl(accent),
                            ThreatScanBanner(scan: _threats),
                          ],
                        ),
                        scrollController: _boardScroll,
                        portraitScrollKey: const ValueKey(
                          'portrait-match-scroll',
                        ),
                        landscapeScrollKey: const ValueKey(
                          'landscape-match-scroll',
                        ),
                      );
                    }
                    final landscape =
                        constraints.maxWidth > constraints.maxHeight;
                    if (landscape) {
                      return Padding(
                        padding: EdgeInsets.all(_showTopBar ? 12 : 8),
                        child: ListView(
                          key: const ValueKey('landscape-board-scroll'),
                          controller: _boardScroll,
                          children: [
                            Column(
                              children: [
                                SizedBox(
                                  height: math.max(
                                    1.0,
                                    constraints.maxHeight -
                                        (_showTopBar ? 24 : 16),
                                  ),
                                  child: Row(
                                    key: const ValueKey(
                                      'landscape-match-layout',
                                    ),
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Expanded(
                                              child: Center(
                                                child: AspectRatio(
                                                  aspectRatio: 1,
                                                  child: _buildBoard(
                                                    context,
                                                    accent,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              height:
                                                  (MediaQuery.textScalerOf(
                                                                context,
                                                              ).scale(14) *
                                                              2.6 +
                                                          24)
                                                      .clamp(60, 104)
                                                      .toDouble(),
                                              child: _quickPlayAssists(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: _showTopBar ? 16 : 8),
                                      SizedBox(
                                        width: (constraints.maxWidth * .36)
                                            .clamp(280.0, 420.0)
                                            .toDouble(),
                                        child: ListView(
                                          key: const ValueKey(
                                            'landscape-match-scroll',
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          children: _buildMatchDetails(
                                            accent,
                                            includeAssists: false,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_autoPlay && !_matchFinished)
                                  _autoSpeedControl(accent),
                              ],
                            ),
                          ],
                        ),
                      );
                    }
                    final actionsHeight =
                        (MediaQuery.textScalerOf(context).scale(14) * 2.6 + 24)
                            .clamp(60, 104)
                            .toDouble();
                    return SafeArea(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 5, 10, 4),
                            child: NeonLiveStatusBar(
                              status: _status,
                              whiteTime: _whiteTime,
                              blackTime: _blackTime,
                              turn: _game.position.turn,
                              timed: _timeControl.timed,
                            ),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, pane) {
                                final extent = math.max(
                                  1.0,
                                  math.min(
                                    pane.maxWidth - 16,
                                    pane.maxHeight - actionsHeight - 16,
                                  ),
                                );
                                return ListView(
                                  key: const ValueKey('portrait-match-scroll'),
                                  controller: _boardScroll,
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    0,
                                    8,
                                    8,
                                  ),
                                  children: [
                                    SizedBox(
                                      height: extent,
                                      child: Center(
                                        child: SizedBox.square(
                                          dimension: extent,
                                          child: _buildBoard(context, accent),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: actionsHeight,
                                      child: _quickPlayAssists(),
                                    ),
                                    if (_autoPlay && !_matchFinished)
                                      _autoSpeedControl(accent),
                                    ThreatScanBanner(scan: _threats),
                                    const SizedBox(height: 8),
                                    Column(
                                      children:
                                          _buildMatchDetails(
                                                accent,
                                                includeAssists: false,
                                              )
                                              .where(
                                                (item) => item is! MatchHeader,
                                              )
                                              .toList(),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
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
}
