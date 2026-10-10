// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../domain/neon_live_action.dart';
import '../../services/theme_music.dart';
import 'animated_move_timing.dart';

CinematicSound animatedCaptureImpactSound({
  required Role role,
  required bool checkmate,
}) => checkmate
    ? CinematicSound.finalStrike
    : switch (role) {
        Role.king || Role.queen || Role.rook => CinematicSound.heavyImpact,
        _ => CinematicSound.lightImpact,
      };

/// Owns accepted Animated capture cues when an opponent card replaces the stage.
/// Its clock follows board movement and is independent of capture-overlay Skip.
class AnimatedAcceptedCaptureCues extends StatefulWidget {
  const AnimatedAcceptedCaptureCues({
    required this.position,
    this.action,
    this.enabled = true,
    this.reducedMotion = false,
    super.key,
  });

  final Position position;
  final NeonLiveAction? action;
  final bool enabled;
  final bool reducedMotion;

  @override
  State<AnimatedAcceptedCaptureCues> createState() =>
      _AnimatedAcceptedCaptureCuesState();
}

class _AnimatedAcceptedCaptureCuesState
    extends State<AnimatedAcceptedCaptureCues>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _motion = AnimationController(
    vsync: this,
    duration: animatedMoveDuration,
    value: 1,
  );
  ThemeMusic? _music;
  bool _backgrounded = false;
  bool _reduced = false;
  bool _armed = false;
  bool _attackPlayed = false;
  bool _impactPlayed = false;
  CinematicSound _impact = CinematicSound.lightImpact;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _motion.addListener(_playCues);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _backgrounded = lifecycle != null && lifecycle != AppLifecycleState.resumed;
    // Mounting a restored game never arms its last accepted capture.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _music = MusicScope.of(context);
    _reduced =
        widget.reducedMotion ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (_reduced) _motion.value = 1;
    _playCues();
  }

  @override
  void didUpdateWidget(AnimatedAcceptedCaptureCues oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reduced =
        widget.reducedMotion ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (!widget.enabled) {
      _armed = false;
      _motion.stop();
      return;
    }
    if (oldWidget.position.fen != widget.position.fen) {
      final action = widget.action;
      _armed =
          oldWidget.enabled &&
          action != null &&
          !action.isSelection &&
          action.captured != null;
      _attackPlayed = false;
      _impactPlayed = false;
      _motion.stop();
      if (_armed) {
        _impact = animatedCaptureImpactSound(
          role: action!.actor.role,
          checkmate: widget.position.isCheckmate,
        );
        if (_reduced) {
          _motion.value = 1;
        } else if (_backgrounded) {
          _motion.value = 0;
        } else {
          _motion.forward(from: 0);
        }
      }
    } else if (_reduced && _motion.value != 1) {
      _motion.value = 1;
    }
    // Clock/ACK revisions, selection and Skip do not restart or cancel a strike.
    _playCues();
  }

  void _playCues() {
    if (!_armed || _backgrounded || !widget.enabled) return;
    if (!_attackPlayed) {
      _attackPlayed = true;
      unawaited(_music?.playEffect(CinematicSound.attack));
    }
    if (!_impactPlayed &&
        (_reduced || _motion.value >= animatedMoveImpactFraction)) {
      _impactPlayed = true;
      unawaited(_music?.playEffect(_impact));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _backgrounded = state != AppLifecycleState.resumed;
    if (_backgrounded) {
      _motion.stop();
    } else if (_armed && !_reduced && _motion.value < 1) {
      _motion.forward();
    }
    _playCues();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.removeListener(_playCues);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
