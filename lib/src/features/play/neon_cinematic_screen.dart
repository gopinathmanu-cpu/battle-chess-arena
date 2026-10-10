// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import '../../domain/animated_army_theme.dart';
import '../../domain/cinematic_replay.dart';
import '../../domain/cinematic_threats.dart';
import '../../domain/neon_cinematic_story.dart';
import '../../domain/piece_pack.dart';
import '../../services/cinematic_audio.dart';
import '../../services/audio_preference_storage.dart';
import '../../services/theme_music.dart';
import 'board_appearance.dart';
import 'chess_widgets.dart';
import 'neon_illustrated_stage.dart';
import 'neon_cinematic_board.dart';

/// An illustrated film of immutable recorded moves, with independent audio.
class NeonCinematicScreen extends StatefulWidget {
  const NeonCinematicScreen({
    required this.moves,
    required this.resultTitle,
    this.playerSide,
    this.winnerSide,
    this.theme = AnimatedArmyTheme.neon,
    this.classicStyle = ClassicPieceStyle.magneticTeaching,
    this.narrator,
    this.score,
    super.key,
  });
  final List<String> moves;
  final String resultTitle;
  final Side? playerSide;
  final Side? winnerSide;
  final AnimatedArmyTheme theme;
  final ClassicPieceStyle classicStyle;
  final CinematicNarrator? narrator;
  final CinematicScore? score;
  @override
  State<NeonCinematicScreen> createState() => _NeonCinematicScreenState();
}

