// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/game_display_settings.dart';
import '../../widgets/color_range_picker.dart';

/// Compact alternating-square mark used for board-only colour actions.
class ChessboardPaintIcon extends StatelessWidget {
  const ChessboardPaintIcon({this.active = false, this.size = 26, super.key});

  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final filled = active ? const Color(0xFF24C7B1) : const Color(0xFF6C8EFF);
    final open = active ? const Color(0xFFFFD166) : const Color(0xFFE9C46A);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .08),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .18),
        border: Border.all(color: filled, width: 1.4),
      ),
      child: CustomPaint(
        painter: _CheckerIconPainter(light: open, dark: filled),
      ),
    );
  }
}

class BoardColorSettingsSection extends StatelessWidget {
  const BoardColorSettingsSection({required this.display, super.key});

  final GameDisplaySettings display;

  Future<void> _choose(BuildContext context) async {
    final colours = await showDialog<(Color, Color)>(
      context: context,
      builder: (_) => _BoardColorsDialog(
        initialLight: display.boardLightSquare,
        initialDark: display.boardDarkSquare,
      ),
    );
    if (colours != null) {
      unawaited(display.setBoardColors(colours.$1, colours.$2));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SwitchListTile(
        key: const ValueKey('custom-board-colors-toggle'),
        secondary: ChessboardPaintIcon(
          active: display.customBoardColorsEnabled,
        ),
        title: const Text('Use my chessboard colours'),
        subtitle: const Text(
          'Change only the board squares. Pieces and world stay unchanged.',
        ),
        value: display.customBoardColorsEnabled,
        onChanged: (_) => unawaited(display.toggleBoardColors()),
      ),
      ListTile(
        key: const ValueKey('choose-board-colors'),
        leading: _TwoColourSwatch(
          light: display.boardLightSquare,
          dark: display.boardDarkSquare,
        ),
        title: const Text('Choose board colours'),
        subtitle: const Text('Light squares and dark squares'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _choose(context),
      ),
    ],
  );
}

class _BoardColorsDialog extends StatefulWidget {
  const _BoardColorsDialog({
    required this.initialLight,
    required this.initialDark,
  });

  final Color initialLight;
  final Color initialDark;

  @override
  State<_BoardColorsDialog> createState() => _BoardColorsDialogState();
}

class _BoardColorsDialogState extends State<_BoardColorsDialog> {
  late Color _light = widget.initialLight;
  late Color _dark = widget.initialDark;

  static const _palettes = <(String, Color, Color)>[
    ('Sunlit teal', Color(0xFFFFE7B8), Color(0xFF28766E)),
    ('Royal berry', Color(0xFFFFE0EA), Color(0xFF70406F)),
    ('Ocean blue', Color(0xFFE0F4FF), Color(0xFF28668A)),
    ('Emerald', Color(0xFFE9F5C8), Color(0xFF347052)),
    ('Warm walnut', Color(0xFFFFE1AE), Color(0xFF815035)),
    ('Tournament', Color(0xFFF4F4F4), Color(0xFF4B5965)),
  ];

  bool get _readable =>
      _light.computeLuminance() - _dark.computeLuminance() >= .20;

  Future<void> _pick({required bool light}) async {
    final selected = await showDialog<Color>(
      context: context,
      builder: (_) => _ColourPickerDialog(
        label: light ? 'Light squares' : 'Dark squares',
        initial: light ? _light : _dark,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (light) {
        _light = selected;
      } else {
        _dark = selected;
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Row(
      children: [
        ChessboardPaintIcon(active: true),
        SizedBox(width: 12),
        Expanded(child: Text('Chessboard colours')),
      ],
    ),
    scrollable: true,
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BoardPreview(light: _light, dark: _dark),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (name, light, dark) in _palettes)
                ChoiceChip(
                  label: Text(name),
                  avatar: _TwoColourSwatch(light: light, dark: dark, size: 22),
                  selected: _light == light && _dark == dark,
                  onSelected: (_) => setState(() {
                    _light = light;
                    _dark = dark;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _ColourPickerButton(
            key: const ValueKey('light-square-color-picker'),
            label: 'Light squares',
            colour: _light,
            onTap: () => _pick(light: true),
          ),
          const SizedBox(height: 8),
          _ColourPickerButton(
            key: const ValueKey('dark-square-color-picker'),
            label: 'Dark squares',
            colour: _dark,
            onTap: () => _pick(light: false),
          ),
          if (!_readable)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Choose a brighter light colour and a darker second colour so pieces remain easy to identify.',
                style: TextStyle(color: Color(0xFFFFC66D)),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('apply-board-colors'),
        onPressed: _readable
            ? () => Navigator.pop(context, (_light, _dark))
            : null,
        child: const Text('Apply colours'),
      ),
    ],
  );
}

class _BoardPreview extends StatelessWidget {
  const _BoardPreview({required this.light, required this.dark});

  final Color light;
  final Color dark;

  @override
  Widget build(BuildContext context) => Center(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: 152,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
          ),
          itemCount: 64,
          itemBuilder: (_, index) =>
              ColoredBox(color: ((index ~/ 8) + index) % 2 == 0 ? light : dark),
        ),
      ),
    ),
  );
}

class _ColourPickerButton extends StatelessWidget {
  const _ColourPickerButton({
    required this.label,
    required this.colour,
    required this.onTap,
    super.key,
  });

  final String label;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    ),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white54),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        const Icon(Icons.palette_rounded, size: 20, color: Color(0xFFFF8A65)),
      ],
    ),
  );
}

class _CheckerIconPainter extends CustomPainter {
  const _CheckerIconPainter({required this.light, required this.dark});
  final Color light;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    final squareWidth = size.width / 4;
    final squareHeight = size.height / 4;
    for (var row = 0; row < 4; row++) {
      for (var column = 0; column < 4; column++) {
        canvas.drawRect(
          Rect.fromLTWH(
            column * squareWidth,
            row * squareHeight,
            squareWidth,
            squareHeight,
          ),
          Paint()..color = (row + column).isEven ? light : dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerIconPainter oldDelegate) =>
      oldDelegate.light != light || oldDelegate.dark != dark;
}

class _ColourPickerDialog extends StatefulWidget {
  const _ColourPickerDialog({required this.label, required this.initial});

  final String label;
  final Color initial;

  @override
  State<_ColourPickerDialog> createState() => _ColourPickerDialogState();
}

class _ColourPickerDialogState extends State<_ColourPickerDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);

  Color get _colour => _hsv.toColor().withValues(alpha: 1);

  void _update(HSVColor value) => setState(() => _hsv = value);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.label),
    scrollable: true,
    content: SizedBox(
      width: 330,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 62,
            decoration: BoxDecoration(
              color: _colour,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white54),
            ),
          ),
          const SizedBox(height: 12),
          ColorRangePicker(
            key: const ValueKey('board-color-range-picker'),
            value: _hsv,
            onChanged: _update,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _colour),
        child: const Text('Use colour'),
      ),
    ],
  );
}

class _TwoColourSwatch extends StatelessWidget {
  const _TwoColourSwatch({
    required this.light,
    required this.dark,
    this.size = 34,
  });

  final Color light;
  final Color dark;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(7),
    child: SizedBox.square(
      dimension: size,
      child: Row(
        children: [
          Expanded(
            child: ColoredBox(color: light, child: const SizedBox.expand()),
          ),
          Expanded(
            child: ColoredBox(color: dark, child: const SizedBox.expand()),
          ),
        ],
      ),
    ),
  );
}
