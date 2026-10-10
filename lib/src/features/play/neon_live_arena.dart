// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../domain/neon_live_action.dart';
import '../../domain/animated_army_theme.dart';
import '../../domain/piece_pack.dart';
import '../../domain/piece_selection_commentary.dart';
import '../../services/theme_music.dart';
import 'board_appearance.dart';
import 'animated_move_timing.dart';
import 'animated_accepted_capture_cues.dart';
import 'animated_castling_presentation.dart';
import 'neon_illustrated_stage.dart';

const _gold = Color(0xFFFFD382);
const _night = Color(0xFF070B19);
const neonLiveMoveAnimationDuration = animatedMoveDuration;

bool usesNeonLiveArena(BoardAppearance appearance) =>
    appearance.animatedArena &&
    appearance.customSet == null &&
    appearance.white.id == PiecePackId.futuristic &&
    appearance.black.id == PiecePackId.futuristic;

AnimatedArmyTheme? animatedArmyThemeForAppearance(BoardAppearance appearance) =>
    !appearance.animatedArena ||
        appearance.customSet != null ||
        appearance.white.id != appearance.black.id
    ? null
    : AnimatedArmyTheme.forPack(appearance.white.id);

bool usesAnimatedLiveArena(BoardAppearance appearance) =>
    animatedArmyThemeForAppearance(appearance) != null;

/// A responsive illustration above the live, interactive board. It interprets
/// a selection or accepted move without advancing the game or delaying input.
class NeonLiveArena extends StatefulWidget {
  const NeonLiveArena({
    required this.viewerSide,
    required this.position,
    this.action,
    this.reducedMotion = false,
    this.theme = AnimatedArmyTheme.neon,
    super.key,
  });

  final Side viewerSide;
  final Position position;
  final NeonLiveAction? action;
  final bool reducedMotion;
  final AnimatedArmyTheme theme;

  @override
  State<NeonLiveArena> createState() => _NeonLiveArenaState();
}

