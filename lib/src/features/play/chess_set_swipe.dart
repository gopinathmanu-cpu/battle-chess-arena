// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// A deliberate horizontal swipe changes art, never the chess position.
/// Vertical scrolling and ordinary square taps retain their own recognizers.
class ChessSetSwipe extends StatefulWidget {
  const ChessSetSwipe({required this.child, this.onChange, super.key});
  final Widget child;
  final ValueChanged<int>? onChange;
  @override
  State<ChessSetSwipe> createState() => _ChessSetSwipeState();
}

class _ChessSetSwipeState extends State<ChessSetSwipe> {
  double _distance = 0;
  @override
  Widget build(BuildContext context) => Semantics(
    customSemanticsActions: widget.onChange == null
        ? null
        : {
            const CustomSemanticsAction(label: 'Next chess set'): () =>
                widget.onChange!(1),
            const CustomSemanticsAction(label: 'Previous chess set'): () =>
                widget.onChange!(-1),
          },
    child: GestureDetector(
      onHorizontalDragStart: widget.onChange == null
          ? null
          : (_) => _distance = 0,
      onHorizontalDragUpdate: widget.onChange == null
          ? null
          : (event) => _distance += event.delta.dx,
      onHorizontalDragCancel: widget.onChange == null
          ? null
          : () => _distance = 0,
      onHorizontalDragEnd: widget.onChange == null
          ? null
          : (_) {
              if (_distance.abs() >= 48) {
                widget.onChange!(_distance < 0 ? 1 : -1);
              }
              _distance = 0;
            },
      child: widget.child,
    ),
  );
}
