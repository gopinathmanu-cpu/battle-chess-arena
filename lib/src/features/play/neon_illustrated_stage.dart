// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../domain/cinematic_replay.dart';
import '../../domain/cinematic_threats.dart';
import '../../domain/animated_army_theme.dart';

const _ice = Color(0xFF83F8EF);
const _rose = Color(0xFFFF6ACB);
const _ink = Color(0xFF070B19);
const _routeText = TextStyle(
  color: Color(0xFFDFE8F2),
  fontSize: 10,
  fontWeight: FontWeight.w600,
  letterSpacing: 1.3,
);

/// A layered, illustrated film stage. All action comes from a validated ply;
/// camera cuts never turn a check into a capture or invent an opposing piece.
class NeonIllustratedStage extends StatelessWidget {
  const NeonIllustratedStage({
    required this.scene,
    required this.progress,
    required this.intro,
    required this.finale,
    required this.reducedMotion,
    required this.title,
    required this.subtitle,
    required this.resultTitle,
    this.winnerSide,
    this.compact = false,
    this.captionInset,
    this.threats = const [],
    this.theme = AnimatedArmyTheme.neon,
    super.key,
  });

  final CinematicReplayScene? scene;
  final double progress;
  final bool intro;
  final bool finale;
  final bool reducedMotion;
  final String title;
  final String subtitle;
  final String resultTitle;
  final Side? winnerSide;
  final bool compact;
  final double? captionInset;
  final List<CinematicThreat> threats;
  final AnimatedArmyTheme theme;
  Color get _ice => Color(theme.whiteColorArgb);
  Color get _rose => Color(theme.blackColorArgb);
  Color get _ink => Color(theme.baseColorArgb);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final tall = size.height > size.width * .95;
      final p = progress.clamp(0.0, 1.0);
      final motion = reducedMotion ? .76 : p;
      final side = scene?.side ?? Side.white;
      final accent = side == Side.white ? _ice : _rose;
      final cut = _shot(scene, motion);
      final push = reducedMotion ? 0.0 : _ease(motion);
      final cameraScale = switch (cut) {
        _Shot.establishing => 1.03 + push * .04,
        _Shot.portrait => 1.14 + push * .05,
        _Shot.impact => 1.2,
        _Shot.aftermath => 1.08 + push * .03,
      };
      final cameraX = reducedMotion
          ? 0.0
          : (side == Side.white ? -1 : 1) * (push - .5) * 24;
      final veryShort = compact && size.height < 180;
      final stageTop = compact
          ? (veryShort ? 4.0 : 12.0)
          : (tall ? 44.0 : 26.0);
      final captionSpace =
          captionInset ??
          (compact
              ? (veryShort
                    ? 45.0
                    : size.height < 280
                    ? 65.0
                    : 90.0)
              : size.height * .28);
      final actionSize = Size(
        size.width,
        math.max(0, size.height - stageTop - captionSpace),
      );
      return ClipRect(
        key: const ValueKey('neon-illustrated-stage'),
        child: Semantics(
          label: intro
              ? '${theme.displayName} prologue with the two core kings'
              : finale
              ? '${theme.displayName} epilogue. $resultTitle'
              : '${scene?.side.name} ${scene?.resolution.attacker.role.name}, '
                    '${scene?.source.name} to ${scene?.target.name}',
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: _ink),
              Transform.translate(
                offset: Offset(cameraX, reducedMotion ? 0 : -push * 8),
                child: Transform.scale(
                  scale: cameraScale,
                  child: Image.asset(
                    theme.worldAsset,
                    fit: BoxFit.cover,
                    alignment: tall ? const Alignment(.2, 0) : Alignment.center,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, trace) => DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _ice.withValues(alpha: .25),
                            _ink,
                            _rose.withValues(alpha: .25),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // A painted background stays visible between the two factions;
              // soft light separates the illustrations from the city itself.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _ink.withValues(alpha: .2),
                      _ink.withValues(alpha: .02),
                      _ink.withValues(alpha: .7),
                      _ink,
                    ],
                    stops: const [0, .3, .72, 1],
                  ),
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _AtmospherePainter(
                    progress: motion,
                    accent: accent,
                    moving: !reducedMotion,
                    theme: theme,
                  ),
                ),
              ),
              // Frame the city behind the actors, keeping edge portraits and
              // their threat labels as bright as the encounter stamps.
              Positioned(
                left: 0,
                right: 0,
                top: stageTop,
                height: actionSize.height,
                child: intro || finale
                    ? _bookend(actionSize, motion, tall)
                    : _action(
                        actionSize,
                        p,
                        cut,
                        tall,
                        metadataVisible: !veryShort,
                      ),
              ),
              if (!reducedMotion && !intro && !finale)
                IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: _cutOpacity(p)),
                  ),
                ),
              if (!veryShort)
                Positioned(
                  left: 20,
                  right: 20,
                  top: compact ? 10 : 72,
                  child: Row(
                    children: [
                      Container(width: 18, height: 2, color: accent),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _chapterLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2,
                            shadows: const [Shadow(blurRadius: 10)],
                          ),
                        ),
                      ),
                      if (scene != null)
                        Row(
                          key: const ValueKey('neon-move-route'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              scene!.source.name.toUpperCase(),
                              style: _routeText,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              child: Icon(
                                Icons.arrow_forward,
                                size: 12,
                                color: Color(0xFFDFE8F2),
                              ),
                            ),
                            Text(
                              scene!.target.name.toUpperCase(),
                              style: _routeText,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              if (title.isNotEmpty || subtitle.isNotEmpty)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: tall ? 28 : 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        intro
                            ? theme.displayName.toUpperCase()
                            : finale
                            ? 'THE WORLD REMEMBERS'
                            : '${(side == Side.white ? theme.whiteFaction : theme.blackFaction).toUpperCase()}  /  ${scene!.san}',
                        style: TextStyle(
                          fontSize: 9,
                          color: accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.6,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        title,
                        key: const ValueKey('cinematic-headline'),
                        maxLines: tall ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize:
                              (intro || finale ? 32.0 : 27.0) *
                              (size.width < 370 ? .88 : 1),
                          height: 1.02,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.8,
                          color: Colors.white,
                          shadows: [Shadow(blurRadius: 14, color: _ink)],
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        Text(
                          subtitle,
                          maxLines: tall ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFFBDCCD9),
                            fontSize: 12,
                            height: 1.35,
                            shadows: [Shadow(blurRadius: 8, color: _ink)],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              // Small framing bars, rather than a boxed stage, leave the city
              // and foreground artwork full bleed at every phone aspect ratio.
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 5,
                child: ColoredBox(color: Colors.black),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 5,
                child: ColoredBox(color: Colors.black),
              ),
            ],
          ),
        ),
      );
    },
  );

  String get _chapterLabel {
    if (intro) return 'A BATTLE CHESS ARENA FILM';
    if (finale) return 'EPILOGUE';
    final s = scene!;
    final heading = s.isCheckmate
        ? 'THE FINAL STAND'
        : s.isPromotion
        ? 'ASCENSION'
        : s.isCastling
        ? 'THE FORTRESS'
        : s.isCapture
        ? 'THE STRIKE'
        : s.isCheck
        ? 'THE WARNING'
        : 'THE ADVANCE';
    return 'CHAPTER ${s.ply.toString().padLeft(2, '0')}  /  $heading';
  }

  _Shot _shot(CinematicReplayScene? s, double p) {
    if (s == null) return _Shot.establishing;
    if (reducedMotion) return _Shot.aftermath;
    if (p < .24) return s.ply.isEven ? _Shot.portrait : _Shot.establishing;
    if (p < .64) {
      return s.isCapture || s.isPromotion || s.isCheck
          ? _Shot.impact
          : s.resolution.attacker.role == Role.rook || s.isCastling
          ? _Shot.establishing
          : _Shot.portrait;
    }
    return _Shot.aftermath;
  }

  Widget _bookend(Size size, double p, bool tall) {
    final h = math.min(size.height * .9, size.width * (tall ? 1.25 : .84));
    final w = h * .54;
    final arrival = reducedMotion ? 1.0 : _ease((p / .5).clamp(0.0, 1.0));
    final victor = finale
        ? cinematicWinner(
            resultTitle: resultTitle,
            finalPosition: scene?.after,
            winnerSide: winnerSide,
          )
        : null;
    final whiteWins = victor == Side.white;
    final blackWins = victor == Side.black;
    final bodyHeight = animatedFigureBodyHeight(
      theme: theme,
      space: Size(w, h),
      pieces: const [Piece.whiteKing, Piece.blackKing],
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (victor != null)
          Positioned.fill(
            child: Semantics(
              label: '${victor.name} victory celebration',
              child: CustomPaint(
                key: ValueKey('neon-victory-${victor.name}'),
                painter: _VictoryPainter(
                  winner: victor,
                  progress: reducedMotion ? .76 : p,
                  reduced: reducedMotion,
                  theme: theme,
                ),
              ),
            ),
          ),
        Positioned(
          left: size.width * (tall ? .04 : .13) - (1 - arrival) * 24,
          top: size.height - h,
          width: w,
          height: h,
          child: Opacity(
            opacity: blackWins ? .45 : 1,
            child: NeonFigureSprite(
              key: const ValueKey('film-leader-white'),
              bodyHeight: bodyHeight,
              piece: const Piece(color: Side.white, role: Role.king),
              faceRight: true,
              theme: theme,
            ),
          ),
        ),
        Positioned(
          right: size.width * (tall ? .02 : .12) - (1 - arrival) * 24,
          top: size.height - h,
          width: w,
          height: h,
          child: Opacity(
            opacity: whiteWins ? .45 : .92,
            child: NeonFigureSprite(
              key: const ValueKey('film-leader-black'),
              bodyHeight: bodyHeight,
              piece: const Piece(color: Side.black, role: Role.king),
              faceRight: false,
              theme: theme,
            ),
          ),
        ),
        if (finale)
          Center(
            child: Container(
              width: size.width * .82,
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _ice.withValues(alpha: 0),
                    _ice.withValues(alpha: .65),
                    _rose.withValues(alpha: .65),
                    _rose.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _action(
    Size size,
    double p,
    _Shot cut,
    bool tall, {
    required bool metadataVisible,
  }) {
    final s = scene!;
    final attacker = s.resolution.attacker;
    final accent = s.side == Side.white ? _ice : _rose;
    final whiteMoves = s.side == Side.white;
    final direction = whiteMoves ? 1.0 : -1.0;
    final tiny = compact && size.height < 90;
    final landed = p >= .56;
    final showThreats = landed && threats.isNotEmpty;
    final hasThreatColumn = !s.isCastling && threats.isNotEmpty;
    final bubbleTop = tiny
        ? 0.0
        : compact
        ? (metadataVisible ? 20.0 : 0.0)
        : (metadataVisible ? 54.0 : 4.0);
    final bubbleHeight = math.max(0.0, size.height - bubbleTop - 2);
    final bubbleWidth = math.min(260.0, math.max(0.0, size.width * .32 - 8));
    final stampHeight = math.min(tiny ? 12.0 : 22.0, size.height * .22);
    final headroom = math.min(
      compact ? (tiny ? 16.0 : 32.0) : 24.0,
      size.height * .3,
    );
    final motion = reducedMotion ? .76 : p;
    final approach = _ease(((motion - .16) / .48).clamp(0.0, 1.0));
    final close = cut == _Shot.impact || cut == _Shot.portrait;
    final h = math.min(
      math.max(0.0, size.height - headroom) * (close ? 1 : .95),
      size.width * (tall ? 1.55 : 1.05),
    );
    final w = math.min(h * .69, size.width * (s.isCastling ? .26 : .38));
    final center = size.width * .5;
    final attackX =
        size.width *
        (whiteMoves
            ? (s.isCastling ? .16 : .24) + approach * .07
            : (s.isCastling ? .84 : .76) - approach * .07);
    final defendX =
        size.width *
        (s.isCastling
            ? (whiteMoves ? .40 : .60)
            : hasThreatColumn
            ? (whiteMoves ? .55 : .45)
            : (whiteMoves ? .75 : .25));
    final baseY = size.height - h;
    final knightLeap = attacker.role == Role.knight && !reducedMotion
        ? math.sin(approach * math.pi) * math.min(32, size.height * .08)
        : 0.0;
    final opponent = s.isCastling
        ? Piece(color: s.side, role: Role.rook)
        : s.resolution.defender ??
              (s.isCheck && !landed
                  ? Piece(color: s.side.opposite, role: Role.king)
                  : null);
    // Captures keep the actual victim as a full figure. A check on the surviving
    // king is a separate threat bubble and never receives a defeat stamp.
    final victimWidth = w;
    final victimHeight = h;
    final victimTop = size.height - h;
    final defeatedStampWidth = math.min(
      victimWidth * 1.2,
      size.width * (hasThreatColumn ? .22 : .4),
    );
    final bodyHeight = animatedFigureBodyHeight(
      theme: theme,
      space: Size(math.min(w, size.width * (hasThreatColumn ? .26 : .34)), h),
    );
    final transformed = s.isPromotion && landed;
    final hero = transformed
        ? Piece(color: attacker.color, role: s.resolution.move.promotion!)
        : attacker;
    final strike = reducedMotion
        ? 0.0
        : math.sin(((p - .37) / .28).clamp(0.0, 1.0) * math.pi);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _ActionPainter(
              from: Offset(attackX, size.height * .57),
              to: Offset(
                opponent == null
                    ? center + direction * size.width * .29
                    : defendX,
                size.height * .55,
              ),
              progress: p,
              strike: strike,
              accent: accent,
              role: attacker.role,
              capture: s.isCapture,
              castle: s.isCastling,
              promotion: s.isPromotion,
              check: s.isCheck,
              reduced: reducedMotion,
              theme: theme,
            ),
          ),
        ),
        if (opponent != null)
          Positioned(
            left: defendX - victimWidth * .5,
            top: victimTop,
            width: victimWidth,
            height: victimHeight,
            child: Opacity(
              opacity: s.isCapture && landed ? .68 : 1,
              child: NeonFigureSprite(
                key: ValueKey(
                  'film-victim-${opponent.color.name}-${opponent.role.name}',
                ),
                piece: opponent,
                bodyHeight: bodyHeight,
                faceRight: opponent.color == Side.white,
                theme: theme,
              ),
            ),
          ),
        Positioned(
          left: attackX - w * .5,
          top: baseY - knightLeap,
          width: w,
          height: h,
          child: NeonFigureSprite(
            key: ValueKey('film-hero-${hero.color.name}-${hero.role.name}'),
            piece: hero,
            bodyHeight: bodyHeight,
            faceRight: hero.color == Side.white,
            theme: theme,
          ),
        ),
        if (s.isCapture)
          Positioned.fill(
            child: IgnorePointer(
              child: Semantics(
                label:
                    '${s.side.name} ${attacker.role.name} strikes the '
                    'captured ${s.resolution.defender!.role.name} on ${s.captureSquare!.name}',
                child: CustomPaint(
                  key: const ValueKey('neon-capture-strike'),
                  painter: _CaptureStrikePainter(
                    from: Offset(attackX, baseY + h * .38),
                    to: Offset(defendX, victimTop + victimHeight * .42),
                    progress: p,
                    accent: accent,
                    reduced: reducedMotion,
                    theme: theme,
                    role: attacker.role,
                  ),
                ),
              ),
            ),
          ),
        if (s.isCapture && landed) ...[
          Positioned(
            left: math.max(0, attackX - size.width * .21),
            top: math.max(0, baseY - knightLeap - stampHeight),
            width: size.width * .42,
            height: stampHeight,
            child: _EncounterStamp(
              key: const ValueKey('neon-capture-winner'),
              label: 'WINNER',
              description:
                  '${hero.color.name} ${hero.role.name} wins this capture',
              color: accent,
              tiny: tiny,
            ),
          ),
          Positioned(
            left: (defendX - defeatedStampWidth * .5).clamp(
              0.0,
              size.width - defeatedStampWidth,
            ),
            top: math.max(0, victimTop - stampHeight),
            width: defeatedStampWidth,
            height: stampHeight,
            child: _EncounterStamp(
              key: const ValueKey('neon-capture-defeated'),
              label: 'DEFEATED',
              description:
                  '${opponent!.color.name} ${opponent.role.name} was captured on ${s.captureSquare!.name}',
              color: const Color(0xFFFF6E83),
              tiny: tiny,
            ),
          ),
        ],
        if (showThreats)
          Positioned(
            left: whiteMoves ? size.width - bubbleWidth - 8 : 8,
            top: bubbleTop,
            width: bubbleWidth,
            height: bubbleHeight,
            child: _ThreatPager(
              key: const ValueKey('neon-threat-bubbles'),
              scene: s,
              threats: threats,
              tiny: tiny,
              progress: p,
              reducedMotion: reducedMotion,
              theme: theme,
            ),
          ),
        if (transformed && !reducedMotion)
          Positioned(
            left: attackX - w * .6,
            top: baseY + h * .1,
            width: w * 1.2,
            height: h * .7,
            child: Opacity(
              opacity: (1 - ((p - .58) / .23).clamp(0.0, 1.0)) * .75,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: .4),
                      accent.withValues(alpha: .3),
                      accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  double _cutOpacity(double p) {
    for (final boundary in const [.24, .64]) {
      final distance = (p - boundary).abs();
      if (distance < .016) return (1 - distance / .016) * .5;
    }
    return 0;
  }
}

class _EncounterStamp extends StatelessWidget {
  const _EncounterStamp({
    required this.label,
    required this.description,
    required this.color,
    required this.tiny,
    super.key,
  });

  final String label;
  final String description;
  final Color color;
  final bool tiny;

  @override
  Widget build(BuildContext context) => Semantics(
    label: description,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: tiny ? 7 : 11, vertical: 3),
        decoration: BoxDecoration(
          color: _ink.withValues(alpha: .88),
          border: Border.all(color: color.withValues(alpha: .85)),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: .18), blurRadius: 7),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: tiny ? 8 : 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ),
    ),
  );
}

