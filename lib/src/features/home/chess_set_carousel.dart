// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../domain/piece_pack.dart';
import '../../domain/custom_chess_set.dart';
import '../play/board_appearance.dart';
import '../play/chess_widgets.dart';

/// Real game artwork, in the starting position, with swipe and arrow selection.
class ChessSetCarousel extends StatefulWidget {
  const ChessSetCarousel({
    required this.pack,
    required this.classic,
    required this.style,
    required this.onChanged,
    this.themedPacks = availablePiecePacks,
    this.onDoubleTap,
    super.key,
  });

  final PiecePack pack;
  final bool classic;
  final ClassicPieceStyle style;
  final List<PiecePack> themedPacks;

  /// Animated selections use the global catalogue index, even when filtered.
  /// Classic selections use the classic-style index.
  final ValueChanged<int> onChanged;
  final VoidCallback? onDoubleTap;

  int get selectedIndex => classic
      ? ClassicPieceStyle.values.indexOf(style)
      : themedPacks.indexWhere((item) => item.id == pack.id);
  int get count =>
      classic ? ClassicPieceStyle.values.length : themedPacks.length;

  @override
  State<ChessSetCarousel> createState() => _ChessSetCarouselState();
}

class _ChessSetCarouselState extends State<ChessSetCarousel> {
  late PageController _pages;
  bool _synchronizing = false;

  @override
  void initState() {
    super.initState();
    _pages = PageController(initialPage: widget.selectedIndex);
  }

