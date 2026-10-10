// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

/// Keeps live action visible while the existing board and match controls remain
/// interactive. A compact viewport fits the entire board before scrolling.
class NeonLiveGameLayout extends StatefulWidget {
  const NeonLiveGameLayout({
    required this.arena,
    required this.board,
    required this.header,
    required this.details,
    required this.scrollController,
    this.boardFooter,
    this.quickActions,
    this.portraitScrollKey,
    this.landscapeScrollKey,
    this.compactPortraitArena = false,
    super.key,
  });

  final Widget arena, board, header;
  final List<Widget> details;
  final ScrollController scrollController;
  final Widget? boardFooter;
  final Widget? quickActions;
  final Key? portraitScrollKey, landscapeScrollKey;

  /// Opponent cards keep their natural height; illustrated stages keep theirs.
  final bool compactPortraitArena;

  @override
  State<NeonLiveGameLayout> createState() => _NeonLiveGameLayoutState();
}

class _NeonLiveGameLayoutState extends State<NeonLiveGameLayout> {
  bool _boardOnLeft = false;

  double _actionsHeight(BuildContext context) => widget.quickActions == null
      ? 0
      : (MediaQuery.textScalerOf(context).scale(14) * 2.6 + 24)
            .clamp(60, 104)
            .toDouble();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, screen) {
        final landscape = screen.maxWidth > screen.maxHeight;
        final actionsHeight = _actionsHeight(context);
        if (landscape) {
          final rowHeight = math.max(
            1.0,
            math.min((screen.maxWidth - 64) / 2, screen.maxHeight - 16),
          );
          final actionPanel = Expanded(
            key: const ValueKey('neon-live-animation-panel'),
            child: Column(
              children: [
                Expanded(child: widget.arena),
                if (widget.quickActions != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    key: const ValueKey('neon-live-quick-actions'),
                    height: actionsHeight,
                    child: widget.quickActions,
                  ),
                ],
              ],
            ),
          );
          final boardPanel = Expanded(
            key: const ValueKey('neon-live-board-panel'),
            child: Center(
              child: SizedBox.square(dimension: rowHeight, child: widget.board),
            ),
          );
          return SizedBox.expand(
            key: const ValueKey('neon-live-game-layout'),
            child: ListView(
              key: widget.landscapeScrollKey,
              controller: widget.scrollController,
              padding: const EdgeInsets.all(8),
              children: [
                SizedBox(
                  height: rowHeight,
                  child: Row(
                    key: const ValueKey('neon-live-landscape-action-board-row'),
                    children: [
                      _boardOnLeft ? boardPanel : actionPanel,
                      SizedBox(
                        width: 48,
                        child: IconButton(
                          key: const ValueKey('neon-live-swap-panels'),
                          tooltip: _boardOnLeft
                              ? 'Place chessboard on right'
                              : 'Place chessboard on left',
                          onPressed: () =>
                              setState(() => _boardOnLeft = !_boardOnLeft),
                          icon: const Icon(Icons.swap_horiz),
                        ),
                      ),
                      _boardOnLeft ? actionPanel : boardPanel,
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 9, 2, 4),
                  child: widget.header,
                ),
                if (widget.boardFooter != null) widget.boardFooter!,
                ...widget.details,
              ],
            ),
          );
        }
        final panelHeight = math.min(
          screen.maxHeight * .36,
          (screen.maxHeight * .28).clamp(76.0, 230.0),
        );
        return Column(
          key: const ValueKey('neon-live-game-layout'),
          children: [
            if (widget.compactPortraitArena)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: widget.arena,
              )
            else
              SizedBox(height: panelHeight, child: widget.arena),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 4),
              child: widget.header,
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
                    key: widget.portraitScrollKey,
                    controller: widget.scrollController,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    children: [
                      SizedBox(
                        height: extent,
                        child: Center(
                          child: SizedBox.square(
                            dimension: extent,
                            child: widget.board,
                          ),
                        ),
                      ),
                      if (widget.quickActions != null) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          key: const ValueKey('neon-live-quick-actions'),
                          height: actionsHeight,
                          child: widget.quickActions,
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (widget.boardFooter != null) widget.boardFooter!,
                      ...widget.details,
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Compact clocks and status use the existing match's values, without owning
/// timers. Their values remain readable in portrait and landscape layouts.
class NeonLiveStatusBar extends StatelessWidget {
  const NeonLiveStatusBar({
    required this.status,
    required this.whiteTime,
    required this.blackTime,
    required this.turn,
    required this.timed,
    super.key,
  });

  final String status;
  final Duration whiteTime, blackTime;
  final Side turn;
  final bool timed;

  String _format(Duration time) => !timed
      ? '--:--'
      : time.inHours > 0
      ? '${time.inHours}h ${(time.inMinutes % 60).toString().padLeft(2, '0')}m'
      : '${time.inMinutes.toString().padLeft(2, '0')}:${(time.inSeconds % 60).toString().padLeft(2, '0')}';

  Widget _clock(Side side, Duration time) => Expanded(
    child: Semantics(
      label: '${side.name} ${timed ? _format(time) : 'untimed'}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: turn == side ? const Color(0xFF233D4A) : Colors.white10,
          borderRadius: BorderRadius.circular(6),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                side.name.toUpperCase(),
                style: const TextStyle(fontSize: 10),
              ),
              const SizedBox(width: 8),
              Text(
                _format(time),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          _clock(Side.white, whiteTime),
          const SizedBox(width: 8),
          _clock(Side.black, blackTime),
        ],
      ),
      const SizedBox(height: 3),
      Text(
        status,
        key: const ValueKey('neon-live-game-status'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF83F8EF),
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