class _ThreatPager extends StatefulWidget {
  const _ThreatPager({
    required this.scene,
    required this.threats,
    required this.tiny,
    required this.progress,
    required this.reducedMotion,
    required this.theme,
    super.key,
  });
  final CinematicReplayScene scene;
  final List<CinematicThreat> threats;
  final bool tiny;
  final double progress;
  final bool reducedMotion;
  final AnimatedArmyTheme theme;

  @override
  State<_ThreatPager> createState() => _ThreatPagerState();
}

class _ThreatPagerState extends State<_ThreatPager> {
  int _page = 0;
  int get _pageCount => (widget.threats.length + 2) ~/ 3;

  String _identity(_ThreatPager widget) =>
      '${widget.theme.name}|${widget.scene.ply}|${widget.scene.before.fen}|${widget.scene.san}|'
      '${widget.threats.map((threat) => '${threat.piece.color.name}-${threat.piece.role.name}-${threat.square.name}-${threat.isCheck}').join(',')}';

  @override
  void didUpdateWidget(_ThreatPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_identity(oldWidget) != _identity(widget)) _page = 0;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final controlsHeight = _pageCount > 1
          ? math.min(32.0, box.maxHeight * .2)
          : 0.0;
      return Column(
        children: [
          Expanded(
            child: Column(
              children: [
                // The domain list already puts checks first. Paging slices that exact
                // order instead of re-ranking, duplicating or hiding future entries.
                for (final threat in widget.threats.skip(_page * 3).take(3))
                  Expanded(
                    child: _ThreatBubble(
                      key: ValueKey(
                        'neon-threat-${threat.piece.color.name}-${threat.piece.role.name}-${threat.square.name}',
                      ),
                      threat: threat,
                      tiny: widget.tiny,
                      progress: widget.progress,
                      reducedMotion: widget.reducedMotion,
                      theme: widget.theme,
                    ),
                  ),
              ],
            ),
          ),
          if (_pageCount > 1)
            SizedBox(
              height: controlsHeight,
              child: Row(
                children: [
                  _pageButton(previous: true, height: controlsHeight),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${_page + 1} / $_pageCount',
                          key: const ValueKey('neon-threat-page-count'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.tiny ? 7 : 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _pageButton(previous: false, height: controlsHeight),
                ],
              ),
            ),
        ],
      );
    },
  );

  Widget _pageButton({required bool previous, required double height}) =>
      SizedBox(
        width: height * 1.25,
        height: height,
        child: IconButton(
          key: ValueKey(
            previous ? 'neon-threat-page-prev' : 'neon-threat-page-next',
          ),
          tooltip: previous
              ? 'Previous threatened pieces'
              : 'Next threatened pieces',
          onPressed: previous
              ? (_page > 0 ? () => setState(() => _page--) : null)
              : (_page + 1 < _pageCount ? () => setState(() => _page++) : null),
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: Icon(
            previous ? Icons.chevron_left : Icons.chevron_right,
            size: math.min(23, height * .85),
            color: (previous ? _page > 0 : _page + 1 < _pageCount)
                ? Colors.white
                : Colors.white24,
          ),
        ),
      );
}

