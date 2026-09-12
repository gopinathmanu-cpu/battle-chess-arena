// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:math' as math;
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import '../../domain/game_session.dart';
import 'board_appearance.dart';
import '../../domain/piece_pack.dart';
import '../../services/theme_music.dart';

Duration captureBattleDuration({required bool reduced, required bool fast}) {
  if (reduced) return const Duration(milliseconds: 300);
  if (fast) return const Duration(milliseconds: 700);
  return const Duration(milliseconds: 1500);
}

String captureDescription(MoveResolution battle) {
  String sideName(Side side) => side == Side.white ? 'White' : 'Black';
  String roleName(Role role) => switch (role) {
    Role.king => 'King',
    Role.queen => 'Queen',
    Role.rook => 'Rook',
    Role.bishop => 'Bishop',
    Role.knight => 'Knight',
    Role.pawn => 'Pawn',
  };
  String squareLabel(Piece piece, Square square) {
    final prefix = switch (piece.role) {
      Role.king => 'K',
      Role.queen => 'Q',
      Role.rook => 'R',
      Role.bishop => 'B',
      Role.knight => 'N',
      Role.pawn => '',
    };
    return '$prefix${square.name}';
  }

  final defender = battle.defender!;
  return '${sideName(battle.attacker.color)} ${roleName(battle.attacker.role)} '
      '(${squareLabel(battle.attacker, battle.move.from)}) takes '
      '${sideName(defender.color)} ${roleName(defender.role)} '
      '(${squareLabel(defender, battle.move.to)})';
}

CinematicSound cinematicImpactSound(MoveResolution battle) {
  if (battle.san.endsWith('#')) return CinematicSound.finalStrike;
  return switch (battle.attacker.role) {
    Role.rook || Role.queen || Role.king => CinematicSound.heavyImpact,
    _ => CinematicSound.lightImpact,
  };
}

class CaptureBattleOverlay extends StatefulWidget {
  const CaptureBattleOverlay({
    required this.battle,
    required this.accent,
    required this.reduced,
    required this.useCharacterAsset,
    required this.onSkip,
    this.fast = false,
    this.appearance,
    this.orientation = Side.white,
    super.key,
  });
  final BoardAppearance? appearance;
  final MoveResolution battle;
  final Color accent;
  final bool reduced;
  final bool fast;
  final bool useCharacterAsset;
  final VoidCallback onSkip;
  final Side orientation;

  @override
  State<CaptureBattleOverlay> createState() => CaptureBattleOverlayState();
}

