// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/capture_threat.dart';
import 'play_assist_style.dart';

class ThreatScanController extends ChangeNotifier {
  static const pairDuration = Duration(seconds: 3);
  Timer? _pairTimer;
  Timer? _blinkTimer;
  List<CaptureThreat> _threats = const [];
  int _index = 0;
  bool _lit = true;
  bool _active = false;
  String? _message;
  bool _reducedMotion = false;

  bool get active => _active;
  bool get lit => _reducedMotion || _lit;
  CaptureThreat? get current => _active ? _threats[_index] : null;
  String? get message => _message;

  void start(List<CaptureThreat> threats, {required bool reducedMotion}) {
    _cancelTimers();
    _threats = List.of(threats);
    _index = 0;
    _reducedMotion = reducedMotion;
    _active = threats.isNotEmpty;
    if (_active) {
      _showPair();
    } else {
      _message =
          'No immediate checks or capture threats in this position. Future tactics still matter.';
      notifyListeners();
    }
  }

  void _showPair() {
    _cancelTimers();
    _lit = true;
    _message =
        'Threat ${_index + 1} of ${_threats.length} · ${current!.description}';
    _pairTimer = Timer(pairDuration, () {
      _index++;
      if (_index == _threats.length) {
        _cancelTimers();
        _active = false;
        _message =
            'Scan complete · ${_threats.length} ${_threats.length == 1 ? 'threat' : 'threats'} shown.';
        notifyListeners();
      } else {
        _showPair();
      }
    });
    _startBlinking();
    notifyListeners();
  }

  void _startBlinking() {
    _blinkTimer?.cancel();
    if (_active && !_reducedMotion) {
      // One gentle on/off cycle per second; never a rapid strobe.
      _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        _lit = !_lit;
        notifyListeners();
      });
    }
  }

  void setReducedMotion(bool reduced) {
    if (_reducedMotion == reduced) return;
    _reducedMotion = reduced;
    _lit = true;
    _startBlinking();
    // Called from didChangeDependencies; that dependency already rebuilds UI.
  }

  void stop() {
    _cancelTimers();
    final changed = _active || _message != null;
    _active = false;
    _message = null;
    _threats = const [];
    if (changed) notifyListeners();
  }

  void _cancelTimers() {
    _pairTimer?.cancel();
    _blinkTimer?.cancel();
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}

class ThreatScanControls extends StatelessWidget {
  const ThreatScanControls({
    required this.scan,
    required this.enabled,
    required this.onScan,
    super.key,
  });
  final ThreatScanController scan;
  final bool enabled;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          FilledButton.tonalIcon(
            key: const ValueKey('analyse-threats'),
            onPressed: scan.active
                ? scan.stop
                : enabled
                ? onScan
                : null,
            icon: scan.active
                ? const Icon(Icons.stop_circle_outlined)
                : const ThreatActionIcon(size: 18),
            label: Text(
              scan.active ? 'Stop threat scan' : 'Analyse attack threats',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Opponent checks and captures on the current board · 3 seconds per threat. Free to use; clocks keep running.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class ThreatScanButton extends StatelessWidget {
  const ThreatScanButton({
    required this.scan,
    required this.enabled,
    required this.onScan,
    super.key,
  });

  final ThreatScanController scan;
  final bool enabled;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    style: playAssistButtonStyle,
    key: const ValueKey('analyse-threats'),
    onPressed: scan.active
        ? scan.stop
        : enabled
        ? onScan
        : null,
    icon: scan.active
        ? const Icon(Icons.stop_circle_outlined)
        : const ThreatActionIcon(size: 18),
    label: Text(
      scan.active ? 'Stop scan' : 'Threat scan',
      textAlign: TextAlign.center,
    ),
  );
}

class ThreatScanBanner extends StatelessWidget {
  const ThreatScanBanner({required this.scan, super.key});
  final ThreatScanController scan;
  @override
  Widget build(BuildContext context) => scan.message == null
      ? const SizedBox.shrink()
      : Padding(
          key: const ValueKey('threat-scan-board-status'),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  scan.message!,
                  key: const ValueKey('threat-scan-message'),
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: scan.active
                    ? 'Stop threat scan'
                    : 'Dismiss threat scan',
                onPressed: scan.stop,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        );
}