  @override
  void didUpdateWidget(ChessSetCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // External changes (restored preferences or switching families) must not
    // leave the board preview on a different set from the new-game selection.
    if (oldWidget.classic != widget.classic ||
        oldWidget.selectedIndex != widget.selectedIndex) {
      if (_pages.hasClients && _pages.page!.round() != widget.selectedIndex) {
        _synchronizing = true;
        _pages.jumpToPage(widget.selectedIndex);
        _synchronizing = false;
      }
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _move(int delta) {
    // Wrap at either end so every set remains one continuous carousel.
    final target = (widget.selectedIndex + delta) % widget.count;
    if ((target - widget.selectedIndex).abs() > 1) {
      _pages.jumpToPage(target);
      return;
    }
    _pages.animateToPage(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.classic ? widget.style.label : widget.pack.name;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          key: const ValueKey('home-board-preview'),
          aspectRatio: 1,
          child: GestureDetector(
            key: const ValueKey('home-board-double-tap-target'),
            behavior: HitTestBehavior.opaque,
            onDoubleTap: widget.onDoubleTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  key: const ValueKey('chess-set-carousel'),
                  controller: _pages,
                  itemCount: widget.count,
                  onPageChanged: (index) {
                    if (_synchronizing) return;
                    widget.onChanged(
                      widget.classic
                          ? index
                          : piecePacks.indexWhere(
                              (pack) => pack.id == widget.themedPacks[index].id,
                            ),
                    );
                  },
                  itemBuilder: (context, index) {
                    final pack = widget.classic
                        ? widget.pack
                        : widget.themedPacks[index];
                    var appearance = BoardAppearance(
                      white: pack,
                      black: pack,
                      board: pack,
                      animatedArena: !widget.classic,
                    );
                    final label = widget.classic
                        ? ClassicPieceStyle.values[index].label
                        : pack.name;
                    if (widget.classic) {
                      appearance = appearance.withStandardPieces(
                        ClassicPieceStyle.values[index],
                      );
                    }
                    return Center(
                      child: Semantics(
                        image: true,
                        button: widget.onDoubleTap != null,
                        onTap: widget.onDoubleTap,
                        label:
                            '$label chess set, full board with white and black pieces${widget.onDoubleTap == null ? '' : ', double tap to play computer'}',
                        child: ExcludeSemantics(
                          child: IgnorePointer(
                            child: RepaintBoundary(
                              child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF151725),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: pack.accent.withValues(alpha: .6),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: MediaQuery.removePadding(
                                    context: context,
                                    removeTop: true,
                                    removeBottom: true,
                                    child: PrimaryScrollController.none(
                                      child: ChessBoard(
                                        position: Chess.initial,
                                        selected: null,
                                        legalTargets: const {},
                                        accent: pack.accent,
                                        appearance: appearance,
                                        showPieceRoles: false,
                                        onSquareTap: (_) {},
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (widget.onDoubleTap != null)
                  const Center(child: QuickComputerGameHint()),
              ],
            ),
          ),
        ),
        Row(
          children: [
            IconButton.filledTonal(
              key: const ValueKey('previous-chess-set'),
              tooltip: 'Previous chess set',
              onPressed: () => _move(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Column(
                  children: [
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${widget.selectedIndex + 1} / ${widget.count} · Swipe to choose',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton.filledTonal(
              key: const ValueKey('next-chess-set'),
              tooltip: 'Next chess set',
              onPressed: () => _move(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}

class CustomChessSetCarousel extends StatefulWidget {
  const CustomChessSetCarousel({
    required this.sets,
    required this.active,
    required this.basePack,
    required this.onChanged,
    this.onDoubleTap,
    super.key,
  });

  final List<CustomChessSet> sets;
  final CustomChessSet active;
  final PiecePack basePack;
  final ValueChanged<CustomChessSet> onChanged;
  final VoidCallback? onDoubleTap;

  int get selectedIndex => sets.indexWhere((set) => set.id == active.id);

  @override
  State<CustomChessSetCarousel> createState() => _CustomChessSetCarouselState();
}

class _CustomChessSetCarouselState extends State<CustomChessSetCarousel> {
  late PageController _pages;
  bool _synchronizing = false;

  int get _index => widget.selectedIndex.clamp(0, widget.sets.length - 1);

  @override
  void initState() {
    super.initState();
    _pages = PageController(initialPage: _index);
  }

  @override
  void didUpdateWidget(CustomChessSetCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.active.id != widget.active.id ||
            oldWidget.sets.length != widget.sets.length) &&
        _pages.hasClients &&
        _pages.page?.round() != _index) {
      _synchronizing = true;
      _pages.jumpToPage(_index);
      _synchronizing = false;
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _move(int delta) {
    final target = (_index + delta) % widget.sets.length;
    if ((target - _index).abs() > 1) {
      _pages.jumpToPage(target);
    } else {
      _pages.animateToPage(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AspectRatio(
        key: const ValueKey('home-custom-board-preview'),
        aspectRatio: 1,
        child: GestureDetector(
          key: const ValueKey('home-custom-board-double-tap-target'),
          behavior: HitTestBehavior.opaque,
          onDoubleTap: widget.onDoubleTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                key: const ValueKey('my-themes-carousel'),
                controller: _pages,
                itemCount: widget.sets.length,
                onPageChanged: (page) {
                  if (!_synchronizing) widget.onChanged(widget.sets[page]);
                },
                itemBuilder: (context, page) {
                  final custom = widget.sets[page];
                  final appearance = BoardAppearance.forPack(
                    widget.basePack,
                  ).withCustomSet(custom);
                  return Semantics(
                    image: true,
                    button: widget.onDoubleTap != null,
                    onTap: widget.onDoubleTap,
                    label:
                        '${custom.name} custom chess set, full board${widget.onDoubleTap == null ? '' : ', double tap to play computer'}',
                    child: ExcludeSemantics(
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF151725),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Color(
                                  custom.whiteAccent,
                                ).withValues(alpha: .7),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: ChessBoard(
                                position: Chess.initial,
                                selected: null,
                                legalTargets: const {},
                                accent: Color(custom.whiteAccent),
                                appearance: appearance,
                                showPieceRoles: false,
                                onSquareTap: (_) {},
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (widget.onDoubleTap != null)
                const Center(child: QuickComputerGameHint()),
            ],
          ),
        ),
      ),
      Row(
        children: [
          IconButton.filledTonal(
            key: const ValueKey('previous-custom-chess-set'),
            tooltip: 'Previous custom chess set',
            onPressed: () => _move(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.active.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${_index + 1} / ${widget.sets.length} · Swipe to choose',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            key: const ValueKey('next-custom-chess-set'),
            tooltip: 'Next custom chess set',
            onPressed: () => _move(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    ],
  );
}

class QuickComputerGameHint extends StatelessWidget {
  const QuickComputerGameHint({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: Container(
        key: const ValueKey('quick-computer-game-hint'),
        constraints: const BoxConstraints(maxWidth: 230),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF11131F).withValues(alpha: .68),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .2)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scroll left or right to select chess set',
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                height: 1.15,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Double click to start quick game with computer',
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                height: 1.15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