class _ThreatBubble extends StatelessWidget {
  const _ThreatBubble({
    required this.threat,
    required this.tiny,
    required this.progress,
    required this.reducedMotion,
    required this.theme,
    super.key,
  });
  final CinematicThreat threat;
  final bool tiny;
  final double progress;
  final bool reducedMotion;
  final AnimatedArmyTheme theme;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final color = threat.isCheck
          ? Color(theme.blackColorArgb)
          : const Color(0xFFFFCF73);
      final description =
          '${threat.piece.color.name} ${threat.piece.role.name} '
          'on ${threat.square.name} ${threat.isCheck ? 'in check' : 'under attack'}';
      final diameter = math.max(
        1.0,
        math.min(112.0, math.min(box.maxWidth * .61, box.maxHeight - 5)),
      );
      return Tooltip(
        message: description,
        child: Semantics(
          label: description,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                key: ValueKey('neon-threat-portrait-${threat.square.name}'),
                width: diameter,
                height: diameter,
                padding: EdgeInsets.all(math.min(2, diameter * .08)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _ink.withValues(alpha: .93),
                  border: Border.all(
                    color: color.withValues(
                      alpha: threat.newlyThreatened ? 1 : .8,
                    ),
                    width: threat.isCheck ? 2 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: .2),
                      blurRadius: 9,
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipOval(
                      child: Transform.scale(
                        scale: 2.05,
                        alignment: const Alignment(0, -.56),
                        child: NeonFigureSprite(
                          piece: threat.piece,
                          faceRight: threat.piece.color == Side.white,
                          theme: theme,
                        ),
                      ),
                    ),
                    if (threat.isCheck)
                      CustomPaint(
                        key: ValueKey('neon-check-aura-${threat.square.name}'),
                        painter: _CheckAuraPainter(
                          progress: reducedMotion ? .76 : progress,
                          reduced: reducedMotion,
                          theme: theme,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: math.min(6, box.maxWidth * .025)),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${threat.isCheck ? 'CHECK' : threat.piece.role.name.toUpperCase()}\n${threat.square.name.toUpperCase()}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color,
                        fontSize: tiny ? 8 : 14,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        shadows: const [Shadow(blurRadius: 4, color: _ink)],
                      ),
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

enum _Shot { establishing, portrait, impact, aftermath }

enum NeonFigurePose { rest, ready, attack }

class NeonPoseBlend {
  const NeonPoseBlend(this.pose, {this.from, this.mix = 1});
  final NeonFigurePose pose;
  final NeonFigurePose? from;
  final double mix;
}

NeonPoseBlend neonCapturePose(double progress, {required double impact}) {
  if (progress < .12) return const NeonPoseBlend(NeonFigurePose.ready);
  if (progress < impact) {
    return NeonPoseBlend(
      NeonFigurePose.attack,
      from: NeonFigurePose.ready,
      mix: _poseEase(((progress - .12) / (impact - .12)).clamp(0.0, 1.0)),
    );
  }
  if (progress < impact + .1) return const NeonPoseBlend(NeonFigurePose.attack);
  return NeonPoseBlend(
    NeonFigurePose.rest,
    from: NeonFigurePose.attack,
    mix: _poseEase(
      ((progress - impact - .1) / (1 - impact - .1)).clamp(0.0, 1.0),
    ),
  );
}

double _poseEase(double p) => p * p * p * (p * (6 * p - 15) + 10);

double _ease(double t) => Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));

/// Source images contain six illustrated units per faction. Measured source
/// bounds keep wide mounts and energy weapons intact without importing the
/// next unit. Native aspect fitting preserves every character's proportions.
class NeonFigureSprite extends StatefulWidget {
  const NeonFigureSprite({
    required this.piece,
    this.faceRight,
    this.theme = AnimatedArmyTheme.neon,
    this.pose = NeonFigurePose.rest,
    this.fromPose,
    this.poseBlend = 1,
    this.bodyHeight,
    super.key,
  });
  final Piece piece;
  final bool? faceRight;
  final AnimatedArmyTheme theme;
  final NeonFigurePose pose;
  final NeonFigurePose? fromPose;
  final double poseBlend;

  /// A shared head-to-feet size supplied by an encounter. Weapon margins do
  /// not determine a winner's or captured unit's physical scale.
  final double? bodyHeight;

  @override
  State<NeonFigureSprite> createState() => _NeonFigureSpriteState();
}

class _NeonFigureSpriteState extends State<NeonFigureSprite> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double _imageAspect = 3;
  final Map<String, ImageStream> _poseStreams = {};
  final Map<String, ImageStreamListener> _poseListeners = {};
  final Map<NeonFigurePose, ui.Image> _poseImages = {};

  String get _asset => widget.theme.castAsset(widget.piece.color);

  @override
  void initState() {
    super.initState();
    _imageAspect = widget.theme == AnimatedArmyTheme.neon ? 3 : 2;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
    _resolvePoses();
  }

  @override
  void didUpdateWidget(NeonFigureSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.piece.color != widget.piece.color ||
        oldWidget.theme != widget.theme) {
      _imageAspect = widget.theme == AnimatedArmyTheme.neon ? 3 : 2;
      _resolve();
    }
    if (oldWidget.piece.role != widget.piece.role) {
      for (final entry in _poseStreams.entries) {
        entry.value.removeListener(_poseListeners[entry.key]!);
      }
      _poseStreams.clear();
      _poseListeners.clear();
      for (final pose in [NeonFigurePose.ready, NeonFigurePose.attack]) {
        _poseImages.remove(pose)?.dispose();
      }
    }
    if (oldWidget.pose != widget.pose ||
        oldWidget.fromPose != widget.fromPose ||
        oldWidget.theme != widget.theme ||
        oldWidget.piece.role != widget.piece.role) {
      _resolvePoses();
    }
  }