class _NeonCinematicScreenState extends State<NeonCinematicScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  late final CinematicReplay _replay;
  late final Side? _winner;
  late final NeonCinematicStory _story;
  late final List<NeonStoryBeat> _beats;
  late final List<List<CinematicThreat>> _threatsByScene;
  late final AnimationController _film;
  late final CinematicNarrator _narrator;
  late final CinematicScore _score;
  ThemeMusic? _backgroundMusic;
  VoidCallback? _releaseBackground;
  ModalRoute<void>? _route;
  Timer? _controlsTimer;
  int _chapter = 0, _voiceRevision = 0, _scoreRevision = 0;
  int _narrationPreferenceRevision = 0, _musicPreferenceRevision = 0;
  double _speed = 1;
  bool _playing = true, _background = false, _boardOpen = false;
  bool _started = false, _impactPlayed = false, _reduced = false;
  bool _covered = false;
  bool _audioPreferencesLoaded = false;
  bool _narrationEnabled = true, _narrationPending = false;
  bool _musicEnabled = true, _controlsVisible = true;
  bool _classicReplayPieces = false;

  Color get _accent => Color(widget.theme.accentColorArgb);
  Color get _base => Color(widget.theme.baseColorArgb);
  PiecePack get _pack =>
      piecePacks.singleWhere((p) => p.id == widget.theme.packId);

  int get _lastChapter => _replay.scenes.length + 1;
  bool get _intro => _chapter == 0;
  bool get _finale => _chapter == _lastChapter;
  bool get _canRun =>
      _audioPreferencesLoaded &&
      _playing &&
      !_background &&
      !_boardOpen &&
      !_covered;
  CinematicReplayScene? get _scene =>
      _intro || _finale ? null : _replay.scenes[_chapter - 1];
  List<CinematicThreat> get _threats =>
      _scene == null ? const [] : _threatsByScene[_chapter - 1];
  NeonStoryBeat get _beat => _beats[_chapter];
  Duration get _sceneDuration {
    final visual = (_beat.visualDuration.inMilliseconds / _speed).round();
    final words = _beat.narration.split(RegExp(r'\s+')).length;
    final spoken = _narrationEnabled && _narrator.supported
        ? (words * 340 / _speed.clamp(.8, 1.6) + 600).round()
        : 0;
    return Duration(milliseconds: visual > spoken ? visual : spoken);
  }

  Position get _position => _intro
      ? _replay.initialPosition
      : _finale
      ? _replay.finalPosition
      : _film.value >= cinematicBoardMoveEnd
      ? _scene!.after
      : _scene!.before;
  String get _sceneLabel => _intro
      ? 'PROLOGUE'
      : _finale
      ? (widget.theme == AnimatedArmyTheme.neon
            ? 'FINAL TRANSMISSION'
            : 'EPILOGUE')
      : 'MOVE ${_scene!.moveNumber} · ${_scene!.side == Side.white ? 'WHITE' : 'BLACK'} · ${_scene!.san}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _replay = CinematicReplay.fromMoves(
      moves: widget.moves,
      resultTitle: widget.resultTitle,
    );
    _winner = cinematicWinner(
      resultTitle: _replay.resultTitle,
      finalPosition: _replay.finalPosition,
      winnerSide: widget.winnerSide,
    );
    _story = NeonCinematicStory(
      _replay,
      playerSide: widget.playerSide,
      winnerSide: widget.winnerSide,
      theme: widget.theme,
    );
    _beats = List.unmodifiable([
      _story.intro(),
      ...List.generate(_replay.scenes.length, _story.move),
      _story.finale(),
    ]);
    _threatsByScene = List.unmodifiable(
      _replay.scenes.map(cinematicThreatsAfter),
    );
    _narrator = widget.narrator ?? NativeCinematicNarrator();
    _score = widget.score ?? AssetCinematicScore(theme: widget.theme);
    _film =
        AnimationController(
            vsync: this,
            duration: _sceneDuration,
            animationBehavior: AnimationBehavior.preserve,
          )
          ..addListener(_onFrame)
          ..addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced != _reduced) {
      _controlsTimer?.cancel();
      _controlsVisible = true;
    }
    _reduced = reduced;
    final route = ModalRoute.of(context);
    if (route != _route) {
      musicRoutes.unsubscribe(this);
      _route = route;
      if (route != null) musicRoutes.subscribe(this, route);
    }
    if (!_started) {
      _started = true;
      _backgroundMusic = MusicScope.of(context);
      _musicEnabled = !(_backgroundMusic?.muted ?? false);
      _releaseBackground = _backgroundMusic?.suspendBackground();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_restoreAudioPreferences());
      });
    } else if (_audioPreferencesLoaded &&
        _backgroundMusic != null &&
        _musicEnabled != !_backgroundMusic!.muted) {
      _musicEnabled = !_backgroundMusic!.muted;
      unawaited(_syncScore());
    }
  }

  Future<void> _restoreAudioPreferences() async {
    final narrationRevision = _narrationPreferenceRevision;
    final musicRevision = _musicPreferenceRevision;
    final choices = await Future.wait([
      AudioPreferenceStorage.loadCommentaryEnabled(),
      AudioPreferenceStorage.loadMusicMuted(),
    ]);
    if (!mounted) return;
    setState(() {
      if (narrationRevision == _narrationPreferenceRevision) {
        _narrationEnabled = choices[0];
      }
      if (musicRevision == _musicPreferenceRevision) {
        _musicEnabled = !(_backgroundMusic?.muted ?? choices[1]);
      }
      _audioPreferencesLoaded = true;
    });
    _film.duration = _sceneDuration;
    _resumeCurrent();
    _armControls();
  }

  void _onFrame() {
    if (!_impactPlayed &&
        ((_finale && _winner != null && _film.value >= .22) ||
            (_film.value >= cinematicBoardMoveEnd &&
                (_scene?.isCapture == true || _scene?.isCheckmate == true)))) {
      _impactPlayed = true;
      if (_musicEnabled && _canRun) {
        unawaited(
          _score
              .impact(finale: _finale || _scene!.isCheckmate)
              .catchError((Object _) {}),
        );
      }
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _advanceIfReady();
  }

  void _advanceIfReady() {
    if (!mounted || !_canRun || !_film.isCompleted || _narrationPending) return;
    if (_finale) {
      setState(() {
        _playing = false;
        _controlsVisible = true;
      });
      _controlsTimer?.cancel();
      unawaited(_syncScore());
    } else {
      _seek(_chapter + 1);
    }
  }

  Future<void> _syncScore() async {
    final revision = ++_scoreRevision;
    await _backgroundMusic?.settled;
    if (!mounted || revision != _scoreRevision) return;
    try {
      if (_canRun && _musicEnabled) {
        await _score.play(ducked: _narrationPending);
      } else {
        await _score.pause();
      }
    } catch (_) {
      /* Captions remain available when audio is unavailable. */
    }
  }

  void _cancelNarration() {
    _voiceRevision++;
    _narrationPending = false;
    unawaited(_narrator.stop().catchError((Object _) {}));
  }

  void _beginNarration() {
    final revision = ++_voiceRevision;
    _narrationPending = _canRun && _narrationEnabled && _narrator.supported;
    unawaited(_syncScore());
    if (!_narrationPending) return;
    unawaited(() async {
      try {
        await _narrator.narrate(_beat.narration, rate: _speed.clamp(.8, 1.6));
      } catch (_) {
        /* Missing English voice data must not block the film. */
      }
      if (!mounted || revision != _voiceRevision) return;
      setState(() => _narrationPending = false);
      unawaited(_syncScore());
      _advanceIfReady();
    }());
  }

  void _resumeCurrent() {
    if (!_canRun) return;
    _beginNarration();
    if (_film.isCompleted) {
      _advanceIfReady();
    } else {
      _film.forward();
    }
  }

  void _seek(int chapter) {
    _film.stop();
    _cancelNarration();
    setState(() {
      _chapter = chapter.clamp(0, _lastChapter);
      _impactPlayed = false;
    });
    _film.duration = _sceneDuration;
    _film.value = 0;
    _resumeCurrent();
    unawaited(_syncScore());
  }

  void _togglePlayback() {
    _showControls();
    if (!_playing && _film.isCompleted && _finale) {
      setState(() => _playing = true);
      _seek(0);
      _armControls();
      return;
    }
    setState(() => _playing = !_playing);
    if (_playing) {
      _resumeCurrent();
      _armControls();
    } else {
      _film.stop();
      _cancelNarration();
      _controlsTimer?.cancel();
      unawaited(_syncScore());
    }
  }

  void _changeSpeed() {
    _showControls();
    _cancelNarration();
    setState(
      () => _speed = _speed == 1
          ? 2
          : _speed == 2
          ? 4
          : 1,
    );
    _film.duration = _sceneDuration;
    _resumeCurrent();
  }

  void _toggleNarration() {
    _showControls();
    _cancelNarration();
    setState(() => _narrationEnabled = !_narrationEnabled);
    _narrationPreferenceRevision++;
    unawaited(
      AudioPreferenceStorage.saveCommentaryEnabled(
        _narrationEnabled,
      ).catchError((Object _) {}),
    );
    _film.duration = _sceneDuration;
    if (_narrationEnabled) _beginNarration();
    unawaited(_syncScore());
    _advanceIfReady();
    if (_canRun && !_film.isCompleted) _film.forward();
  }

  @override
  void didPushNext() {
    _covered = true;
    _film.stop();
    _controlsTimer?.cancel();
    _cancelNarration();
    unawaited(_syncScore());
  }

  @override
  void didPopNext() {
    _covered = false;
    _resumeCurrent();
    _armControls();
  }

  @override
  void didPop() => didPushNext();

  void _toggleMusic() {
    _showControls();
    setState(() => _musicEnabled = !_musicEnabled);
    _musicPreferenceRevision++;
    final music = _backgroundMusic;
    if (music != null) {
      music.setMuted(!_musicEnabled);
    } else {
      unawaited(
        AudioPreferenceStorage.saveMusicMuted(
          !_musicEnabled,
        ).catchError((Object _) {}),
      );
    }
    unawaited(_syncScore());
  }

  void _showControls() {
    _controlsTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _armControls();
  }

  void _armControls() {
    _controlsTimer?.cancel();
    if (!_canRun || _reduced) return;
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _canRun && !_reduced) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _background = true;
      _film.stop();
      _controlsTimer?.cancel();
      _cancelNarration();
      unawaited(_syncScore());
    } else {
      _background = false;
      _resumeCurrent();
      _armControls();
    }
  }

  Future<void> _showBoard() async {
    _showControls();
    setState(() => _boardOpen = true);
    _film.stop();
    _cancelNarration();
    unawaited(_syncScore());
    final position = _position;
    final scene = _scene;
    try {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF101726),
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _sceneLabel,
                  style: TextStyle(color: _accent, fontSize: 12),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 350),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: AbsorbPointer(
                      child: ChessBoard(
                        position: position,
                        selected: null,
                        legalTargets: const {},
                        accent: _accent,
                        onSquareTap: (_) {},
                        appearance: _classicReplayPieces
                            ? BoardAppearance.forPack(
                                _pack,
                              ).withStandardPieces(widget.classicStyle)
                            : BoardAppearance.forPack(_pack),
                        lastMoveFrom: scene?.source,
                        lastMoveTo: scene?.target,
                        showPieceRoles: false,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _finale
                      ? _replay.resultTitle
                      : scene == null
                      ? 'The opening position'
                      : '${scene.source.name} → ${scene.target.name} · ${scene.san}',
                ),
                const SizedBox(height: 6),
                TextButton(
                  key: const ValueKey('cinematic-close-board'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Return to film'),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _boardOpen = false);
        _resumeCurrent();
        _armControls();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    musicRoutes.unsubscribe(this);
    _controlsTimer?.cancel();
    _voiceRevision++;
    _scoreRevision++;
    _film.dispose();
    unawaited(_narrator.dispose().catchError((Object _) {}));
    final release = _releaseBackground;
    unawaited(
      _score
          .dispose()
          .catchError((Object _) {})
          .whenComplete(() => release?.call()),
    );
    super.dispose();
  }

  Widget _hud(Widget child) => IgnorePointer(
    ignoring: !_controlsVisible,
    child: AnimatedOpacity(
      duration: _reduced ? Duration.zero : const Duration(milliseconds: 250),
      opacity: _controlsVisible ? 1 : 0,
      child: child,
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Back to game result',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        Expanded(
          child: Text(
            widget.theme.displayName,
            key: const ValueKey('cinematic-theme-title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
        IconButton(
          key: const ValueKey('cinematic-narration-toggle'),
          tooltip: _narrationEnabled ? 'Mute narration' : 'Enable narration',
          color: _narrationEnabled ? _accent : Colors.white54,
          icon: Icon(
            _narrationEnabled ? Icons.record_voice_over : Icons.voice_over_off,
          ),
          onPressed: _audioPreferencesLoaded ? _toggleNarration : null,
        ),
        IconButton(
          key: const ValueKey('cinematic-music'),
          tooltip: _musicEnabled ? 'Mute soundtrack' : 'Enable soundtrack',
          color: _musicEnabled ? _accent : Colors.white54,
          icon: Icon(_musicEnabled ? Icons.music_note : Icons.music_off),
          onPressed: _audioPreferencesLoaded ? _toggleMusic : null,
        ),
        IconButton(
          key: const ValueKey('cinematic-piece-toggle'),
          tooltip: _classicReplayPieces
              ? 'Use Animated replay pieces'
              : 'Use Classic replay pieces',
          icon: Icon(
            _classicReplayPieces ? Icons.auto_awesome : Icons.castle_outlined,
          ),
          onPressed: () {
            _showControls();
            setState(() => _classicReplayPieces = !_classicReplayPieces);
          },
        ),
        IconButton(
          key: const ValueKey('cinematic-board'),
          tooltip: 'Enlarge recorded board',
          onPressed: _showBoard,
          icon: const Icon(Icons.grid_on),
        ),
      ],
    ),
  );

  Widget _captions(double height) {
    final short = height < 280;
    final veryShort = height < 180;
    final label = Text(
      _sceneLabel,
      key: const ValueKey('cinematic-scene-label'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: _accent,
        fontWeight: FontWeight.w700,
        fontSize: veryShort ? 8 : 9,
        letterSpacing: short ? .7 : 1.3,
      ),
    );
    final headline = Text(
      _beat.title,
      key: const ValueKey('cinematic-headline'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: veryShort
            ? 13
            : short
            ? 16
            : 20,
        height: 1.05,
        fontWeight: FontWeight.w900,
        shadows: const [Shadow(blurRadius: 12)],
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(short ? 12 : 18, 5, short ? 12 : 18, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (veryShort)
            Row(
              children: [
                Expanded(child: label),
                const SizedBox(width: 8),
                Expanded(child: headline),
              ],
            )
          else ...[
            label,
            const SizedBox(height: 3),
            headline,
          ],
          if (_finale && _beat.title != _replay.resultTitle) ...[
            const SizedBox(height: 3),
            Text(
              _replay.resultTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _accent,
                fontSize: short ? 10 : 12,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _beat.narration,
            key: const ValueKey('cinematic-narration'),
            maxLines: short ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: short ? 10.5 : 12,
              height: 1.2,
              color: const Color(0xFFE0E6EF),
              shadows: const [Shadow(blurRadius: 12)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _transport() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 26,
          child: AnimatedBuilder(
            animation: _film,
            builder: (context, _) => Slider(
              key: const ValueKey('cinematic-timeline'),
              label: _intro
                  ? 'Prologue'
                  : _finale
                  ? 'Finale'
                  : 'Move $_chapter',
              semanticFormatterCallback: (value) => value.round() == 0
                  ? 'Prologue'
                  : value.round() == _lastChapter
                  ? 'Finale'
                  : 'Move ${value.round()}',
              value: (_chapter + _film.value).clamp(0, _lastChapter.toDouble()),
              min: 0,
              max: _lastChapter.toDouble(),
              onChanged: (value) {
                _showControls();
                _seek(value.round());
              },
            ),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              key: const ValueKey('cinematic-previous'),
              tooltip: 'Previous scene',
              onPressed: _chapter > 0
                  ? () {
                      _showControls();
                      _seek(_chapter - 1);
                    }
                  : null,
              icon: const Icon(Icons.skip_previous),
            ),
            IconButton.filled(
              key: const ValueKey('cinematic-play-pause'),
              tooltip: _playing ? 'Pause film' : 'Play film',
              onPressed: _togglePlayback,
              icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
            ),
            IconButton(
              key: const ValueKey('cinematic-next'),
              tooltip: 'Next scene',
              onPressed: !_finale
                  ? () {
                      _showControls();
                      _seek(_chapter + 1);
                    }
                  : null,
              icon: const Icon(Icons.skip_next),
            ),
            TextButton(
              key: const ValueKey('cinematic-speed'),
              onPressed: _changeSpeed,
              child: Text('${_speed.toInt()}×'),
            ),
            if (_finale)
              IconButton(
                key: const ValueKey('cinematic-replay'),
                tooltip: 'Watch again',
                onPressed: () {
                  setState(() => _playing = true);
                  _showControls();
                  _seek(0);
                },
                icon: const Icon(Icons.replay),
              )
            else
              Text(
                '$_chapter / $_lastChapter',
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _actionPane(bool sideCaptions) => LayoutBuilder(
    builder: (context, constraints) => Column(
      key: const ValueKey('cinematic-action-pane'),
      children: [
        Expanded(
          child: NeonIllustratedStage(
            theme: widget.theme,
            scene: _scene,
            progress: _film.value,
            intro: _intro,
            finale: _finale,
            reducedMotion: _reduced,
            compact: true,
            captionInset: 0,
            threats: _threats,
            title: '',
            subtitle: '',
            resultTitle: _replay.resultTitle,
            winnerSide: _winner,
          ),
        ),
        if (!sideCaptions)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _base.withValues(alpha: 0),
                  _base.withValues(alpha: .96),
                ],
              ),
            ),
            child: _captions(constraints.maxHeight),
          ),
      ],
    ),
  );

  Widget _battlefield() => NeonCinematicBoard(
    key: const ValueKey('cinematic-battlefield-pane'),
    theme: widget.theme,
    position: _position,
    scene: _scene,
    progress: _film.value,
    intro: _intro,
    finale: _finale,
    reducedMotion: _reduced,
    classicPieces: _classicReplayPieces,
    classicStyle: widget.classicStyle,
    threatSquares: _film.value >= cinematicBoardMoveEnd
        ? _threats.map((threat) => threat.square).toSet()
        : const {},
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.dark(primary: _accent),
      scaffoldBackgroundColor: _base,
    ),
    child: Scaffold(
      key: const ValueKey('neon-cinematic-screen'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, screen) {
            // Short landscape has room beside the board for captions. Use it
            // to keep the upper action figures visible, including larger text.
            final sideCaptions =
                screen.maxHeight < 500 && screen.maxWidth > screen.maxHeight;
            return Column(
              children: [
                AnimatedContainer(
                  duration: _reduced
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  height: _controlsVisible ? 52 : 0,
                  child: _controlsVisible ? _hud(_header()) : null,
                ),
                Expanded(
                  child: GestureDetector(
                    key: const ValueKey('cinematic-stage'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _showControls,
                    child: AnimatedBuilder(
                      animation: _film,
                      builder: (context, _) => Column(
                        children: [
                          Expanded(child: _actionPane(sideCaptions)),
                          const SizedBox(
                            height: 1,
                            child: ColoredBox(color: Color(0xFF294252)),
                          ),
                          Expanded(
                            child: sideCaptions
                                ? LayoutBuilder(
                                    builder: (context, pane) => Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: _battlefield(),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: _captions(pane.maxHeight),
                                        ),
                                      ],
                                    ),
                                  )
                                : _battlefield(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: _reduced
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  height: _controlsVisible ? 76 : 0,
                  child: _controlsVisible ? _transport() : null,
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