class _NeonLiveArenaState extends State<NeonLiveArena>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: neonLiveMoveAnimationDuration,
    value: 1,
  );
  int _page = 0;
  bool _reduced = false;
  _ActorPose? _renderedActorPose;
  _ActorPose? _startActorPose;
  _ActorVelocity _renderedActorVelocity = _ActorVelocity.zero;
  _ActorVelocity _startActorVelocity = _ActorVelocity.zero;
  List<_ArenaThreat> _outgoingThreats = const [];
  bool _backgrounded = false;
  ThemeMusic? _music;
  bool _captureSoundArmed = false;
  bool _attackPlayed = false;
  bool _impactPlayed = false;
  final _replyRandom = math.Random();
  String? _selectionReply;
  String? _previousSelectionReply;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _motion.addListener(_captureCues);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _backgrounded = lifecycle != null && lifecycle != AppLifecycleState.resumed;
    _chooseSelectionReply();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _backgrounded = state != AppLifecycleState.resumed;
    if (_backgrounded) {
      _motion.stop();
    } else if (!_reduced &&
        widget.action?.isSelection == false &&
        _motion.value < 1) {
      _motion.forward();
    }
    _captureCues();
  }

  void _chooseSelectionReply() {
    final action = widget.action;
    if (action == null || !action.isSelection) {
      _selectionReply = null;
      return;
    }
    final lines = pieceSelectionCommentary(
      position: widget.position,
      action: action,
      theme: widget.theme,
    );
    final varied = lines
        .where((line) => line != _previousSelectionReply)
        .toList(growable: false);
    final candidates = varied.isEmpty ? lines : varied;
    _selectionReply = candidates.isEmpty
        ? null
        : candidates[_replyRandom.nextInt(candidates.length)];
    _previousSelectionReply = _selectionReply;
  }

  void _captureCues() {
    if (!_captureSoundArmed || _backgrounded) return;
    final action = widget.action;
    if (action == null || action.isSelection || action.captured == null) return;
    if (!_attackPlayed) {
      _attackPlayed = true;
      unawaited(_music?.playEffect(CinematicSound.attack));
    }
    if (!_impactPlayed &&
        (_reduced || _motion.value >= animatedMoveImpactFraction)) {
      _impactPlayed = true;
      final effect = animatedCaptureImpactSound(
        role: action.actor.role,
        checkmate: widget.position.isCheckmate,
      );
      unawaited(_music?.playEffect(effect));
    }
  }

  Color get _cyan => Color(widget.theme.whiteColorArgb);
  Color get _pink => Color(widget.theme.blackColorArgb);
  Color get _night => Color(widget.theme.baseColorArgb);

  bool _sameActor(NeonLiveAction? before, NeonLiveAction? after) =>
      before != null &&
      after != null &&
      before.actor.color == after.actor.color &&
      (before.target ?? before.source) == after.source &&
      (before.actor.role == after.actor.role ||
          (before.actor.role == Role.pawn &&
              !after.isSelection &&
              after.actor.role != Role.king));

  String _identity(NeonLiveArena arena) {
    final action = arena.action;
    return '${arena.theme.name}|${arena.viewerSide.name}|${arena.position.fen}|'
        '${action?.actor}|${action?.source}|${action?.target}|'
        '${action?.isSelection}|${action?.actorOnLeft}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _music = MusicScope.of(context);
    _reduced =
        widget.reducedMotion ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (_reduced) _motion.value = 1;
  }

  @override
  void didUpdateWidget(NeonLiveArena oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reduced =
        widget.reducedMotion ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (_identity(oldWidget) != _identity(widget)) {
      _page = 0;
      _chooseSelectionReply();
      // Restored initial actions are silent; only a newly accepted capture
      // arms these cues. Their clock pauses with the actual visible strike.
      final action = widget.action;
      final acceptedMove =
          action != null &&
          !action.isSelection &&
          oldWidget.position.fen != widget.position.fen;
      _captureSoundArmed = acceptedMove && action.captured != null;
      _attackPlayed = false;
      _impactPlayed = false;
      // A selected avatar stays still. A committed move starts from its pose;
      // opponent moves without a prior selection can enter the battlefield.
      final continuous =
          oldWidget.theme == widget.theme &&
          oldWidget.action?.actorOnLeft == widget.action?.actorOnLeft &&
          _sameActor(oldWidget.action, widget.action);
      _startActorPose = continuous ? _renderedActorPose : null;
      _startActorVelocity = continuous
          ? _renderedActorVelocity
          : _ActorVelocity.zero;
      _outgoingThreats =
          acceptedMove &&
              continuous &&
              oldWidget.action!.isSelection &&
              widget.action?.isSelection == false
          ? oldWidget.action!.threats
                .map(
                  (threat) => _ArenaThreat(
                    piece: threat.piece,
                    square: threat.square,
                    destinations: threat.destinations,
                    isCheck: threat.isCheck,
                    possibleCheck: threat.possibleCheck,
                  ),
                )
                .toList(growable: false)
          : const [];
      _renderedActorPose = null;
      _renderedActorVelocity = _ActorVelocity.zero;
      _motion.duration = animatedMoveDuration;
      if (_reduced || !acceptedMove) {
        _motion.value = 1;
      } else if (_backgrounded) {
        _motion.value = 0;
      } else {
        _motion.forward(from: 0);
      }
    } else if (_reduced && _motion.value != 1) {
      _motion.value = 1;
    }
    _captureCues();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.removeListener(_captureCues);
    _motion.dispose();
    super.dispose();
  }

  List<_ArenaThreat> get _threats {
    final action = widget.action;
    if (action != null) {
      return action.threats
          .map(
            (threat) => _ArenaThreat(
              piece: threat.piece,
              square: threat.square,
              destinations: threat.destinations,
              isCheck: threat.isCheck,
              possibleCheck: threat.possibleCheck,
            ),
          )
          .toList(growable: false);
    }
    if (!widget.position.isCheck) return const [];
    final square = widget.position.board.kingOf(widget.position.turn);
    final piece = square == null ? null : widget.position.board.pieceAt(square);
    if (square == null || piece == null) return const [];
    return [_ArenaThreat(piece: piece, square: square, isCheck: true)];
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    builder: (context, _) => LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final short = size.height < 140;
        final p = _reduced ? 1.0 : _motion.value;
        final action = widget.action;
        final afterThreats = _threats;
        final moving = action != null && !action.isSelection;
        final useOutgoing =
            moving &&
            !_reduced &&
            p < animatedMoveImpactFraction &&
            _outgoingThreats.isNotEmpty;
        final threats = useOutgoing ? _outgoingThreats : afterThreats;
        final threatsOpacity = !moving || _reduced
            ? 1.0
            : useOutgoing
            ? 1 -
                  _smoothStep(
                    ((p - animatedMoveImpactFraction + .12) / .12).clamp(
                      0.0,
                      1.0,
                    ),
                  )
            : _smoothStep(
                ((p - animatedMoveImpactFraction) / .18).clamp(0.0, 1.0),
              );
        // Reserve the same column throughout a chapter, even when selected
        // victims disappear and the accepted position has different threats.
        final hasThreatColumn =
            afterThreats.isNotEmpty || (moving && _outgoingThreats.isNotEmpty);
        final actorOnLeft = action?.actorOnLeft ?? true;
        final threatsOnLeft = action == null && threats.isNotEmpty
            ? threats.first.piece.color == widget.viewerSide
            : !actorOnLeft;
        final headerHeight = math.min(short ? 23.0 : 29.0, size.height * .22);
        final bodyHeight = math.max(0.0, size.height - headerHeight - 5);
        final figureBodyHeight = animatedFigureBodyHeight(
          theme: widget.theme,
          space: Size(
            size.width * .3,
            bodyHeight - math.min(20.0, bodyHeight * .16),
          ),
        );
        final columnWidth = math.min(210.0, size.width * .32);
        final leftCenter =
            size.width * (hasThreatColumn && threatsOnLeft ? .48 : .25);
        final rightCenter =
            size.width * (hasThreatColumn && !threatsOnLeft ? .52 : .75);
        final leftPiece = action?.actorOnLeft == true
            ? action!.actor
            : action?.captured;
        final rightPiece = action?.actorOnLeft == false
            ? action!.actor
            : action?.captured;
        final checkmate = widget.position.isCheckmate;
        final castling =
            action != null && !action.isSelection && action.castling != null;
        final title = checkmate
            ? 'CHECKMATE'
            : action == null
            ? widget.position.isCheck
                  ? 'KING IN CHECK'
                  : widget.theme.displayName.toUpperCase()
            : '${action.isSelection
                      ? 'SELECTED'
                      : castling
                      ? 'CASTLING'
                      : 'LAST MOVE'} · '
                  '${action.actor.color.name.toUpperCase()} ${action.actor.role.name.toUpperCase()}';
        final route = action == null
            ? '${widget.viewerSide.name.toUpperCase()} · YOUR ARMY'
            : action.target == null
            ? action.source.name.toUpperCase()
            : '${action.source.name.toUpperCase()} → ${action.target!.name.toUpperCase()}';
        return ClipRRect(
          key: const ValueKey('neon-live-arena'),
          borderRadius: BorderRadius.circular(12),
          child: Semantics(
            label: action == null
                ? '$title. $route. Select a piece to show its character.'
                : '$title. $route. ${action.actor.color.name} '
                      '${action.actor.role.name} appears on the '
                      '${actorOnLeft ? 'left' : 'right'}.',
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: _night),
                IgnorePointer(
                  child: Transform.scale(
                    scale: 1.04,
                    child: Image.asset(
                      widget.theme.worldAsset,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, .2),
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, _, _) => ColoredBox(color: _night),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _night.withValues(alpha: .53),
                          _night.withValues(alpha: .13),
                          _night.withValues(alpha: .75),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  top: 3,
                  height: headerHeight,
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  key: const ValueKey('neon-live-heading'),
                                  style: TextStyle(
                                    color: checkmate
                                        ? _gold
                                        : widget.viewerSide == Side.white
                                        ? _cyan
                                        : _pink,
                                    fontSize: short ? 9 : 11,
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (checkmate)
                                  Text(
                                    'VICTORY · ${widget.position.turn.opposite.name.toUpperCase()}',
                                    key: const ValueKey('neon-live-victory'),
                                    style: TextStyle(
                                      color: _gold,
                                      fontSize: short ? 9 : 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            key: const ValueKey('neon-live-route'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                action?.source.name.toUpperCase() ?? route,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (action?.target != null) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    Icons.arrow_forward,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  action!.target!.name.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: headerHeight + 3,
                  height: bodyHeight,
                  child: Stack(
                    children: [
                      if (checkmate)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              key: const ValueKey(
                                'animated-live-victory-effect',
                              ),
                              painter: AnimatedArmyVictoryPainter(
                                theme: widget.theme,
                                winner: widget.position.turn.opposite,
                                winnerOnLeft:
                                    widget.position.turn.opposite ==
                                    widget.viewerSide,
                                progress: p,
                                reducedMotion: _reduced,
                              ),
                            ),
                          ),
                        ),
                      if (castling)
                        Positioned.fill(
                          child: AnimatedCastlingPresentation(
                            action: action,
                            theme: widget.theme,
                            progress: p,
                            figureBodyHeight: figureBodyHeight,
                            actorCenter:
                                (actorOnLeft ? leftCenter : rightCenter) /
                                size.width,
                            startKingCenter: _startActorPose?.x,
                            reducedMotion: _reduced,
                          ),
                        ),
                      if (!castling && leftPiece != null)
                        _figure(
                          size,
                          bodyHeight,
                          leftPiece,
                          leftCenter,
                          true,
                          p,
                          active: action?.actorOnLeft == true,
                          captured: !actorOnLeft && action?.captured != null,
                          figureBodyHeight: figureBodyHeight,
                          selected: action?.isSelection == true,
                        ),
                      if (!castling && rightPiece != null)
                        _figure(
                          size,
                          bodyHeight,
                          rightPiece,
                          rightCenter,
                          false,
                          p,
                          active: action?.actorOnLeft == false,
                          captured: actorOnLeft && action?.captured != null,
                          figureBodyHeight: figureBodyHeight,
                          selected: action?.isSelection == true,
                        ),
                      if (action != null && !castling)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              key: const ValueKey('neon-live-action-emphasis'),
                              painter: _LiveEmphasisPainter(
                                from: Offset(
                                  (_renderedActorPose?.x ??
                                          (actorOnLeft
                                                  ? leftCenter
                                                  : rightCenter) /
                                              size.width) *
                                      size.width,
                                  bodyHeight *
                                      (.45 + (_renderedActorPose?.y ?? 0)),
                                ),
                                to: Offset(
                                  actorOnLeft ? rightCenter : leftCenter,
                                  bodyHeight * .55,
                                ),
                                progress: p,
                                color: action.actor.color == Side.white
                                    ? _cyan
                                    : _pink,
                                capture: action.captured != null,
                                movement: !action.isSelection,
                                reduced: _reduced,
                                theme: widget.theme,
                                role: action.actor.role,
                              ),
                            ),
                          ),
                        ),
                      if (threats.isNotEmpty)
                        Positioned(
                          left: threatsOnLeft
                              ? 5
                              : size.width - columnWidth - 5,
                          top: 0,
                          bottom: 0,
                          width: columnWidth,
                          child: Opacity(
                            key: const ValueKey('neon-live-threat-transition'),
                            opacity: threatsOpacity,
                            child: IgnorePointer(
                              ignoring: threatsOpacity < .05,
                              child: _pager(threats, short, threatsOnLeft),
                            ),
                          ),
                        ),
                      if (action != null &&
                          action.isSelection &&
                          _selectionReply != null)
                        Positioned(
                          left: actorOnLeft ? 6 : size.width * .35,
                          right: actorOnLeft ? size.width * .35 : 6,
                          bottom: math.min(20.0, bodyHeight * .16) + 3,
                          height: math.min(
                            short ? 30.0 : 44.0,
                            bodyHeight * .37,
                          ),
                          child: IgnorePointer(
                            child: Semantics(
                              liveRegion: true,
                              label:
                                  '${action.actor.role.name}: $_selectionReply',
                              child: Container(
                                key: const ValueKey(
                                  'neon-live-selection-bubble',
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF23374E,
                                  ).withValues(alpha: .95),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        (action.actor.color == Side.white
                                                ? _cyan
                                                : _pink)
                                            .withValues(alpha: .75),
                                  ),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SizedBox(
                                    width: math.max(1.0, size.width * .65 - 24),
                                    child: Text(
                                      _selectionReply!,
                                      key: const ValueKey(
                                        'neon-live-selection-comment',
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        height: 1.15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  _ActorPose _actorPose(
    Size size,
    double center,
    bool onLeft,
    double progress,
  ) {
    final base = center / size.width;
    final direction = onLeft ? 1.0 : -1.0;
    final start =
        _startActorPose ?? _ActorPose(x: base - direction * 14 / size.width);
    final action = widget.action!;
    if (action.isSelection) {
      return _ActorPose(x: base);
    }
    final target = action.target!;
    final files = (target.file.value - action.source.file.value).abs();
    final ranks = (target.rank.value - action.source.rank.value).abs();
    final routeLength = math.max(files, ranks) / 7;
    final strideFactor = switch (widget.theme) {
      AnimatedArmyTheme.manga => 1.2,
      AnimatedArmyTheme.epic => .95,
      AnimatedArmyTheme.olympian => .85,
      AnimatedArmyTheme.neon => 1.0,
    };
    final stride = direction * (.032 + routeLength * .024) * strideFactor;
    final leap = action.actor.role == Role.knight
        ? -.045
        : widget.theme == AnimatedArmyTheme.manga
        ? -.025
        : -.018;
    final landed = _ActorPose(x: base + stride);
    // One accepted move has one travel. Finish the leap and lean as that
    // stride lands, then keep its position while attack/defeat effects finish.
    // Returning toward the original lane created an unwanted second shuffle.
    if (progress >= animatedMoveImpactFraction) return landed;
    final seconds =
        animatedMoveDuration.inMicroseconds / Duration.microsecondsPerSecond;
    final travel = (progress / animatedMoveImpactFraction).clamp(0.0, 1.0);
    final pose = _ActorPose.hermite(
      start,
      landed,
      _startActorVelocity,
      travel,
      seconds * animatedMoveImpactFraction,
    );
    final remaining = 1 - travel;
    final arc = 16 * travel * travel * remaining * remaining;
    return _ActorPose(
      x: pose.x,
      y: pose.y + leap * arc,
      scale: pose.scale,
      lean: pose.lean + direction * .055 * arc,
    );
  }

  _ActorVelocity _actorVelocity(
    Size size,
    double center,
    bool onLeft,
    double progress,
  ) {
    if (_reduced || widget.action?.isSelection == true) {
      return _ActorVelocity.zero;
    }
    const epsilon = .0001;
    final lower = (progress - epsilon).clamp(0.0, 1.0);
    final upper = (progress + epsilon).clamp(0.0, 1.0);
    final before = _actorPose(size, center, onLeft, lower);
    final after = _actorPose(size, center, onLeft, upper);
    final seconds =
        (_motion.duration!.inMicroseconds / Duration.microsecondsPerSecond) *
        (upper - lower);
    return _ActorVelocity(
      x: (after.x - before.x) / seconds,
      y: (after.y - before.y) / seconds,
      scale: (after.scale - before.scale) / seconds,
      lean: (after.lean - before.lean) / seconds,
    );
  }

  Widget _figure(
    Size size,
    double height,
    Piece piece,
    double center,
    bool onLeft,
    double progress, {
    required bool active,
    required bool captured,
    required double figureBodyHeight,
    required bool selected,
  }) {
    final labelHeight = math.min(20.0, height * .16);
    final landed = _reduced || progress >= animatedMoveImpactFraction;
    final wonCapture = active && widget.action?.captured != null && landed;
    final defeat = captured
        ? _reduced
              ? 1.0
              : Curves.easeOutCubic.transform(
                  ((_motion.value - animatedMoveImpactFraction) /
                          (1 - animatedMoveImpactFraction))
                      .clamp(0.0, 1.0),
                )
        : 0.0;
    // Actor and victim share a physical body size. Threats and outcomes
    // change emphasis, never the size of a defeated or victorious unit.
    final width = size.width * .3;
    final pose = active
        ? _actorPose(size, center, onLeft, progress)
        : _ActorPose(x: center / size.width);
    if (active) {
      _renderedActorPose = pose;
      _renderedActorVelocity = _actorVelocity(size, center, onLeft, progress);
    }
    return Positioned(
      left: pose.x * size.width - width * .5,
      top: 0,
      bottom: 0,
      width: width,
      child: IgnorePointer(
        child: Column(
          key: captured ? const ValueKey('neon-live-capture-slot') : null,
          children: [
            Expanded(
              child: ClipRect(
                clipBehavior: active ? Clip.none : Clip.hardEdge,
                child: Transform.translate(
                  key: captured
                      ? const ValueKey('neon-live-defeat-drop')
                      : active
                      ? const ValueKey('neon-live-actor-pose')
                      : null,
                  offset: Offset(
                    0,
                    height * (captured ? .045 * defeat : pose.y),
                  ),
                  child: Transform.rotate(
                    alignment: Alignment.bottomCenter,
                    key: captured
                        ? const ValueKey('neon-live-defeat-pose')
                        : active
                        ? const ValueKey('neon-live-actor-lean')
                        : null,
                    angle: captured
                        ? (onLeft ? -.14 : .14) * defeat
                        : pose.lean,
                    child: Transform.scale(
                      alignment: Alignment.bottomCenter,
                      key: captured
                          ? const ValueKey('neon-live-defeat-scale')
                          : active
                          ? const ValueKey('neon-live-actor-scale')
                          : null,
                      scale: captured ? 1 : pose.scale,
                      child: Opacity(
                        key: captured
                            ? const ValueKey('neon-live-defeat-opacity')
                            : null,
                        opacity: captured
                            ? (_reduced
                                      ? 1.0
                                      : _smoothStep(
                                          (progress / .25).clamp(0.0, 1.0),
                                        )) *
                                  (1 - .52 * defeat)
                            : 1,
                        child: NeonFigureSprite(
                          key: ValueKey(
                            'neon-live-${onLeft ? 'left' : 'right'}-figure',
                          ),
                          piece: piece,
                          faceRight: onLeft,
                          theme: widget.theme,
                          bodyHeight: figureBodyHeight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: labelHeight,
              child: Opacity(
                opacity: captured && !landed ? 0 : 1,
                child: ExcludeSemantics(
                  excluding: captured && !landed,
                  child: FittedBox(
                    key: captured && landed
                        ? const ValueKey('neon-live-capture-defeated')
                        : wonCapture
                        ? const ValueKey('neon-live-capture-winner')
                        : null,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${captured
                          ? 'DEFEATED'
                          : wonCapture
                          ? 'WINNER'
                          : selected
                          ? 'SELECTED'
                          : onLeft
                          ? 'YOU'
                          : 'OPPONENT'}\n'
                      '${piece.color.name.toUpperCase()} ${piece.role.name.toUpperCase()}',
                      key: ValueKey(
                        'neon-live-${onLeft ? 'left' : 'right'}-label',
                      ),
                      semanticsLabel: captured
                          ? '${piece.color.name} ${piece.role.name} is defeated in this capture.'
                          : wonCapture
                          ? '${piece.color.name} ${piece.role.name} wins this capture.'
                          : null,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: captured
                            ? const Color(0xFFFF6E83)
                            : wonCapture
                            ? _gold
                            : Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: _night, blurRadius: 6)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pager(List<_ArenaThreat> threats, bool short, bool onLeft) {
    final pages = (threats.length + 2) ~/ 3;
    final page = math.min(_page, pages - 1);
    return LayoutBuilder(
      builder: (context, box) {
        final controlsHeight = pages > 1
            ? math.min(26.0, box.maxHeight * .22)
            : 0.0;
        return Column(
          key: const ValueKey('neon-live-threats'),
          children: [
            Expanded(
              child: Column(
                children: [
                  for (final threat in threats.skip(page * 3).take(3))
                    Expanded(
                      child: _LiveThreatPortrait(
                        threat: threat,
                        short: short,
                        faceRight: onLeft,
                        checkmated:
                            widget.position.isCheckmate &&
                            threat.isCheck &&
                            threat.piece.color == widget.position.turn,
                        theme: widget.theme,
                      ),
                    ),
                ],
              ),
            ),
            if (pages > 1)
              SizedBox(
                height: controlsHeight,
                child: Row(
                  children: [
                    _pageButton(true, page > 0, controlsHeight),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${page + 1} / $pages',
                          key: const ValueKey('neon-live-threat-page'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    _pageButton(false, page + 1 < pages, controlsHeight),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _pageButton(bool previous, bool enabled, double height) => SizedBox(
    width: height * 1.2,
    height: height,
    child: IconButton(
      key: ValueKey(
        previous ? 'neon-live-threat-prev' : 'neon-live-threat-next',
      ),
      tooltip: previous
          ? 'Previous threatened pieces'
          : 'Next threatened pieces',
      onPressed: !enabled
          ? null
          : () => setState(() => _page += previous ? -1 : 1),
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(
        previous ? Icons.chevron_left : Icons.chevron_right,
        color: enabled ? Colors.white : Colors.white38,
        size: height * .85,
      ),
    ),
  );
}

class _ActorPose {
  const _ActorPose({
    required this.x,
    this.y = 0,
    this.scale = 1,
    this.lean = 0,
  });
  final double x;
  final double y;
  final double scale;
  final double lean;

  static _ActorPose hermite(
    _ActorPose from,
    _ActorPose to,
    _ActorVelocity velocity,
    double t,
    double seconds,
  ) {
    final p = t.clamp(0.0, 1.0);
    final a = 2 * p * p * p - 3 * p * p + 1;
    final b = p * p * p - 2 * p * p + p;
    final c = -2 * p * p * p + 3 * p * p;
    return _ActorPose(
      x: a * from.x + b * velocity.x * seconds + c * to.x,
      y: a * from.y + b * velocity.y * seconds + c * to.y,
      scale: a * from.scale + b * velocity.scale * seconds + c * to.scale,
      lean: a * from.lean + b * velocity.lean * seconds + c * to.lean,
    );
  }
}

class _ActorVelocity {
  const _ActorVelocity({this.x = 0, this.y = 0, this.scale = 0, this.lean = 0});
  static const zero = _ActorVelocity();
  final double x, y, scale, lean;
}

double _smoothStep(double p) => p * p * p * (p * (6 * p - 15) + 10);

class _ArenaThreat {
  const _ArenaThreat({
    required this.piece,
    required this.square,
    this.destinations = const {},
    this.isCheck = false,
    this.possibleCheck = false,
  });
  final Piece piece;
  final Square square;
  final Set<Square> destinations;
  final bool isCheck;
  final bool possibleCheck;
}

class _LiveThreatPortrait extends StatelessWidget {
  const _LiveThreatPortrait({
    required this.threat,
    required this.short,
    required this.faceRight,
    required this.checkmated,
    required this.theme,
  });
  final _ArenaThreat threat;
  final bool short;
  final bool faceRight;
  final bool checkmated;
  final AnimatedArmyTheme theme;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final king = threat.isCheck || threat.possibleCheck;
      final color = threat.isCheck ? Color(theme.blackColorArgb) : _gold;
      final diameter = math.max(
        1.0,
        math.min(box.maxWidth * .53, box.maxHeight - 4),
      );
      final label =
          '${threat.isCheck
              ? checkmated
                    ? 'CHECKMATED'
                    : 'CHECK'
              : threat.possibleCheck
              ? 'POSSIBLE\nCHECK'
              : threat.piece.role.name.toUpperCase()}\n${threat.square.name.toUpperCase()}';
      final description =
          '${threat.piece.color.name} ${threat.piece.role.name} on ${threat.square.name}. '
          '${threat.isCheck
              ? checkmated
                    ? 'King is checkmated, never captured.'
                    : 'King in check, never captured.'
              : threat.possibleCheck
              ? 'A legal move can give check; the king is never captured.'
              : 'Legal capture available.'}'
          '${threat.destinations.isEmpty ? '' : ' Legal move destinations: ${threat.destinations.map((square) => square.name).join(', ')}.'}';
      return Semantics(
        label: description,
        child: Tooltip(
          message: description,
          child: Row(
            key: ValueKey('neon-live-threat-${threat.square.name}'),
            children: [
              Container(
                key: ValueKey(
                  'neon-live-threat-portrait-${threat.square.name}',
                ),
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _night.withValues(alpha: .8),
                  border: Border.all(color: color, width: king ? 2 : 1.3),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: .22),
                      blurRadius: king ? 12 : 6,
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipOval(
                      child: Transform.scale(
                        scale: 1.9,
                        alignment: const Alignment(0, -.55),
                        child: NeonFigureSprite(
                          piece: threat.piece,
                          faceRight: faceRight,
                          theme: theme,
                        ),
                      ),
                    ),
                    if (king)
                      CustomPaint(
                        key: ValueKey(
                          threat.isCheck
                              ? 'neon-live-check-aura-${threat.square.name}'
                              : 'neon-live-possible-check-aura-${threat.square.name}',
                        ),
                        painter: _LiveKingAuraPainter(
                          color: color,
                          possible: threat.possibleCheck,
                          theme: theme,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    key: ValueKey(
                      'neon-live-threat-label-${threat.square.name}',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontSize: short ? 8 : 11,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      shadows: const [Shadow(color: _night, blurRadius: 5)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _LiveKingAuraPainter extends CustomPainter {
  const _LiveKingAuraPainter({
    required this.color,
    required this.possible,
    required this.theme,
  });
  final Color color;
  final bool possible;
  final AnimatedArmyTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * .43;
    final paint = Paint()
      ..color = color.withValues(alpha: .8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    if (theme != AnimatedArmyTheme.neon) {
      paintAnimatedArmyKingAura(
        canvas,
        size,
        theme: theme,
        color: color,
        possible: possible,
      );
      return;
    }
    if (possible) {
      for (var i = 0; i < 8; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          i * math.pi / 4,
          math.pi / 7,
          false,
          paint,
        );
      }
    } else {
      canvas.drawCircle(center, radius, paint);
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        final delta = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(
          center + delta * radius * .77,
          center + delta * radius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LiveKingAuraPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.possible != possible ||
      oldDelegate.theme != theme;
}

class _LiveEmphasisPainter extends CustomPainter {
  const _LiveEmphasisPainter({
    required this.from,
    required this.to,
    required this.progress,
    required this.color,
    required this.capture,
    required this.movement,
    required this.reduced,
    required this.theme,
    required this.role,
  });
  final Offset from;
  final Offset to;
  final double progress;
  final Color color;
  final bool capture;
  final bool movement;
  final bool reduced;
  final AnimatedArmyTheme theme;
  final Role role;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(26.0, size.height * .13);
    if (capture && theme != AnimatedArmyTheme.neon) {
      paintAnimatedArmyAttack(
        canvas,
        size,
        theme: theme,
        from: from,
        to: to,
        progress: progress,
        accent: color,
        role: role,
        reducedMotion: reduced,
        landingProgress: animatedMoveImpactFraction,
      );
      return;
    }
    if (reduced) {
      canvas.drawCircle(
        from,
        radius,
        Paint()
          ..color = color.withValues(alpha: .4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      if (capture) {
        canvas.drawCircle(
          to,
          radius * .8,
          Paint()
            ..color = _gold.withValues(alpha: .5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      return;
    }
    if (progress >= 1) return;
    final alpha = math.sin(progress * math.pi) * .8;
    canvas.drawCircle(
      from,
      radius * (.65 + progress * .6),
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    if (!capture) {
      if (movement) {
        final direction = to.dx >= from.dx ? 1.0 : -1.0;
        final foot = Offset(from.dx, size.height * .90);
        canvas.drawLine(
          foot - Offset(direction * radius * 1.7, 0),
          foot + Offset(direction * radius * .9, 0),
          Paint()
            ..color = color.withValues(alpha: alpha * .6)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
      return;
    }
    canvas.drawLine(
      from,
      Offset.lerp(
        from,
        to,
        _smoothStep((progress / animatedMoveImpactFraction).clamp(0.0, 1.0)),
      )!,
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    if (progress >= animatedMoveImpactFraction) {
      canvas.drawCircle(
        to,
        radius * (.6 + (progress - animatedMoveImpactFraction) * 1.2),
        Paint()
          ..color = _gold.withValues(alpha: alpha * (1 - progress))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.drawCircle(
      to,
      radius * (.5 + progress),
      Paint()
        ..color = color.withValues(alpha: alpha * .45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_LiveEmphasisPainter oldDelegate) =>
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.capture != capture ||
      oldDelegate.movement != movement ||
      oldDelegate.reduced != reduced ||
      oldDelegate.theme != theme ||
      oldDelegate.role != role;
}