class CaptureBattleOverlayState extends State<CaptureBattleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _impactSoundTimer;
  bool _soundScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: captureBattleDuration(
        reduced: widget.reduced,
        fast: widget.fast,
      ),
    )..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_soundScheduled) return;
    _soundScheduled = true;
    final music = MusicScope.of(context);
    unawaited(music?.playEffect(CinematicSound.attack));
    final duration = captureBattleDuration(
      reduced: widget.reduced,
      fast: widget.fast,
    );
    _impactSoundTimer = Timer(
      Duration(milliseconds: (duration.inMilliseconds * .32).round()),
      () => unawaited(music?.playEffect(cinematicImpactSound(widget.battle))),
    );
  }

  @override
  void dispose() {
    _impactSoundTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = _controller.value;
        final travel = Curves.easeInOutCubic.transform(
          (value / .32).clamp(0.0, 1.0),
        );
        final cinematic = Curves.easeOutCubic.transform(
          ((value - .38) / .62).clamp(0.0, 1.0),
        );
        final backdropOpacity = ((value - .34) / .18).clamp(0.0, 1.0) * .95;
        final impact = ((value - .27) / .22).clamp(0.0, 1.0);
        final flash = (1 - ((value - .32).abs() / .07)).clamp(0.0, 1.0);
        return Opacity(
          opacity: widget.reduced ? value : 1,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(
                    0xFF0A0812,
                  ).withValues(alpha: backdropOpacity),
                ),
              ),
              if (!widget.reduced)
                _BoardCaptureFlight(
                  battle: widget.battle,
                  appearance: widget.appearance,
                  orientation: widget.orientation,
                  accent: widget.accent,
                  progress: travel,
                  opacity: 1 - ((value - .32) / .12).clamp(0.0, 1.0),
                ),
              if (!widget.reduced)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _ImpactBurstPainter(
                        progress: impact,
                        color: widget.accent,
                      ),
                    ),
                  ),
                ),
              if (!widget.reduced && flash > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: flash * .24),
                    ),
                  ),
                ),
              if (!widget.reduced)
                Positioned.fill(
                  child: Opacity(
                    opacity: cinematic,
                    child: CustomPaint(
                      painter: _SpeedLinesPainter(
                        progress: cinematic,
                        color: widget.accent,
                      ),
                    ),
                  ),
                ),
              Opacity(
                opacity: widget.reduced ? value : cinematic,
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.translate(
                          offset: Offset(
                            widget.reduced ? 0 : -50 * (1 - cinematic),
                            0,
                          ),
                          child: _Fighter(
                            piece: widget.battle.attacker,
                            pack:
                                widget.appearance?.army(
                                  widget.battle.attacker.color,
                                ) ??
                                piecePacks.first,
                            accent: widget.accent,
                            useCharacterAsset: widget.useCharacterAsset,
                            victorious: true,
                            progress: cinematic,
                          ),
                        ),
                        Transform.scale(
                          scale: widget.reduced ? 1 : .4 + cinematic,
                          child: Icon(
                            Icons.bolt,
                            size: 60,
                            color: widget.accent,
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(
                            widget.reduced ? 0 : 50 * (1 - cinematic),
                            0,
                          ),
                          child: Opacity(
                            opacity:
                                1 -
                                (_controller.value > .72
                                    ? (_controller.value - .72) / .28
                                    : 0),
                            child: _Fighter(
                              piece: widget.battle.defender!,
                              pack:
                                  widget.appearance?.army(
                                    widget.battle.defender!.color,
                                  ) ??
                                  piecePacks.first,
                              accent: Colors.white70,
                              useCharacterAsset: widget.useCharacterAsset,
                              victorious: false,
                              progress: cinematic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 28,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: widget.reduced ? value : cinematic,
                  child: Text(
                    widget.battle.san.endsWith('#')
                        ? 'FINAL STRIKE'
                        : 'CAPTURE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.accent,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 68,
                left: 16,
                right: 16,
                child: Opacity(
                  opacity: widget.reduced ? value : cinematic,
                  child: Text(
                    captureDescription(widget.battle),
                    key: const ValueKey('capture-description'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: TextButton.icon(
                  onPressed: widget.onSkip,
                  icon: const Icon(Icons.fast_forward),
                  label: const Text('Skip'),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _BoardCaptureFlight extends StatelessWidget {
  const _BoardCaptureFlight({
    required this.battle,
    required this.appearance,
    required this.orientation,
    required this.accent,
    required this.progress,
    required this.opacity,
  });

  final MoveResolution battle;
  final BoardAppearance? appearance;
  final Side orientation;
  final Color accent;
  final double progress;
  final double opacity;

  Offset _squareOffset(Square square, double cell) {
    final file = square.file;
    final rank = square.rank;
    final column = orientation == Side.white ? file : 7 - file;
    final row = orientation == Side.white ? 7 - rank : rank;
    return Offset(column * cell, row * cell);
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final cell = constraints.maxWidth / 8;
        final from = _squareOffset(battle.move.from, cell);
        final to = _squareOffset(battle.move.to, cell);
        final location = Offset.lerp(from, to, progress)!;
        final pack =
            appearance?.army(battle.attacker.color) ?? piecePacks.first;
        final defenderPack =
            appearance?.army(battle.defender!.color) ?? piecePacks.first;
        return Stack(
          children: [
            Positioned(
              key: ValueKey('capture-target-${battle.move.to.name}'),
              left: to.dx,
              top: to.dy,
              width: cell,
              height: cell,
              child: Opacity(
                opacity: 1 - ((progress - .76) / .24).clamp(0.0, 1.0),
                child: CharacterPiece(
                  piece: battle.defender!,
                  pack: defenderPack,
                ),
              ),
            ),
            Positioned(
              key: ValueKey(
                'capture-flight-${battle.move.from.name}-${battle.move.to.name}',
              ),
              left: location.dx,
              top: location.dy,
              width: cell,
              height: cell,
              child: Opacity(
                opacity: opacity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: .75),
                        blurRadius: cell * .35,
                        spreadRadius: cell * .06,
                      ),
                    ],
                  ),
                  child: Transform.scale(
                    scale: 1 + math.sin(progress * math.pi) * .18,
                    child: CharacterPiece(piece: battle.attacker, pack: pack),
                  ),
                ),
              ),
            ),
            if (progress > .72)
              Positioned(
                left: to.dx,
                top: to.dy,
                width: cell,
                height: cell,
                child: IgnorePointer(
                  child: Transform.scale(
                    scale: .5 + progress * .7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(
                            alpha: (1 - progress).clamp(0.0, 1.0),
                          ),
                          width: 4,
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

class _Fighter extends StatelessWidget {
  const _Fighter({
    required this.piece,
    required this.pack,
    required this.accent,
    required this.useCharacterAsset,
    required this.victorious,
    required this.progress,
  });
  final Piece piece;
  final PiecePack pack;
  final Color accent;
  final bool useCharacterAsset;
  final bool victorious;
  final double progress;

  IconData get _roleIcon => switch (piece.role) {
    Role.king => Icons.workspace_premium,
    Role.queen => Icons.auto_awesome,
    Role.rook => Icons.account_balance,
    Role.bishop => Icons.change_history,
    Role.knight => Icons.bolt,
    Role.pawn => Icons.shield_outlined,
  };

  Color get _roleAccent => victorious
      ? switch (piece.role) {
          Role.king => const Color(0xFFFFD54F),
          Role.queen => const Color(0xFFF48FB1),
          Role.rook => const Color(0xFFFFB74D),
          Role.bishop => const Color(0xFFCE93D8),
          Role.knight => const Color(0xFF80DEEA),
          Role.pawn => accent,
        }
      : Colors.blueGrey.shade300;

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleAccent;
    final art = useCharacterAsset && pack.id == PiecePackId.anime
        ? ClipRect(
            child: Align(
              alignment: piece.color == Side.white
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              widthFactor: .5,
              child: Image.asset(
                'assets/characters/manga-vanguard-pawn-duel.png',
                width: 240,
                height: 132,
                fit: BoxFit.contain,
              ),
            ),
          )
        : SizedBox.square(
            dimension: 88,
            child: CharacterPiece(piece: piece, pack: pack),
          );
    return Transform.scale(
      scale: victorious ? 1 + math.sin(progress * math.pi).abs() * .055 : 1,
      child: Container(
        width: 100,
        height: 142,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              roleColor.withValues(alpha: victorious ? .82 : .38),
              const Color(0xFF171021),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(42),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(42),
          ),
          border: Border.all(color: roleColor, width: victorious ? 3 : 1.5),
          boxShadow: [
            BoxShadow(
              color: roleColor.withValues(alpha: victorious ? .72 : .20),
              blurRadius: victorious ? 32 : 14,
              spreadRadius: victorious ? 3 : 0,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (victorious)
              art
            else
              ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  .28,
                  .58,
                  .14,
                  0,
                  0,
                  .28,
                  .58,
                  .14,
                  0,
                  0,
                  .28,
                  .58,
                  .14,
                  0,
                  0,
                  0,
                  0,
                  0,
                  .72,
                  0,
                ]),
                child: art,
              ),
            Positioned(
              top: 6,
              right: 7,
              child: Icon(_roleIcon, size: 20, color: roleColor),
            ),
            Positioned(
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: victorious ? const Color(0xFFE5A900) : Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  victorious ? 'VICTOR' : 'DEFEATED',
                  style: TextStyle(
                    color: victorious ? Colors.black : Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImpactBurstPainter extends CustomPainter {
  const _ImpactBurstPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = size.center(Offset.zero);
    final fade = 1 - progress;
    final ring = Paint()
      ..color = color.withValues(alpha: fade * .8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 + fade * 5;
    canvas.drawCircle(center, 18 + progress * size.shortestSide * .32, ring);
    final ray = Paint()
      ..color = Colors.white.withValues(alpha: fade * .9)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;
    for (var i = 0; i < 16; i++) {
      final angle = math.pi * 2 * i / 16;
      final inner = 22 + progress * 55;
      final outer = inner + 18 + progress * 42;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        ray,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ImpactBurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _SpeedLinesPainter extends CustomPainter {
  const _SpeedLinesPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color.withValues(alpha: .18 * progress)
      ..strokeWidth = 2;
    for (var i = 0; i < 28; i++) {
      final angle = math.pi * 2 / 28 * i;
      canvas.drawLine(
        Offset(
          center.dx + math.cos(angle) * 55,
          center.dy + math.sin(angle) * 55,
        ),
        Offset(
          center.dx + math.cos(angle) * size.longestSide,
          center.dy + math.sin(angle) * size.longestSide,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedLinesPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
