// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../domain/custom_avatar.dart';
import 'custom_avatar_portrait.dart';

/// Returns an appearance ID to the profile form; it never saves the profile.
class CustomAvatarBuilderScreen extends StatefulWidget {
  const CustomAvatarBuilderScreen({this.initialDesign, super.key});

  final CustomAvatarDesign? initialDesign;

  @override
  State<CustomAvatarBuilderScreen> createState() =>
      _CustomAvatarBuilderScreenState();
}

enum _AvatarSection { face, hair, facialHair, glasses, style }

class _CustomAvatarBuilderScreenState extends State<CustomAvatarBuilderScreen> {
  late final _initial = widget.initialDesign ?? const CustomAvatarDesign();
  late CustomAvatarDesign _design = _initial;
  final _optionsScroll = ScrollController();
  _AvatarSection _section = _AvatarSection.face;
  bool _allowPop = false;
  bool _closing = false;
  bool get _dirty => _design != _initial;

  @override
  void dispose() {
    _optionsScroll.dispose();
    super.dispose();
  }

  void _update(CustomAvatarDesign design) => setState(() => _design = design);

  Future<void> _finish([String? avatarId]) async {
    if (_closing) return;
    setState(() {
      _allowPop = true;
      _closing = true;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(avatarId);
  }

  Future<void> _cancel() async {
    if (_closing) return;
    if (!_dirty) return _finish();
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard avatar changes?'),
        content: const Text('Your profile avatar has not changed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep creating'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) await _finish();
  }

  Future<void> _reset() async {
    final reset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset this avatar?'),
        content: const Text(
          'Start again with the default avatar. Your profile will not change until you save it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep creating'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset avatar'),
          ),
        ],
      ),
    );
    if (reset == true && mounted) _update(const CustomAvatarDesign());
  }

  void _selectSection(_AvatarSection section) {
    if (_section == section) return;
    if (_optionsScroll.hasClients) _optionsScroll.jumpTo(0);
    setState(() => _section = section);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || !_dirty,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _cancel();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _cancel),
        title: const Text('Avatar Studio'),
        actions: [
          IconButton(
            key: const ValueKey('avatar-reset'),
            onPressed: _closing ? null : _reset,
            tooltip: 'Reset avatar',
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: FilledButton.icon(
            key: const ValueKey('use-custom-avatar'),
            onPressed: _closing ? null : () => _finish(_design.avatarId),
            icon: const Icon(Icons.check_circle_outline),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Use this avatar'),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth >= 700 ||
              (constraints.maxWidth >= 560 &&
                  constraints.maxWidth > constraints.maxHeight * 1.5);
          final controls = Column(
            children: [
              _SectionPicker(selected: _section, onSelected: _selectSection),
              Expanded(
                child: ListView(
                  key: const ValueKey('avatar-options-scroll'),
                  controller: _optionsScroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: _controls(),
                ),
              ),
            ],
          );
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: constraints.maxWidth < 700 ? 220 : 260,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 0, 16),
                    child: _PreviewPanel(design: _design, vertical: true),
                  ),
                ),
                Expanded(child: controls),
              ],
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: _PreviewPanel(design: _design),
              ),
              Expanded(child: controls),
            ],
          );
        },
      ),
    ),
  );

  List<Widget> _controls() => switch (_section) {
    _AvatarSection.face => _faceControls(),
    _AvatarSection.hair => _hairControls(),
    _AvatarSection.facialHair => _facialHairControls(),
    _AvatarSection.glasses => _glassesControls(),
    _AvatarSection.style => _styleControls(),
  };

  List<Widget> _faceControls() => [
    const _Heading('Start with a look'),
    _AvatarGrid(
      preferredColumns: 4,
      children: [
        for (final (name, presentation, age, hair) in [
          ('Man', 0, 2, 2),
          ('Woman', 1, 2, 7),
          ('Boy', 0, 0, 3),
          ('Girl', 1, 0, 11),
        ])
          _PortraitOption(
            key: ValueKey('avatar-starter-${name.toLowerCase()}'),
            label: name,
            design: _design.copyWith(
              presentation: presentation,
              age: age,
              hairStyle: hair,
              beard: 0,
              moustache: 0,
            ),
            selected:
                _design.presentation == presentation &&
                _design.age == age &&
                _design.hairStyle == hair &&
                _design.beard == 0 &&
                _design.moustache == 0,
            small: true,
            onTap: () => _update(
              _design.copyWith(
                presentation: presentation,
                age: age,
                hairStyle: hair,
                beard: 0,
                moustache: 0,
              ),
            ),
          ),
      ],
    ),
    const SizedBox(height: 12),
    Text(
      MediaQuery.textScalerOf(context).scale(14) > 23
          ? 'Save your profile to keep this avatar.'
          : 'Every starting look can be customised.',
      style: const TextStyle(fontSize: 12, color: Colors.white60),
    ),
    const SizedBox(height: 22),
    const _Heading('Face style'),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < CustomAvatarDesign.presentationLabels.length; i++)
          ChoiceChip(
            key: ValueKey('avatar-presentation-$i'),
            label: Text(CustomAvatarDesign.presentationLabels[i]),
            selected: _design.presentation == i,
            onSelected: (_) => _update(_design.copyWith(presentation: i)),
          ),
      ],
    ),
    const SizedBox(height: 22),
    const _Heading('Age'),
    _options(
      category: 'age',
      labels: CustomAvatarDesign.ageLabels,
      selected: _design.age,
      design: (i) => _design.copyWith(age: i),
      preferredColumns: 4,
    ),
    const SizedBox(height: 22),
    const _Heading('Face shape'),
    _options(
      category: 'face',
      labels: CustomAvatarDesign.faceLabels,
      selected: _design.face,
      design: (i) => _design.copyWith(face: i),
      preferredColumns: 4,
    ),
    const SizedBox(height: 22),
    _ColourOptions(
      category: 'skin',
      title: 'Skin tone',
      colors: CustomAvatarPortrait.skinTones,
      labels: CustomAvatarDesign.skinToneLabels,
      selected: _design.skinTone,
      onSelected: (i) => _update(_design.copyWith(skinTone: i)),
    ),
  ];

  List<Widget> _hairControls() => [
    const _Heading('Hairstyle'),
    _options(
      category: 'hair',
      labels: CustomAvatarDesign.hairStyleLabels,
      selected: _design.hairStyle,
      design: (i) => _design.copyWith(hairStyle: i),
    ),
    const SizedBox(height: 22),
    _ColourOptions(
      category: 'hair-colour',
      title: 'Hair colour',
      colors: CustomAvatarPortrait.hairColors,
      labels: CustomAvatarDesign.hairColorLabels,
      selected: _design.hairColor,
      onSelected: (i) => _update(_design.copyWith(hairColor: i)),
    ),
  ];

  List<Widget> _facialHairControls() => [
    const _Heading('Moustache'),
    _options(
      category: 'moustache',
      labels: CustomAvatarDesign.moustacheLabels,
      selected: _design.moustache,
      design: (i) => _design.copyWith(moustache: i),
    ),
    const SizedBox(height: 22),
    const _Heading('Beard'),
    _options(
      category: 'beard',
      labels: CustomAvatarDesign.beardLabels,
      selected: _design.beard,
      design: (i) => _design.copyWith(beard: i),
    ),
    const SizedBox(height: 16),
    const Text(
      'Facial hair follows your chosen hair colour.',
      style: TextStyle(color: Colors.white60),
    ),
  ];

  List<Widget> _glassesControls() => [
    const _Heading('Glasses & shades'),
    _options(
      category: 'glasses',
      labels: CustomAvatarDesign.eyewearLabels,
      selected: _design.eyewear,
      design: (i) => _design.copyWith(eyewear: i),
    ),
  ];

  List<Widget> _styleControls() => [
    const _Heading('Outfit'),
    _options(
      category: 'outfit',
      labels: CustomAvatarDesign.outfitLabels,
      selected: _design.outfit,
      design: (i) => _design.copyWith(outfit: i),
    ),
    const SizedBox(height: 22),
    _ColourOptions(
      category: 'outfit-colour',
      title: 'Outfit colour',
      colors: CustomAvatarPortrait.outfitColors,
      labels: CustomAvatarDesign.outfitColorLabels,
      selected: _design.outfitColor,
      onSelected: (i) => _update(_design.copyWith(outfitColor: i)),
    ),
    const SizedBox(height: 22),
    _ColourOptions(
      category: 'background',
      title: 'Background',
      colors: CustomAvatarPortrait.backgroundColors,
      labels: CustomAvatarDesign.backgroundLabels,
      selected: _design.background,
      onSelected: (i) => _update(_design.copyWith(background: i)),
    ),
  ];

  Widget _options({
    required String category,
    required List<String> labels,
    required int selected,
    required CustomAvatarDesign Function(int) design,
    int preferredColumns = 3,
  }) => _AvatarGrid(
    preferredColumns: preferredColumns,
    children: [
      for (var i = 0; i < labels.length; i++)
        _PortraitOption(
          key: ValueKey('avatar-$category-$i'),
          label: labels[i],
          design: design(i),
          selected: selected == i,
          onTap: () => _update(design(i)),
        ),
    ],
  );
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.design, this.vertical = false});
  final CustomAvatarDesign design;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 23;
    final portrait = Semantics(
      image: true,
      label: 'Your avatar live preview',
      child: ExcludeSemantics(
        child: CustomAvatarPortrait(
          key: const ValueKey('custom-avatar-live-preview'),
          design: design,
          size: vertical
              ? 164
              : largeText
              ? 84
              : 106,
        ),
      ),
    );
    final description = Column(
      crossAxisAlignment: vertical
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Live preview',
          textAlign: vertical ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xffe1d8ff),
          ),
        ),
        if (!largeText) ...[
          const SizedBox(height: 6),
          Text(
            'Save your profile to keep this avatar.',
            textAlign: vertical ? TextAlign.center : TextAlign.start,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ],
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff2b2442), Color(0xff132d39)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xff746199).withValues(alpha: .5),
        ),
      ),
      child: vertical
          ? Column(
              children: [portrait, const SizedBox(height: 12), description],
            )
          : Row(
              children: [
                portrait,
                const SizedBox(width: 16),
                Expanded(child: description),
              ],
            ),
    );
  }
}

