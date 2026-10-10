// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, lerpDouble;

import 'package:flutter/material.dart';

import '../../services/arena_credit_controller.dart';
import '../../services/theme_music.dart';
import 'gold_credit_coin.dart';

/// Provides the shared scopes without reserving a permanent strip above every
/// screen. Each screen places the balance in its own compact header row.
class ArenaCreditAppFrame extends StatelessWidget {
  const ArenaCreditAppFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class ArenaCreditHeader extends StatefulWidget {
  const ArenaCreditHeader({this.compact = false, super.key});

  final bool compact;

  @override
  State<ArenaCreditHeader> createState() => _ArenaCreditHeaderState();
}

class _ArenaCreditHeaderState extends State<ArenaCreditHeader>
    with SingleTickerProviderStateMixin {
  late final ArenaCreditController _fallbackCredits = ArenaCreditController();
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    value: 1,
  )..addListener(_tick);
  ArenaCreditController? _credits;
  ArenaCreditChange? _change;
  int? _from;
  int? _to;
  int _lastChangeSequence = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = ArenaCreditScope.maybeOf(context) ?? _fallbackCredits;
    if (identical(next, _credits)) return;
    _credits?.removeListener(_handleCreditUpdate);
    _credits = next..addListener(_handleCreditUpdate);
    _to = next.credits;
    _from = _to;
    _lastChangeSequence = next.lastChange?.sequence ?? 0;
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  int? get _displayedCredits {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return to;
    final progress = Curves.easeOutCubic.transform(_animation.value);
    return lerpDouble(from, to, progress)?.round();
  }

  void _handleCreditUpdate() {
    if (!mounted) return;
    final credits = _credits!;
    final event = credits.lastChange;
    if (event != null && event.sequence != _lastChangeSequence) {
      final displayed = _displayedCredits;
      _lastChangeSequence = event.sequence;
      _change = event;
      _from = displayed ?? event.from;
      _to = event.to;
      _animation.duration = Duration(
        milliseconds: event.isAddition ? 1100 : 650,
      );
      _animation.forward(from: 0);
      // Reward sounds are celebratory. Charges stay silent so spending a
      // credit never interrupts the active soundtrack.
      if (event.isAddition) {
        unawaited(
          MusicScope.of(context)?.playEffect(CinematicSound.creditCoin),
        );
      }
      setState(() {});
      return;
    }
    if (_to != credits.credits) {
      _animation.stop();
      _change = null;
      _from = credits.credits;
      _to = credits.credits;
      _animation.value = 1;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _credits?.removeListener(_handleCreditUpdate);
    _fallbackCredits.dispose();
    _animation
      ..removeListener(_tick)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final credits = _credits!;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final value = reduceMotion ? credits.credits : _displayedCredits;
    final event = _change;
    final progress = reduceMotion ? 1.0 : _animation.value;
    final changing = event != null && progress < 1;
    final addition = event?.isAddition == true && changing;
    final deduction = event?.delta.isNegative == true && changing;
    final pulse = changing ? math.sin(progress * math.pi) : 0.0;
    final deltaOpacity = reduceMotion
        ? 0.0
        : progress < .72
        ? 1.0
        : ((1 - progress) / .28).clamp(0.0, 1.0);
    final colors = Theme.of(context).colorScheme;
    final badgeColor = Color.lerp(
      colors.surfaceContainerHighest,
      event?.isAddition == true ? const Color(0xFF806516) : colors.error,
      pulse * (addition ? .72 : .48),
    )!;
    final freshness = credits.isLive
        ? 'Live server balance'
        : credits.hasCachedBalance
        ? 'Last known balance while offline'
        : 'Welcome balance; confirmed when your online profile connects';
    final amountLabel = '$value';

    return Material(
      key: const ValueKey('arena-credit-header'),
      color: Colors.transparent,
      child: SizedBox(
        width: widget.compact ? 92 : 100,
        height: widget.compact ? 32 : 36,
        child: Semantics(
          liveRegion: true,
          label: 'Credits, $amountLabel. $freshness.',
          child: ExcludeSemantics(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  key: const ValueKey('arena-credit-header-balance'),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  width: widget.compact ? 92 : 100,
                  height: widget.compact ? 28 : 32,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: addition
                          ? Colors.amberAccent.withValues(alpha: .8)
                          : deduction
                          ? colors.error.withValues(alpha: .95)
                          : colors.outlineVariant,
                    ),
                    boxShadow: changing
                        ? [
                            BoxShadow(
                              color:
                                  (addition ? Colors.amberAccent : colors.error)
                                      .withValues(alpha: pulse * .38),
                              blurRadius: 12 * pulse,
                              spreadRadius: 2 * pulse,
                            ),
                          ]
                        : const [],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GoldCreditCoin(size: widget.compact ? 15 : 17),
                        const SizedBox(width: 4),
                        SizedBox(
                          key: const ValueKey(
                            'arena-credit-header-amount-slot',
                          ),
                          width: 48,
                          height: 20,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              amountLabel,
                              key: const ValueKey('arena-credit-header-amount'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 14,
                          child: !credits.isLive && credits.account != null
                              ? const Padding(
                                  padding: EdgeInsets.only(left: 2),
                                  child: Icon(
                                    Icons.cloud_off_outlined,
                                    key: ValueKey('arena-credit-header-cached'),
                                    size: 12,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                if (deduction && !reduceMotion)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Transform.scale(
                        scale: 1 + pulse * .22,
                        child: Opacity(
                          opacity: pulse * .9,
                          child: Container(
                            key: const ValueKey('arena-credit-deduction-pulse'),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: colors.error,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (addition && !reduceMotion) ...[
                  Positioned(
                    left: -8 - 4 * pulse,
                    top: -4 - 3 * pulse,
                    child: Opacity(
                      opacity: pulse,
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 11,
                        color: Colors.amberAccent,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -9 - 5 * pulse,
                    bottom: -4 - 2 * pulse,
                    child: Opacity(
                      opacity: pulse,
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 9,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                Positioned(
                  top: -6,
                  right: 6,
                  child: IgnorePointer(
                    child: SizedBox(
                      key: const ValueKey('arena-credit-delta-slot'),
                      width: 32,
                      height: 14,
                      child: event != null && deltaOpacity > 0
                          ? Opacity(
                              opacity: deltaOpacity,
                              child: Transform.translate(
                                offset: Offset(0, (1 - progress) * 3),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '${event.delta > 0 ? '+' : ''}${event.delta}',
                                        key: ValueKey(
                                          'arena-credit-delta-${event.sequence}',
                                        ),
                                        style: TextStyle(
                                          color: event.isAddition
                                              ? Colors.amberAccent
                                              : colors.error,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