  void _resolve() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _stream = AssetImage(
      _asset,
    ).resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener(
      (info, synchronousCall) {
        final aspect = info.image.width / info.image.height;
        final image = info.image.clone();
        info.dispose();
        if (!mounted) {
          image.dispose();
          return;
        }
        void assign() {
          _poseImages[NeonFigurePose.rest]?.dispose();
          _poseImages[NeonFigurePose.rest] = image;
          _imageAspect = aspect;
        }

        if (synchronousCall) {
          assign();
        } else {
          // A final rest decode can complete the three-pose painter even when
          // its aspect ratio matches the initial estimate exactly.
          setState(assign);
        }
      },
      onError: (Object error, StackTrace? trace) {
        // The image widget below supplies an unobtrusive loading fallback.
      },
    );
    _stream!.addListener(_listener!);
  }

  void _resolvePoses() {
    if (widget.theme != AnimatedArmyTheme.neon ||
        _poseStreams.isNotEmpty ||
        (widget.pose == NeonFigurePose.rest && widget.fromPose == null)) {
      return;
    }
    final readyPath = neonReadyAsset(widget.piece.role);
    for (final path in [readyPath, neonAttackAsset(widget.piece.role)]) {
      final stream = AssetImage(
        path,
      ).resolve(createLocalImageConfiguration(context));
      final listener = ImageStreamListener((info, synchronous) {
        final pose = path == readyPath
            ? NeonFigurePose.ready
            : NeonFigurePose.attack;
        final image = info.image.clone();
        info.dispose();
        if (!mounted) {
          image.dispose();
          return;
        }
        void assign() {
          _poseImages[pose]?.dispose();
          _poseImages[pose] = image;
        }

        if (synchronous) {
          assign();
        } else {
          setState(assign);
        }
      }, onError: (Object error, StackTrace? trace) {});
      _poseStreams[path] = stream;
      _poseListeners[path] = listener;
      stream.addListener(listener);
    }
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    for (final entry in _poseStreams.entries) {
      entry.value.removeListener(_poseListeners[entry.key]!);
    }
    for (final image in _poseImages.values) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _illustrationBounds(widget.piece, theme: widget.theme);
    final slotAspect = _imageAspect * bounds.width / bounds.height;
    final color = Color(
      widget.piece.color == Side.white
          ? widget.theme.whiteColorArgb
          : widget.theme.blackColorArgb,
    );
    return Semantics(
      label:
          '${widget.piece.color.name} ${widget.piece.role.name} illustration',
      child: LayoutBuilder(
        builder: (context, box) {
          final body = _figureSourceBodyHeight(widget.piece, widget.theme);
          final source = _figureSourceBounds(widget.piece, widget.theme);
          final slotWidth = widget.bodyHeight == null
              ? math.min(box.maxWidth, box.maxHeight * slotAspect)
              : source.width * widget.bodyHeight! / body;
          final imageHeight = widget.bodyHeight == null
              ? slotWidth / slotAspect
              : source.height * widget.bodyHeight! / body;
          final atlasWidth = slotWidth / bounds.width;
          final atlasHeight = imageHeight / bounds.height;
          final posed =
              widget.theme == AnimatedArmyTheme.neon &&
              _poseImages.length == 3 &&
              (widget.pose != NeonFigurePose.rest || widget.fromPose != null);
          return Stack(
            fit: StackFit.expand,
            clipBehavior: posed || widget.bodyHeight != null
                ? Clip.none
                : Clip.hardEdge,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -.1),
                    radius: .75,
                    colors: [
                      color.withValues(alpha: .16),
                      color.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              Transform.flip(
                key: ValueKey(
                  'neon-figure-mirror-${widget.piece.color.name}-${widget.piece.role.name}',
                ),
                // Both source sheets face right. Color does not determine a
                // source pose's native direction; every Black pose is mirrored.
                flipX: !(widget.faceRight ?? widget.piece.color == Side.white),
                child: posed
                    ? _NeonPoseArtwork(
                        piece: widget.piece,
                        pose: widget.pose,
                        from: widget.fromPose,
                        mix: widget.poseBlend,
                        images: _poseImages,
                        bodyHeight: widget.bodyHeight,
                      )
                    : Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          width: slotWidth,
                          height: imageHeight,
                          child: ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.topLeft,
                              minWidth: atlasWidth,
                              maxWidth: atlasWidth,
                              minHeight: atlasHeight,
                              maxHeight: atlasHeight,
                              child: Transform.translate(
                                offset: Offset(
                                  -bounds.left * atlasWidth,
                                  -bounds.top * atlasHeight,
                                ),
                                child: ClipPath(
                                  clipper:
                                      widget.theme == AnimatedArmyTheme.neon
                                      ? null
                                      : _CombinedCastClipper(
                                          widget.theme,
                                          widget.piece,
                                        ),
                                  child: Image.asset(
                                    _asset,
                                    width: atlasWidth,
                                    height: atlasHeight,
                                    filterQuality: FilterQuality.high,
                                    fit: BoxFit.fill,
                                    errorBuilder: (context, error, trace) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NeonPoseFrame {
  const _NeonPoseFrame(
    this.asset,
    this.bounds,
    this.bodyHeight,
    this.anchorX, {
    this.atlasSize = const Size(1774, 887),
  });
  final String asset;
  final Rect bounds;
  final double bodyHeight;
  final double anchorX;
  final Size atlasSize;
}

_NeonPoseFrame _neonPoseFrame(Piece piece, NeonFigurePose pose) {
  final index = _castColumn(piece.role);
  final white = piece.color == Side.white;
  if (pose == NeonFigurePose.rest) {
    final atlas = Size(white ? 2172 : 2167, white ? 724 : 726);
    final normalized = _illustrationBounds(piece);
    final bounds = Rect.fromLTRB(
      normalized.left * atlas.width,
      normalized.top * atlas.height,
      normalized.right * atlas.width,
      normalized.bottom * atlas.height,
    );
    final bodies = white
        ? const [438.0, 394.0, 456.0, 417.0, 508.0, 319.0]
        : const [438.0, 386.0, 430.0, 435.0, 504.0, 367.0];
    return _NeonPoseFrame(
      AnimatedArmyTheme.neon.castAsset(piece.color),
      bounds,
      bodies[index],
      bounds.center.dx,
      atlasSize: atlas,
    );
  }
  final ready = pose == NeonFigurePose.ready;
  final bounds = ready
      ? (white
            ? const [
                Rect.fromLTRB(0, 51, 299, 484),
                Rect.fromLTRB(302, 123, 582, 483),
                Rect.fromLTRB(579, 47, 969, 479),
                Rect.fromLTRB(901, 87, 1231, 483),
                Rect.fromLTRB(1195, 40, 1555, 479),
                Rect.fromLTRB(1531, 132, 1774, 488),
              ]
            : const [
                Rect.fromLTRB(0, 484, 298, 887),
                Rect.fromLTRB(301, 537, 584, 884),
                Rect.fromLTRB(582, 477, 975, 879),
                Rect.fromLTRB(905, 504, 1237, 884),
                Rect.fromLTRB(1195, 480, 1578, 883),
                Rect.fromLTRB(1530, 517, 1774, 887),
              ])
      : (white
            ? const [
                Rect.fromLTRB(0, 120, 359, 474),
                Rect.fromLTRB(287, 185, 654, 477),
                Rect.fromLTRB(595, 51, 961, 478),
                Rect.fromLTRB(901, 138, 1239, 475),
                Rect.fromLTRB(1189, 65, 1542, 472),
                Rect.fromLTRB(1492, 211, 1774, 475),
              ]
            : const [
                Rect.fromLTRB(0, 520, 371, 871),
                Rect.fromLTRB(295, 568, 672, 877),
                Rect.fromLTRB(601, 466, 967, 871),
                Rect.fromLTRB(907, 533, 1250, 874),
                Rect.fromLTRB(1192, 474, 1522, 870),
                Rect.fromLTRB(1508, 600, 1774, 875),
              ]);
  final bodies = ready
      ? (white
            ? const [316.0, 293.0, 356.0, 319.0, 355.0, 250.0]
            : const [321.0, 297.0, 321.0, 311.0, 365.0, 264.0])
      : (white
            ? const [310.0, 278.0, 339.0, 306.0, 396.0, 233.0]
            : const [314.0, 281.0, 330.0, 290.0, 386.0, 211.0]);
  final anchors = ready
      ? const [157.0, 474.0, 735.0, 1080.0, 1370.0, 1660.0]
      : const [155.0, 460.0, 745.0, 1090.0, 1355.0, 1640.0];
  return _NeonPoseFrame(
    ready ? neonReadyAsset(piece.role) : neonAttackAsset(piece.role),
    bounds[index],
    bodies[index],
    anchors[index],
  );
}

/// Every pose uses the same body height and foot anchor. A raised blade may
/// extend beyond the actor's layout slot without shrinking its wearer.
class _NeonPoseArtwork extends StatelessWidget {
  const _NeonPoseArtwork({
    required this.piece,
    required this.pose,
    required this.from,
    required this.mix,
    required this.images,
    this.bodyHeight,
  });
  final Piece piece;
  final NeonFigurePose pose;
  final NeonFigurePose? from;
  final double mix;
  final Map<NeonFigurePose, ui.Image> images;
  final double? bodyHeight;
  @override
  Widget build(BuildContext context) => CustomPaint(
    key: ValueKey(
      'neon-pose-${piece.color.name}-${piece.role.name}-${pose.name}',
    ),
    painter: _NeonPosePainter(
      piece: piece,
      pose: pose,
      from: from,
      mix: mix.clamp(0.0, 1.0),
      images: images,
      bodyHeight: bodyHeight,
    ),
  );
}

class _NeonPosePainter extends CustomPainter {
  _NeonPosePainter({
    required this.piece,
    required this.pose,
    required this.from,
    required this.mix,
    required Map<NeonFigurePose, ui.Image> images,
    this.bodyHeight,
  }) : images = Map.of(images);
  final Piece piece;
  final NeonFigurePose pose;
  final NeonFigurePose? from;
  final double mix;
  final Map<NeonFigurePose, ui.Image> images;
  final double? bodyHeight;
  @override
  void paint(Canvas canvas, Size size) {
    final frames = NeonFigurePose.values.map(
      (pose) => _neonPoseFrame(piece, pose),
    );
    final rest = _neonPoseFrame(piece, NeonFigurePose.rest);
    final largestRatio = frames
        .map((frame) => frame.bounds.height / frame.bodyHeight)
        .reduce(math.max);
    final fittedBodyHeight =
        bodyHeight ??
        math.min(
          size.height / largestRatio,
          size.width * rest.bodyHeight / rest.bounds.width,
        );
    void draw(NeonFigurePose pose, double opacity) {
      final image = images[pose];
      if (image == null || opacity == 0) return;
      final source = _neonPoseFrame(piece, pose);
      final scale = fittedBodyHeight / source.bodyHeight;
      canvas.save();
      canvas.translate(
        size.width / 2 - source.anchorX * scale,
        size.height - source.bounds.bottom * scale,
      );
      canvas.scale(scale);
      canvas.clipRect(source.bounds);
      if (pose != NeonFigurePose.rest) {
        canvas.clipPath(
          _NeonPoseClipper(piece, pose, source).getClip(source.atlasSize),
        );
      }
      canvas.drawImage(
        image,
        Offset.zero,
        Paint()
          ..color = Colors.white.withValues(alpha: opacity)
          ..filterQuality = FilterQuality.high,
      );
      canvas.restore();
    }

    if (from != null && from != pose && mix < 1) draw(from!, 1 - mix);
    draw(pose, from == null || from == pose ? 1 : mix);
  }

  @override
  bool shouldRepaint(_NeonPosePainter old) =>
      old.piece != piece ||
      old.pose != pose ||
      old.from != from ||
      old.mix != mix ||
      old.bodyHeight != bodyHeight ||
      NeonFigurePose.values.any((pose) => old.images[pose] != images[pose]);
}

class _NeonPoseClipper extends CustomClipper<Path> {
  const _NeonPoseClipper(this.piece, this.pose, this.frame);
  final Piece piece;
  final NeonFigurePose pose;
  final _NeonPoseFrame frame;
  @override
  Path getClip(Size size) {
    final b = frame.bounds;
    final white = piece.color == Side.white;
    final attack = pose == NeonFigurePose.attack;
    final points = switch ((attack, white, piece.role)) {
      (true, true, Role.king) => const [
        Offset(0, 120),
        Offset(359, 120),
        Offset(359, 175),
        Offset(302, 218),
        Offset(282, 240),
        Offset(282, 410),
        Offset(298, 448),
        Offset(289, 474),
        Offset(0, 474),
      ],
      (true, false, Role.king) => const [
        Offset(0, 520),
        Offset(371, 520),
        Offset(371, 556),
        Offset(303, 594),
        Offset(282, 620),
        Offset(282, 790),
        Offset(299, 849),
        Offset(295, 871),
        Offset(0, 871),
      ],
      (true, true, Role.queen) => const [
        Offset(412, 185),
        Offset(471, 185),
        Offset(495, 226),
        Offset(624, 190),
        Offset(648, 207),
        Offset(630, 226),
        Offset(592, 251),
        Offset(592, 477),
        Offset(306, 477),
        Offset(287, 310),
        Offset(287, 239),
        Offset(383, 218),
      ],
      (true, false, Role.queen) => const [
        Offset(418, 568),
        Offset(492, 568),
        Offset(499, 624),
        Offset(642, 592),
        Offset(662, 604),
        Offset(662, 615),
        Offset(599, 643),
        Offset(599, 877),
        Offset(312, 877),
        Offset(295, 730),
        Offset(295, 633),
        Offset(392, 611),
      ],
      (true, true, Role.bishop) => const [
        Offset(642, 51),
        Offset(739, 51),
        Offset(741, 116),
        Offset(879, 110),
        Offset(927, 156),
        Offset(920, 184),
        Offset(889, 204),
        Offset(888, 323),
        Offset(910, 335),
        Offset(917, 371),
        Offset(945, 381),
        Offset(926, 399),
        Offset(908, 405),
        Offset(869, 414),
        Offset(857, 478),
        Offset(765, 478),
        Offset(760, 459),
        Offset(674, 459),
        Offset(674, 478),
        Offset(595, 478),
        Offset(595, 315),
        Offset(647, 252),
        Offset(657, 198),
        Offset(636, 155),
      ],
      (true, false, Role.bishop) => const [
        Offset(651, 466),
        Offset(751, 466),
        Offset(759, 531),
        Offset(882, 509),
        Offset(927, 545),
        Offset(927, 587),
        Offset(891, 605),
        Offset(891, 724),
        Offset(957, 753),
        Offset(948, 774),
        Offset(920, 797),
        Offset(912, 802),
        Offset(869, 811),
        Offset(856, 871),
        Offset(601, 871),
        Offset(601, 723),
        Offset(652, 664),
        Offset(677, 611),
        Offset(650, 561),
      ],
      (false, true, Role.bishop) => const [
        Offset(600, 47),
        Offset(704, 47),
        Offset(701, 126),
        Offset(795, 110),
        Offset(866, 127),
        Offset(876, 194),
        Offset(893, 245),
        Offset(893, 326),
        Offset(909, 338),
        Offset(916, 373),
        Offset(942, 385),
        Offset(913, 408),
        Offset(871, 417),
        Offset(859, 479),
        Offset(716, 479),
        Offset(716, 469),
        Offset(623, 469),
        Offset(623, 479),
        Offset(579, 479),
        Offset(579, 172),
        Offset(601, 126),
      ],
      (false, false, Role.bishop) => const [
        Offset(623, 477),
        Offset(722, 477),
        Offset(721, 515),
        Offset(801, 515),
        Offset(871, 540),
        Offset(893, 645),
        Offset(893, 728),
        Offset(923, 740),
        Offset(930, 770),
        Offset(951, 781),
        Offset(916, 805),
        Offset(870, 816),
        Offset(859, 879),
        Offset(582, 879),
        Offset(582, 605),
        Offset(623, 537),
      ],
      (true, true, Role.knight) => const [
        Offset(933, 138),
        Offset(1239, 138),
        Offset(1239, 176),
        Offset(1173, 211),
        Offset(1173, 305),
        Offset(1190, 367),
        Offset(1190, 475),
        Offset(928, 475),
        Offset(928, 408),
        Offset(978, 383),
        Offset(945, 335),
        Offset(901, 297),
        Offset(901, 229),
        Offset(932, 204),
      ],
      (true, false, Role.knight) => const [
        Offset(956, 533),
        Offset(1250, 533),
        Offset(1250, 568),
        Offset(1178, 607),
        Offset(1178, 718),
        Offset(1201, 777),
        Offset(1201, 874),
        Offset(930, 874),
        Offset(930, 810),
        Offset(978, 783),
        Offset(947, 734),
        Offset(907, 686),
        Offset(907, 620),
        Offset(956, 589),
      ],
      (false, true, Role.knight) => const [
        Offset(910, 87),
        Offset(1200, 87),
        Offset(1200, 169),
        Offset(1192, 207),
        Offset(1192, 364),
        Offset(1231, 433),
        Offset(1231, 483),
        Offset(929, 483),
        Offset(929, 419),
        Offset(976, 389),
        Offset(946, 341),
        Offset(901, 293),
        Offset(901, 154),
      ],
      (false, false, Role.knight) => const [
        Offset(913, 504),
        Offset(1203, 504),
        Offset(1203, 577),
        Offset(1197, 617),
        Offset(1197, 770),
        Offset(1237, 833),
        Offset(1237, 884),
        Offset(929, 884),
        Offset(929, 821),
        Offset(979, 787),
        Offset(945, 742),
        Offset(905, 694),
        Offset(905, 585),
      ],
      (true, true, Role.rook) => const [
        Offset(1240, 65),
        Offset(1490, 65),
        Offset(1490, 248),
        Offset(1542, 265),
        Offset(1542, 312),
        Offset(1490, 335),
        Offset(1490, 472),
        Offset(1189, 472),
        Offset(1189, 287),
        Offset(1239, 251),
        Offset(1239, 177),
        Offset(1240, 176),
      ],
      (true, false, Role.rook) => const [
        Offset(1251, 474),
        Offset(1490, 474),
        Offset(1490, 642),
        Offset(1522, 657),
        Offset(1522, 710),
        Offset(1493, 722),
        Offset(1493, 870),
        Offset(1192, 870),
        Offset(1192, 692),
        Offset(1250, 649),
        Offset(1250, 570),
        Offset(1251, 568),
      ],
      (false, true, Role.rook) => const [
        Offset(1195, 40),
        Offset(1518, 40),
        Offset(1518, 249),
        Offset(1555, 267),
        Offset(1555, 345),
        Offset(1525, 369),
        Offset(1525, 479),
        Offset(1252, 479),
        Offset(1215, 416),
        Offset(1215, 350),
        Offset(1195, 210),
        Offset(1205, 169),
        Offset(1205, 87),
        Offset(1195, 87),
      ],
      (false, false, Role.rook) => const [
        Offset(1195, 480),
        Offset(1499, 480),
        Offset(1499, 646),
        Offset(1578, 664),
        Offset(1578, 735),
        Offset(1526, 750),
        Offset(1526, 883),
        Offset(1261, 883),
        Offset(1227, 825),
        Offset(1227, 770),
        Offset(1220, 750),
        Offset(1220, 617),
        Offset(1210, 577),
        Offset(1210, 504),
        Offset(1195, 504),
      ],
      (true, true, Role.pawn) => const [
        Offset(1550, 211),
        Offset(1774, 211),
        Offset(1774, 475),
        Offset(1492, 475),
        Offset(1492, 401),
        Offset(1550, 347),
      ],
      (true, false, Role.pawn) => const [
        Offset(1645, 600),
        Offset(1774, 600),
        Offset(1774, 875),
        Offset(1508, 875),
        Offset(1508, 805),
        Offset(1561, 750),
        Offset(1561, 674),
        Offset(1606, 635),
      ],
      (false, true, Role.pawn) => const [
        Offset(1531, 132),
        Offset(1774, 132),
        Offset(1774, 488),
        Offset(1531, 488),
        Offset(1531, 395),
        Offset(1570, 350),
        Offset(1570, 251),
        Offset(1531, 224),
      ],
      (false, false, Role.pawn) => const [
        Offset(1530, 517),
        Offset(1774, 517),
        Offset(1774, 887),
        Offset(1530, 887),
        Offset(1530, 804),
        Offset(1580, 754),
        Offset(1580, 653),
        Offset(1530, 614),
      ],
      _ => [b.topLeft, b.topRight, b.bottomRight, b.bottomLeft],
    };
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = p.dx / frame.atlasSize.width * size.width;
      final y = p.dy / frame.atlasSize.height * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  @override
  bool shouldReclip(_NeonPoseClipper oldClipper) =>
      oldClipper.piece != piece || oldClipper.pose != pose;
}

Rect _figureSourceBounds(Piece piece, AnimatedArmyTheme theme) {
  if (theme != AnimatedArmyTheme.neon) return _combinedCastBounds(theme, piece);
  return _neonPoseFrame(piece, NeonFigurePose.rest).bounds;
}

double _figureSourceBodyHeight(Piece piece, AnimatedArmyTheme theme) {
  if (theme == AnimatedArmyTheme.neon) {
    return _neonPoseFrame(piece, NeonFigurePose.rest).bodyHeight;
  }
  final heights = switch (theme) {
    AnimatedArmyTheme.manga => const [
      400.0,
      351.0,
      391.0,
      391.0,
      374.0,
      325.0,
      395.0,
      350.0,
      383.0,
      393.0,
      365.0,
      326.0,
    ],
    AnimatedArmyTheme.epic => const [
      398.0,
      372.0,
      404.0,
      367.0,
      340.0,
      329.0,
      391.0,
      376.0,
      410.0,
      373.0,
      332.0,
      332.0,
    ],
    AnimatedArmyTheme.olympian => const [
      392.0,
      393.0,
      422.0,
      376.0,
      374.0,
      379.0,
      387.0,
      391.0,
      422.0,
      376.0,
      375.0,
      380.0,
    ],
    AnimatedArmyTheme.neon => throw StateError('Neon has pose body metrics'),
  };
  return heights[_castColumn(piece.role) + (piece.color == Side.white ? 0 : 6)];
}

/// One physical scale for all units in the available actor lane. Live play uses
/// the entire cast so selecting or committing a different role cannot resize
/// the scene. Bookends may supply just the two leaders being shown. Board icons
/// can fit only the rest pose; live and film keep every pose in their budget.
double animatedFigureBodyHeight({
  required AnimatedArmyTheme theme,
  required Size space,
  Iterable<Piece>? pieces,
  Iterable<NeonFigurePose> poses = NeonFigurePose.values,
}) {
  var fitted = math.max(0.0, space.height);
  final cast =
      pieces ??
      [
        for (final side in Side.values)
          for (final role in Role.values) Piece(color: side, role: role),
      ];
  for (final piece in cast) {
    final body = _figureSourceBodyHeight(piece, theme);
    final bounds = _figureSourceBounds(piece, theme);
    var heightRatio = bounds.height / body;
    if (theme == AnimatedArmyTheme.neon) {
      for (final pose in poses) {
        final frame = _neonPoseFrame(piece, pose);
        heightRatio = math.max(
          heightRatio,
          frame.bounds.height / frame.bodyHeight,
        );
      }
    }
    fitted = math.min(
      fitted,
      math.min(space.height / heightRatio, space.width * body / bounds.width),
    );
  }
  return math.max(0.0, fitted);
}

Rect _illustrationBounds(
  Piece piece, {
  AnimatedArmyTheme theme = AnimatedArmyTheme.neon,
}) {
  if (theme != AnimatedArmyTheme.neon) {
    final rect = _combinedCastBounds(theme, piece);
    return Rect.fromLTRB(
      rect.left / 1774,
      rect.top / 887,
      rect.right / 1774,
      rect.bottom / 887,
    );
  }
  // Artwork has deliberate wide silhouettes rather than uniform chess-icon
  // cells. Values include a soft light margin around the opaque alpha bounds.
  // The bishop/knight boundary follows the narrow natural gutter, preserving
  // the elephant's trunk without showing it in the knight's close-up.
  final white = piece.color == Side.white;
  final rect = white
      ? switch (piece.role) {
          Role.king => const Rect.fromLTRB(10, 77, 354, 659),
          Role.queen => const Rect.fromLTRB(381, 221, 680, 659),
          Role.bishop => const Rect.fromLTRB(726, 98, 1106, 653),
          Role.knight => const Rect.fromLTRB(1106, 147, 1448, 656),
          Role.rook => const Rect.fromLTRB(1485, 70, 1878, 641),
          Role.pawn => const Rect.fromLTRB(1887, 217, 2144, 661),
        }
      : switch (piece.role) {
          Role.king => const Rect.fromLTRB(0, 104, 337, 645),
          Role.queen => const Rect.fromLTRB(383, 211, 686, 651),
          Role.bishop => const Rect.fromLTRB(738, 102, 1116, 635),
          Role.knight => const Rect.fromLTRB(1116, 122, 1425, 643),
          Role.rook => const Rect.fromLTRB(1476, 106, 1874, 641),
          Role.pawn => const Rect.fromLTRB(1910, 155, 2167, 653),
        };
  final width = white ? 2172.0 : 2167.0;
  final height = white ? 724.0 : 726.0;
  return Rect.fromLTRB(
    rect.left / width,
    rect.top / height,
    rect.right / width,
    rect.bottom / height,
  );
}

int _castColumn(Role role) => switch (role) {
  Role.king => 0,
  Role.queen => 1,
  Role.bishop => 2,
  Role.knight => 3,
  Role.rook => 4,
  Role.pawn => 5,
};

Rect _combinedCastBounds(AnimatedArmyTheme theme, Piece piece) {
  // Measured opaque silhouettes in the original 1774×887 artwork. The small
  // row margins exclude the next row's raised staff glow from White portraits.
  final bounds = switch (theme) {
    AnimatedArmyTheme.manga => const [
      Rect.fromLTRB(10, 41, 333, 441),
      Rect.fromLTRB(277, 42, 534, 433),
      Rect.fromLTRB(527, 7, 910, 440),
      Rect.fromLTRB(867, 41, 1242, 438),
      Rect.fromLTRB(1177, 64, 1573, 440),
      Rect.fromLTRB(1547, 102, 1774, 440),
      Rect.fromLTRB(9, 464, 352, 872),
      Rect.fromLTRB(278, 460, 553, 867),
      Rect.fromLTRB(533, 442, 903, 869),
      Rect.fromLTRB(876, 468, 1261, 866),
      Rect.fromLTRB(1167, 496, 1578, 871),
      Rect.fromLTRB(1552, 521, 1774, 869),
    ],
    AnimatedArmyTheme.epic => const [
      Rect.fromLTRB(8, 32, 276, 436),
      Rect.fromLTRB(262, 35, 529, 441),
      Rect.fromLTRB(502, 6, 885, 435),
      Rect.fromLTRB(871, 41, 1240, 436),
      Rect.fromLTRB(1185, 69, 1535, 442),
      Rect.fromLTRB(1546, 40, 1764, 436),
      Rect.fromLTRB(9, 464, 280, 870),
      Rect.fromLTRB(267, 467, 529, 875),
      Rect.fromLTRB(508, 442, 881, 873),
      Rect.fromLTRB(872, 478, 1240, 871),
      Rect.fromLTRB(1187, 505, 1535, 876),
      Rect.fromLTRB(1552, 471, 1764, 869),
    ],
    AnimatedArmyTheme.olympian => const [
      Rect.fromLTRB(11, 0, 312, 430),
      Rect.fromLTRB(303, 26, 557, 429),
      Rect.fromLTRB(565, 8, 929, 432),
      Rect.fromLTRB(891, 50, 1244, 428),
      Rect.fromLTRB(1199, 52, 1552, 437),
      Rect.fromLTRB(1547, 16, 1769, 429),
      Rect.fromLTRB(10, 430, 314, 871),
      Rect.fromLTRB(305, 465, 558, 871),
      Rect.fromLTRB(564, 445, 930, 874),
      Rect.fromLTRB(889, 491, 1245, 869),
      Rect.fromLTRB(1197, 490, 1552, 876),
      Rect.fromLTRB(1545, 455, 1769, 870),
    ],
    AnimatedArmyTheme.neon => throw StateError('Neon has separate cast sheets'),
  };
  return bounds[_castColumn(piece.role) + (piece.color == Side.white ? 0 : 6)];
}

/// Renderer-only cuts follow the transparent gutters rather than clipping a
/// raised blade or elephant trunk to a column. Native images remain intact.
class _CombinedCastClipper extends CustomClipper<Path> {
  const _CombinedCastClipper(this.theme, this.piece);
  final AnimatedArmyTheme theme;
  final Piece piece;
  static const _heights = [
    0.0,
    100.0,
    160.0,
    220.0,
    280.0,
    335.0,
    390.0,
    443.5,
  ];
  static const _gutters = {
    AnimatedArmyTheme.manga: [
      [
        [345.0, 345.0, 290.0, 277.0, 279.0, 275.0, 280.0, 290.0],
        [550.0, 555.0, 550.0, 535.0, 535.0, 528.0, 529.0, 530.0],
        [890.0, 890.0, 875.0, 865.0, 905.0, 908.0, 885.0, 875.0],
        [1260.0, 1260.0, 1190.0, 1174.0, 1164.0, 1163.0, 1175.0, 1177.0],
        [1590.0, 1590.0, 1590.0, 1590.0, 1560.0, 1550.0, 1547.0, 1540.0],
      ],
      [
        [354.0, 354.0, 299.0, 291.0, 287.0, 279.0, 291.0, 288.0],
        [548.0, 555.0, 552.0, 547.0, 548.0, 535.0, 535.0, 541.0],
        [887.0, 887.0, 885.0, 875.0, 901.0, 899.0, 882.0, 880.0],
        [1270.0, 1270.0, 1190.0, 1180.0, 1164.0, 1174.0, 1180.0, 1177.0],
        [1590.0, 1590.0, 1590.0, 1590.0, 1572.0, 1557.0, 1549.0, 1540.0],
      ],
    ],
    AnimatedArmyTheme.epic: [
      [
        [280.0, 280.0, 274.0, 264.0, 264.0, 275.0, 278.0, 278.0],
        [540.0, 540.0, 515.0, 510.0, 500.0, 500.0, 502.0, 508.0],
        [873.0, 873.0, 863.0, 863.0, 890.0, 879.0, 866.0, 865.0],
        [1245.0, 1245.0, 1202.0, 1195.0, 1181.0, 1191.0, 1197.0, 1196.0],
        [1550.0, 1550.0, 1545.0, 1545.0, 1543.0, 1540.0, 1544.0, 1542.0],
      ],
      [
        [287.0, 287.0, 282.0, 279.0, 268.0, 275.0, 279.0, 279.0],
        [540.0, 540.0, 516.0, 510.0, 510.0, 509.0, 505.0, 503.0],
        [868.0, 868.0, 863.0, 865.0, 879.0, 875.0, 867.0, 864.0],
        [1240.0, 1240.0, 1200.0, 1199.0, 1187.0, 1182.0, 1192.0, 1197.0],
        [1553.0, 1553.0, 1553.0, 1553.0, 1550.0, 1542.0, 1540.0, 1540.0],
      ],
    ],
    AnimatedArmyTheme.olympian: [
      [
        [321.0, 310.0, 307.0, 299.0, 300.0, 305.0, 310.0, 311.0],
        [565.0, 565.0, 563.0, 562.0, 563.0, 563.0, 564.0, 566.0],
        [903.0, 903.0, 889.0, 884.0, 927.0, 910.0, 877.0, 877.0],
        [1252.0, 1252.0, 1205.0, 1200.0, 1200.0, 1197.0, 1195.0, 1199.0],
        [1550.0, 1550.0, 1550.0, 1550.0, 1548.0, 1538.0, 1547.0, 1547.0],
      ],
      [
        [331.0, 320.0, 310.0, 305.0, 301.0, 308.0, 312.0, 310.0],
        [568.0, 566.0, 563.0, 562.0, 563.0, 563.0, 566.0, 565.0],
        [903.0, 903.0, 888.0, 886.0, 928.0, 910.0, 881.0, 881.0],
        [1253.0, 1253.0, 1202.0, 1202.0, 1200.0, 1198.0, 1198.0, 1198.0],
        [1550.0, 1550.0, 1550.0, 1550.0, 1545.0, 1545.0, 1544.0, 1544.0],
      ],
    ],
  };

  double _boundary(int index, double y) {
    final edge = _silhouetteEdge(index == _castColumn(piece.role));
    if (edge != null) {
      if (y <= edge.first.dy) return edge.first.dx;
      for (var i = 1; i < edge.length; i++) {
        if (y <= edge[i].dy) {
          final p = (y - edge[i - 1].dy) / (edge[i].dy - edge[i - 1].dy);
          return edge[i - 1].dx + (edge[i].dx - edge[i - 1].dx) * p;
        }
      }
      return edge.last.dx;
    }
    if (index == 0) return 0;
    if (index == 6) return 1774;
    final values =
        _gutters[theme]![piece.color == Side.white ? 0 : 1][index - 1];
    if (y <= _heights.first) return values.first;
    for (var i = 1; i < _heights.length; i++) {
      if (y <= _heights[i]) {
        final p = (y - _heights[i - 1]) / (_heights[i] - _heights[i - 1]);
        return values[i - 1] + (values[i] - values[i - 1]) * p;
      }
    }
    return values.last;
  }

  List<Offset>? _silhouetteEdge(bool left) => switch ((
    theme,
    piece.color,
    piece.role,
    left,
  )) {
    // Individual outlines exclude detached neighbor fabric and hooves while
    // preserving the actor's own raised blade, feet, staff, trunk and shield.
    (AnimatedArmyTheme.manga, Side.white, Role.pawn, true) => const [
      Offset(1595, 0),
      Offset(1595, 150),
      Offset(1577, 180),
      Offset(1577, 250),
      Offset(1580, 270),
      Offset(1580, 300),
      Offset(1600, 335),
      Offset(1570, 390),
      Offset(1537, 443.5),
    ],
    (AnimatedArmyTheme.manga, Side.white, Role.bishop, false) => const [
      Offset(890, 0),
      Offset(890, 100),
      Offset(875, 160),
      Offset(865, 220),
      Offset(905, 280),
      Offset(906, 315),
      Offset(895, 335),
      Offset(869, 350),
      Offset(855, 390),
      Offset(844, 443.5),
    ],
    (AnimatedArmyTheme.epic, _, Role.king, false) => const [
      Offset(280, 0),
      Offset(280, 160),
      Offset(271, 220),
      Offset(258, 250),
      Offset(255, 300),
      Offset(260, 350),
      Offset(265, 400),
      Offset(276, 443.5),
    ],
    (AnimatedArmyTheme.epic, Side.white, Role.queen, true) => const [
      Offset(280, 0),
      Offset(280, 160),
      Offset(279, 220),
      Offset(264, 280),
      Offset(275, 335),
      Offset(278, 390),
      Offset(278, 443.5),
    ],
    (AnimatedArmyTheme.epic, Side.black, Role.queen, false) => const [
      Offset(540, 0),
      Offset(540, 100),
      Offset(516, 160),
      Offset(510, 220),
      Offset(501, 280),
      Offset(501, 335),
      Offset(503, 390),
      Offset(503, 443.5),
    ],
    (AnimatedArmyTheme.olympian, Side.black, Role.king, false) => const [
      Offset(331, 0),
      Offset(320, 100),
      Offset(310, 160),
      Offset(305, 220),
      Offset(299, 300),
      Offset(280, 350),
      Offset(280, 443.5),
    ],
    (AnimatedArmyTheme.olympian, Side.white, Role.king, false) => const [
      Offset(321, 0),
      Offset(310, 100),
      Offset(307, 160),
      Offset(299, 220),
      Offset(299, 300),
      Offset(299, 443.5),
    ],
    (AnimatedArmyTheme.olympian, _, Role.bishop, false) => const [
      Offset(903, 0),
      Offset(903, 100),
      Offset(889, 160),
      Offset(884, 220),
      Offset(927, 280),
      Offset(916, 300),
      Offset(892, 315),
      Offset(875, 335),
      Offset(854, 350),
      Offset(844, 390),
      Offset(830, 443.5),
    ],
    _ => null,
  };

  @override
  Path getClip(Size size) {
    final rect = _combinedCastBounds(theme, piece);
    final top = piece.color == Side.white ? 0.0 : 443.5;
    final samples = <double>{
      ..._heights,
      ...?_silhouetteEdge(true)?.map((point) => point.dy),
      ...?_silhouetteEdge(false)?.map((point) => point.dy),
    }.toList()..sort();
    final ys = [
      rect.top - top,
      ...samples.where((y) => y + top > rect.top && y + top < rect.bottom),
      rect.bottom - top,
    ];
    final column = _castColumn(piece.role);
    final path = Path();
    for (var i = 0; i < ys.length; i++) {
      final x = _boundary(column, ys[i]) / 1774 * size.width;
      final y = (ys[i] + top) / 887 * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    for (final y in ys.reversed) {
      path.lineTo(
        _boundary(column + 1, y) / 1774 * size.width,
        (y + top) / 887 * size.height,
      );
    }
    return path..close();
  }

  @override
  bool shouldReclip(_CombinedCastClipper old) =>
      old.theme != theme || old.piece != piece;
}

class _AtmospherePainter extends CustomPainter {
  const _AtmospherePainter({
    required this.progress,
    required this.accent,
    required this.moving,
    required this.theme,
  });
  final double progress;
  final Color accent;
  final bool moving;
  final AnimatedArmyTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    // Two large translucent foreground banks move at different speeds from
    // the city camera; this gives the shot depth rather than a flat zoom.
    final haze = Paint()
      ..shader =
          RadialGradient(
            colors: [
              accent.withValues(alpha: .13),
              accent.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromLTWH(
              -size.width * .25,
              size.height * .28,
              size.width,
              size.height * .8,
            ),
          );
    canvas.save();
    canvas.translate(moving ? progress * size.width * .08 : 0, 0);
    canvas.drawOval(
      Rect.fromLTWH(
        -size.width * .25,
        size.height * .28,
        size.width,
        size.height * .8,
      ),
      haze,
    );
    canvas.restore();
    final fleck = Paint()..color = accent.withValues(alpha: .48);
    for (var i = 0; i < 20; i++) {
      final x = ((i * .173 + (moving ? progress * .055 : 0)) % 1) * size.width;
      final y =
          ((i * .227 + (moving ? -progress * .045 : 0)) % 1) *
          size.height *
          .79;
      final point = Offset(x, y);
      switch (theme) {
        case AnimatedArmyTheme.manga:
          canvas.drawLine(
            point,
            point + const Offset(4, -2),
            fleck..strokeWidth = 1,
          );
        case AnimatedArmyTheme.epic:
          canvas.drawOval(
            Rect.fromCenter(center: point, width: 2, height: 4),
            fleck,
          );
        case AnimatedArmyTheme.olympian:
          canvas.drawOval(
            Rect.fromCenter(center: point, width: 4, height: 1.4),
            fleck,
          );
        case AnimatedArmyTheme.neon:
          canvas.drawCircle(point, i.isEven ? .8 : 1.2, fleck);
      }
    }
    final edge = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Color(theme.baseColorArgb).withValues(alpha: .7),
        ],
        stops: const [.4, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, edge);
  }

  @override
  bool shouldRepaint(_AtmospherePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.moving != moving ||
      oldDelegate.theme != theme;
}

/// The attack beam belongs only to an actual capture. Its endpoint is reached
/// at the same .56 landing phase as the lower board and encounter stamps.
class _CaptureStrikePainter extends CustomPainter {
  const _CaptureStrikePainter({
    required this.from,
    required this.to,
    required this.progress,
    required this.accent,
    required this.reduced,
    required this.theme,
    required this.role,
  });
  final Offset from;
  final Offset to;
  final double progress;
  final Color accent;
  final bool reduced;
  final AnimatedArmyTheme theme;
  final Role role;

  @override
  void paint(Canvas canvas, Size size) {
    if (theme != AnimatedArmyTheme.neon) {
      paintAnimatedArmyAttack(
        canvas,
        size,
        theme: theme,
        from: from,
        to: to,
        progress: progress,
        accent: accent,
        role: role,
        reducedMotion: reduced,
        landingProgress: .56,
      );
      return;
    }
    final unit = math.max(3.0, math.min(34.0, size.height * .1));
    if (reduced) {
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = accent.withValues(alpha: .25)
          ..strokeWidth = 1.5,
      );
      if (progress >= .56) {
        canvas.drawCircle(
          to,
          unit * .65,
          Paint()
            ..color = accent.withValues(alpha: .55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      return;
    }
    if (progress < .2 || progress > .91) return;
    final flight = _ease(((progress - .24) / .32).clamp(0.0, 1.0));
    final fade = (1 - ((progress - .56) / .25).clamp(0.0, 1.0));
    final end = Offset.lerp(from, to, flight)!;
    final charge = (.3 + flight * .7) * fade;
    final rune = Paint()
      ..color = accent.withValues(alpha: charge * .9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(from, unit * .68, rune);
    canvas.drawCircle(from, unit * .9, rune..strokeWidth = .8);
    final hexagon = Path();
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + progress * 2;
      final point = from + Offset(math.cos(a), math.sin(a)) * unit * .78;
      if (i == 0) {
        hexagon.moveTo(point.dx, point.dy);
      } else {
        hexagon.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(hexagon..close(), rune);
    if (flight > 0 && fade > 0) {
      for (final width in [13.0, 6.0, 2.0]) {
        canvas.drawLine(
          from,
          end,
          Paint()
            ..color = (width == 2 ? Colors.white : accent).withValues(
              alpha:
                  charge *
                  (width == 13
                      ? .15
                      : width == 6
                      ? .6
                      : .95),
            )
            ..strokeWidth = math.min(width, unit * .7)
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawCircle(
        end,
        unit * .26,
        Paint()..color = Colors.white.withValues(alpha: charge),
      );
    }
    if (progress < .56) return;
    final impact = ((progress - .56) / .35).clamp(0.0, 1.0);
    final alpha = 1 - impact;
    final radius = unit * (1 + impact * 2.3);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: alpha * .7),
          accent.withValues(alpha: alpha * .48),
          accent.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: to, radius: radius));
    canvas.drawCircle(to, radius, glow);
    canvas.drawCircle(
      to,
      radius * .72,
      Paint()
        ..color = accent.withValues(alpha: alpha * .9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi * 2 / 16;
      final direction = Offset(math.cos(a), math.sin(a));
      final spark = to + direction * unit * (.4 + impact * 2.8);
      canvas.drawLine(
        spark,
        spark + direction * unit * .35,
        Paint()
          ..color = (i.isEven ? Colors.white : accent).withValues(alpha: alpha)
          ..strokeWidth = i.isEven ? 1.6 : 2.4,
      );
    }
  }

  @override
  bool shouldRepaint(_CaptureStrikePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.accent != accent ||
      oldDelegate.reduced != reduced ||
      oldDelegate.theme != theme ||
      oldDelegate.role != role;
}

class _CheckAuraPainter extends CustomPainter {
  const _CheckAuraPainter({
    required this.progress,
    required this.reduced,
    required this.theme,
  });
  final double progress;
  final bool reduced;
  final AnimatedArmyTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    if (theme != AnimatedArmyTheme.neon) {
      paintAnimatedArmyKingAura(
        canvas,
        size,
        theme: theme,
        color: Color(theme.blackColorArgb),
        possible: false,
      );
      return;
    }
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * .45;
    final travel = reduced ? .5 : ((progress - .56) / .44).clamp(0.0, 1.0);
    final line = Paint()
      ..color = _rose.withValues(alpha: .75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius * (.75 + travel * .23), line);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 - math.pi / 8;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * radius * .76,
        center + direction * radius,
        line..strokeWidth = i.isEven ? 2.5 : 1,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckAuraPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.reduced != reduced ||
      oldDelegate.theme != theme;
}

class _VictoryPainter extends CustomPainter {
  const _VictoryPainter({
    required this.winner,
    required this.progress,
    required this.reduced,
    required this.theme,
  });
  final Side winner;
  final double progress;
  final bool reduced;
  final AnimatedArmyTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    if (theme != AnimatedArmyTheme.neon) {
      AnimatedArmyVictoryPainter(
        theme: theme,
        winner: winner,
        winnerOnLeft: winner == Side.white,
        progress: progress,
        reducedMotion: reduced,
      ).paint(canvas, size);
      return;
    }
    final accent = winner == Side.white ? _ice : _rose;
    final throneX = size.width * (winner == Side.white ? .25 : .75);
    final beacon = Path()
      ..moveTo(throneX - size.width * .24, size.height)
      ..lineTo(throneX - size.width * .1, 0)
      ..lineTo(throneX + size.width * .1, 0)
      ..lineTo(throneX + size.width * .24, size.height)
      ..close();
    canvas.drawPath(
      beacon,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: .32),
            accent.withValues(alpha: .02),
          ],
        ).createShader(Offset.zero & size),
    );
    final crownY = size.height * .14;
    final crownWidth = math.min(42.0, size.height * .16);
    final crown = Path()
      ..moveTo(throneX - crownWidth, crownY + crownWidth * .5)
      ..lineTo(throneX - crownWidth, crownY)
      ..lineTo(throneX - crownWidth * .45, crownY + crownWidth * .18)
      ..lineTo(throneX, crownY - crownWidth * .3)
      ..lineTo(throneX + crownWidth * .45, crownY + crownWidth * .18)
      ..lineTo(throneX + crownWidth, crownY)
      ..lineTo(throneX + crownWidth, crownY + crownWidth * .5)
      ..close();
    canvas.drawPath(
      crown,
      Paint()
        ..color = const Color(0xFFFFDF91).withValues(alpha: .85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (reduced) return;
    for (var i = 0; i < 52; i++) {
      final x = ((i * .173 + progress * .035) % 1) * size.width;
      final y = ((i * .227 + progress * .36) % 1) * size.height;
      final color = i % 3 == 0 ? const Color(0xFFFFDF91) : accent;
      final length = i.isEven ? 3.0 : 1.5;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(i + progress * 2);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: length,
          height: length * 2.6,
        ),
        Paint()..color = color.withValues(alpha: .75),
      );
      canvas.restore();
    }
    for (var burst = 0; burst < 3; burst++) {
      final age = ((progress - burst * .18) / .62).clamp(0.0, 1.0);
      if (age <= 0 || age >= 1) continue;
      final center = Offset(
        size.width * (.2 + burst * .3),
        size.height * (.2 + (burst.isOdd ? .12 : 0)),
      );
      final radius = math.min(size.width * .16, size.height * .3) * age;
      for (var ray = 0; ray < 14; ray++) {
        final angle = ray * math.pi * 2 / 14;
        final direction = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(
          center + direction * radius * .7,
          center + direction * radius,
          Paint()
            ..color = accent.withValues(alpha: (1 - age) * .75)
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_VictoryPainter oldDelegate) =>
      oldDelegate.winner != winner ||
      oldDelegate.progress != progress ||
      oldDelegate.reduced != reduced ||
      oldDelegate.theme != theme;
}

class _ActionPainter extends CustomPainter {
  const _ActionPainter({
    required this.from,
    required this.to,
    required this.progress,
    required this.strike,
    required this.accent,
    required this.role,
    required this.capture,
    required this.castle,
    required this.promotion,
    required this.check,
    required this.reduced,
    required this.theme,
  });
  final Offset from;
  final Offset to;
  final double progress;
  final double strike;
  final Color accent;
  final Role role;
  final bool capture;
  final bool castle;
  final bool promotion;
  final bool check;
  final bool reduced;
  final AnimatedArmyTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final route = Paint()
      ..color = accent.withValues(alpha: reduced ? .25 : .12 + strike * .35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    if (castle) {
      final shield = Rect.fromCenter(
        center: Offset((from.dx + to.dx) / 2, size.height * .48),
        width: (to.dx - from.dx).abs() + 80,
        height: size.height * .73,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(shield, const Radius.circular(60)),
        route,
      );
      return;
    }
    if (reduced) {
      canvas.drawLine(
        from + const Offset(0, 48),
        to + const Offset(0, 48),
        route,
      );
      return;
    }
    // Check emphasis is attached to the actual surviving king's threat
    // portrait, keeping capture-and-check effects separate from the victim.
    if (progress < .2 || progress > .82) return;
    if (theme != AnimatedArmyTheme.neon) {
      if (!capture || promotion) {
        final trail = Path()
          ..moveTo(from.dx, from.dy + 30)
          ..quadraticBezierTo(
            (from.dx + to.dx) / 2,
            from.dy + (theme == AnimatedArmyTheme.manga ? -25 : 35),
            to.dx,
            to.dy + 30,
          );
        canvas.drawPath(trail, route..strokeWidth = promotion ? 3 : 1.5);
      }
      return;
    }
    final line = Paint()
      ..color = accent.withValues(alpha: strike * .7)
      ..strokeWidth = capture ? 3 : 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    switch (role) {
      case Role.knight:
        final arc = Path()
          ..moveTo(from.dx, from.dy + 20)
          ..quadraticBezierTo(
            (from.dx + to.dx) / 2,
            from.dy - size.height * .28,
            to.dx,
            to.dy,
          );
        canvas.drawPath(arc, line);
      case Role.bishop:
        canvas.drawLine(
          from - const Offset(0, 52),
          to + const Offset(0, 18),
          line,
        );
        canvas.drawLine(
          from - const Offset(0, 56),
          to + const Offset(0, 22),
          line..strokeWidth = .8,
        );
      case Role.rook:
        for (var rail = -1; rail <= 1; rail++) {
          canvas.drawLine(
            from + Offset(0, rail * 13.0),
            to + Offset(0, rail * 13.0),
            line..strokeWidth = rail == 0 ? 4 : 1,
          );
        }
      case Role.queen:
        for (var ray = -1; ray <= 1; ray++) {
          canvas.drawLine(
            from + Offset(0, ray * 30.0),
            to + Offset(0, ray * 12.0),
            line,
          );
        }
        canvas.drawCircle(from, 25 + strike * 18, line);
      case Role.king:
        canvas.drawArc(
          Rect.fromCircle(center: from, radius: 46),
          -.9,
          2.0,
          false,
          line,
        );
      case Role.pawn:
        canvas.drawLine(
          from + const Offset(0, 16),
          to + const Offset(0, 16),
          line,
        );
    }
    if (capture || promotion) {
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: strike * .45),
            accent.withValues(alpha: strike * .45),
            accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: to, radius: 70));
      canvas.drawCircle(to, 70, glow);
      for (var i = 0; i < 9; i++) {
        final angle = i * math.pi * 2 / 9;
        final travel = ((progress - .43) / .35).clamp(0.0, 1.0);
        final point =
            to + Offset(math.cos(angle), math.sin(angle)) * (12 + travel * 62);
        canvas.drawLine(
          point,
          point + Offset(math.cos(angle), math.sin(angle)) * 9,
          Paint()
            ..color = accent.withValues(alpha: strike * .8)
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ActionPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.role != role ||
      oldDelegate.accent != accent ||
      oldDelegate.strike != strike ||
      oldDelegate.capture != capture ||
      oldDelegate.castle != castle ||
      oldDelegate.promotion != promotion ||
      oldDelegate.check != check ||
      oldDelegate.reduced != reduced ||
      oldDelegate.theme != theme;
}

/// Shared capture art for the live arena and film. Call only for a validated
/// captured victim; checks are rendered by their surviving king's aura.
void paintAnimatedArmyAttack(
  Canvas canvas,
  Size size, {
  required AnimatedArmyTheme theme,
  required Offset from,
  required Offset to,
  required double progress,
  required Color accent,
  required Role role,
  required bool reducedMotion,
  required double landingProgress,
}) {
  final unit = math.max(3.0, math.min(30.0, size.height * .12));
  final start = landingProgress < .5 ? 0.0 : .18;
  if (!reducedMotion && (progress < start || progress >= .96)) return;
  final flight = reducedMotion
      ? 1.0
      : _ease(((progress - start) / (landingProgress - start)).clamp(0.0, 1.0));
  final fade = reducedMotion
      ? .45
      : 1 -
            ((progress - landingProgress) / (1 - landingProgress)).clamp(
              0.0,
              1.0,
            );
  final end = Offset.lerp(from, to, flight)!;
  final paint = Paint()
    ..color = accent.withValues(alpha: fade * .85)
    ..style = PaintingStyle.stroke
    ..strokeWidth = reducedMotion ? 1.5 : 2.5
    ..strokeCap = StrokeCap.round;
  if (reducedMotion) {
    canvas.drawLine(from, to, paint);
    canvas.drawCircle(to, unit * .6, paint);
    return;
  }
  switch (theme) {
    case AnimatedArmyTheme.manga:
      for (var blade = 0; blade < (role == Role.queen ? 3 : 2); blade++) {
        final slash = Path()
          ..moveTo(from.dx, from.dy + blade * 4)
          ..quadraticBezierTo(
            (from.dx + end.dx) / 2,
            from.dy - unit * (1.3 + blade * .25),
            end.dx,
            end.dy + blade * 4,
          );
        canvas.drawPath(slash, paint..strokeWidth = blade == 0 ? 3 : 1);
      }
      canvas.drawArc(
        Rect.fromCircle(center: end, radius: unit * .7),
        -.8,
        math.pi * 1.25,
        false,
        paint..strokeWidth = 3,
      );
    case AnimatedArmyTheme.epic:
      final mystic = role == Role.queen || role == Role.bishop;
      canvas.drawLine(from, end, paint..strokeWidth = mystic ? 1 : 2.5);
      canvas.drawCircle(end, unit * (mystic ? .7 : .3), paint);
      if (mystic) canvas.drawCircle(end, unit * .42, paint..strokeWidth = 1);
      for (var flame = 0; flame < 8; flame++) {
        final angle = flame * math.pi / 4 + progress * 7;
        final ray = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(
          end + ray * unit * .38,
          end + ray * unit * (mystic ? .95 : .5),
          paint..strokeWidth = 2,
        );
      }
    case AnimatedArmyTheme.olympian:
      for (var bolt = 0; bolt < (role == Role.rook ? 3 : 1); bolt++) {
        final lightning = Path()..moveTo(from.dx, from.dy + bolt * 5);
        for (var zig = 1; zig <= 8; zig++) {
          final point = Offset.lerp(from, end, zig / 8)!;
          lightning.lineTo(
            point.dx,
            point.dy +
                bolt * 5 +
                (zig == 8 ? 0 : (zig.isEven ? -1 : 1) * unit * .23),
          );
        }
        canvas.drawPath(lightning, paint..strokeWidth = bolt == 0 ? 2.8 : 1);
      }
    case AnimatedArmyTheme.neon:
      canvas.drawLine(from, end, paint);
  }
  if (progress < landingProgress) return;
  final impact = ((progress - landingProgress) / (1 - landingProgress)).clamp(
    0.0,
    1.0,
  );
  if (theme == AnimatedArmyTheme.olympian) {
    final shield = Path()
      ..moveTo(to.dx, to.dy - unit)
      ..lineTo(to.dx + unit * .8, to.dy - unit * .45)
      ..lineTo(to.dx + unit * .55, to.dy + unit * .6)
      ..lineTo(to.dx, to.dy + unit)
      ..lineTo(to.dx - unit * .55, to.dy + unit * .6)
      ..lineTo(to.dx - unit * .8, to.dy - unit * .45)
      ..close();
    canvas.drawPath(shield, paint..strokeWidth = 1.5);
  } else if (theme == AnimatedArmyTheme.epic) {
    canvas.save();
    canvas.translate(to.dx - unit, to.dy - unit);
    paintAnimatedArmyKingAura(
      canvas,
      Size(unit * 2, unit * 2),
      theme: theme,
      color: accent.withValues(alpha: fade),
      possible: false,
    );
    canvas.restore();
  }
  for (var ray = 0; ray < 12; ray++) {
    final angle = ray * math.pi / 6;
    final direction = Offset(math.cos(angle), math.sin(angle));
    canvas.drawLine(
      to + direction * unit * (.4 + impact),
      to + direction * unit * (.7 + impact * 1.3),
      paint..strokeWidth = 1.5,
    );
  }
}

/// Stable themed crest around a real threatened king, including reduced motion.
void paintAnimatedArmyKingAura(
  Canvas canvas,
  Size size, {
  required AnimatedArmyTheme theme,
  required Color color,
  required bool possible,
}) {
  final center = size.center(Offset.zero);
  final radius = math.min(size.width, size.height) * .44;
  final line = Paint()
    ..color = color.withValues(alpha: .8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  for (var i = 0; i < 12; i++) {
    final angle = i * math.pi / 6;
    if (possible && i.isOdd) continue;
    final radial = Offset(math.cos(angle), math.sin(angle));
    switch (theme) {
      case AnimatedArmyTheme.manga:
        canvas.drawLine(
          center + radial * radius * .72,
          center + radial * radius,
          line..strokeWidth = i.isEven ? 2 : 1,
        );
      case AnimatedArmyTheme.epic:
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(angle);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(radius * .83, 0),
            width: radius * .35,
            height: radius * .18,
          ),
          line,
        );
        canvas.restore();
      case AnimatedArmyTheme.olympian:
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(angle);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(radius * .88, 0),
            width: radius * .24,
            height: radius * .10,
          ),
          line,
        );
        canvas.restore();
      case AnimatedArmyTheme.neon:
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          angle,
          math.pi / 8,
          false,
          line,
        );
    }
  }
  if (!possible && theme != AnimatedArmyTheme.olympian) {
    canvas.drawCircle(center, radius * .70, line..strokeWidth = .9);
  }
}

/// A faction crest and celebratory particles for a verified winner only.
class AnimatedArmyVictoryPainter extends CustomPainter {
  const AnimatedArmyVictoryPainter({
    required this.theme,
    required this.winner,
    required this.winnerOnLeft,
    required this.progress,
    required this.reducedMotion,
  });
  final AnimatedArmyTheme theme;
  final Side winner;
  final bool winnerOnLeft;
  final double progress;
  final bool reducedMotion;
  @override
  void paint(Canvas canvas, Size size) {
    final color = Color(
      winner == Side.white ? theme.whiteColorArgb : theme.blackColorArgb,
    );
    final x = size.width * (winnerOnLeft ? .25 : .75);
    final crestSize = math.min(38.0, size.height * .18);
    canvas.save();
    canvas.translate(x - crestSize / 2, size.height * .10);
    paintAnimatedArmyKingAura(
      canvas,
      Size.square(crestSize),
      theme: theme,
      color: color,
      possible: false,
    );
    canvas.restore();
    if (reducedMotion) return;
    final fleck = Paint()..color = color.withValues(alpha: .65);
    for (var i = 0; i < 28; i++) {
      final point = Offset(
        ((i * .173 + progress * .025) % 1) * size.width,
        ((i * .227 + progress * .32) % 1) * size.height,
      );
      if (theme == AnimatedArmyTheme.manga) {
        canvas.drawLine(
          point,
          point + const Offset(3, -3),
          fleck..strokeWidth = 1.5,
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: point,
            width: 3,
            height: theme == AnimatedArmyTheme.epic ? 5 : 1.5,
          ),
          fleck,
        );
      }
    }
  }

  @override
  bool shouldRepaint(AnimatedArmyVictoryPainter old) =>
      old.theme != theme ||
      old.winner != winner ||
      old.winnerOnLeft != winnerOnLeft ||
      old.progress != progress ||
      old.reducedMotion != reducedMotion;
}