class _SectionPicker extends StatelessWidget {
  const _SectionPicker({required this.selected, required this.onSelected});
  final _AvatarSection selected;
  final ValueChanged<_AvatarSection> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('avatar-section-scroll'),
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(
      children: [
        for (final section in _AvatarSection.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              key: ValueKey('avatar-tab-${section.name}'),
              showCheckmark: false,
              selected: selected == section,
              onSelected: (_) => onSelected(section),
              avatar: Icon(switch (section) {
                _AvatarSection.face => Icons.face_outlined,
                _AvatarSection.hair => Icons.content_cut,
                _AvatarSection.facialHair => Icons.face_retouching_natural,
                _AvatarSection.glasses => Icons.visibility_outlined,
                _AvatarSection.style => Icons.palette_outlined,
              }, size: 18),
              label: Text(switch (section) {
                _AvatarSection.face => 'Face & age',
                _AvatarSection.hair => 'Hair',
                _AvatarSection.facialHair => 'Facial hair',
                _AvatarSection.glasses => 'Glasses',
                _AvatarSection.style => 'Style',
              }),
            ),
          ),
      ],
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _AvatarGrid extends StatelessWidget {
  const _AvatarGrid({required this.children, this.preferredColumns = 3});
  final List<Widget> children;
  final int preferredColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 23;
      final minWidth = largeText
          ? 130.0
          : preferredColumns == 4
          ? 78.0
          : 100.0;
      final columns = (constraints.maxWidth / (minWidth + 10)).floor().clamp(
        1,
        preferredColumns,
      );
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _PortraitOption extends StatelessWidget {
  const _PortraitOption({
    required this.label,
    required this.design,
    required this.selected,
    required this.onTap,
    this.small = false,
    super.key,
  });
  final String label;
  final CustomAvatarDesign design;
  final bool selected;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: label,
    excludeSemantics: true,
    onTap: onTap,
    child: Material(
      color: selected ? const Color(0xff332b48) : const Color(0xff1b1c2b),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white12,
              width: selected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            children: [
              ExcludeSemantics(
                child: CustomAvatarPortrait(
                  design: design,
                  size: small ? 58 : 72,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 16,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white38,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ColourOptions extends StatelessWidget {
  const _ColourOptions({
    required this.category,
    required this.title,
    required this.colors,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });
  final String category;
  final String title;
  final List<Color> colors;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Heading('$title · ${labels[selected]}'),
      _AvatarGrid(
        preferredColumns: 4,
        children: [
          for (var i = 0; i < colors.length; i++)
            Semantics(
              selected: selected == i,
              button: true,
              label: '$title: ${labels[i]}',
              excludeSemantics: true,
              onTap: () => onSelected(i),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: ValueKey('avatar-$category-$i'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelected(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colors[i],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected == i
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.white38,
                              width: selected == i ? 3 : 1,
                            ),
                          ),
                          child: selected == i
                              ? Icon(
                                  Icons.check,
                                  size: 24,
                                  color: colors[i].computeLuminance() > .45
                                      ? Colors.black87
                                      : Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          labels[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected == i
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );
}
