// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import '../../domain/online_player_profile.dart';
import '../../domain/custom_avatar.dart';
import 'avatar_portrait_regions.dart';
import 'custom_avatar_builder_screen.dart';
import 'custom_avatar_portrait.dart';

class OnlineAvatarImage extends StatelessWidget {
  const OnlineAvatarImage({required this.avatarId, this.size = 44, super.key});

  static const atlas = 'assets/avatars/human-face-atlas-v2.png';
  static const botAtlas = 'assets/avatars/bot-personality-atlas.png';

  final String avatarId;
  final double size;

  int? get botAvatarIndex {
    final index = builtInComputerOpponents.indexWhere(
      (opponent) => opponent.avatarId == avatarId,
    );
    return index < 0 ? null : index;
  }

  int get avatarIndex {
    final generated = RegExp(r'^avatar-(\d{2})$').firstMatch(avatarId);
    if (generated != null) {
      final index = int.parse(generated.group(1)!) - 1;
      if (index >= 0 && index < 50) return index;
    }
    final botIndex = botAvatarIndex;
    if (botIndex != null) return botIndex;
    const legacy = [
      'crown',
      'knight',
      'mage',
      'dragon',
      'robot',
      'ranger',
      'sun',
      'moon',
    ];
    final legacyIndex = legacy.indexOf(avatarId);
    return legacyIndex < 0 ? 0 : legacyIndex;
  }

  @override
  Widget build(BuildContext context) {
    final custom = CustomAvatarDesign.tryParse(avatarId);
    if (custom != null) {
      return CustomAvatarPortrait(design: custom, size: size);
    }
    final botIndex = botAvatarIndex;
    final index = botIndex ?? avatarIndex;
    final isBot = botIndex != null;
    final atlasAsset = isBot ? botAtlas : atlas;
    final source = (isBot ? botPortraitRegions : humanPortraitRegions)[index];
    final bot = isBot ? builtInComputerOpponents[index] : null;
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: bot == null
          ? 'Avatar ${index + 1} portrait'
          : '${bot.name} computer avatar portrait',
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.surfaceContainerHighest,
          border: Border.all(color: colorScheme.primary.withValues(alpha: .7)),
        ),
        child: ClipOval(
          child: AvatarPortrait(asset: atlasAsset, source: source),
        ),
      ),
    );
  }
}

/// Resolves the atlas through Flutter's image cache, then paints only one
/// measured portrait. No oversized widget or neighbouring cell is laid out.
class AvatarPortrait extends StatefulWidget {
  const AvatarPortrait({required this.asset, required this.source, super.key});
  final String asset;
  final Rect source;

  @override
  State<AvatarPortrait> createState() => _AvatarPortraitState();
}

class _AvatarPortraitState extends State<AvatarPortrait> {
  ImageStream? _stream;
  ImageInfo? _image;
  late final _listener = ImageStreamListener(
    (image, _) {
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = image;
      });
    },
    onError: (Object error, StackTrace? stack) {
      if (mounted) {
        setState(() {
          _image?.dispose();
          _image = null;
        });
      }
    },
  );

  void _resolve() {
    final stream = AssetImage(
      widget.asset,
    ).resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    _stream?.removeListener(_listener);
    _image?.dispose();
    _image = null;
    _stream = stream..addListener(_listener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(AvatarPortrait oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) _resolve();
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _image == null
      ? const Icon(Icons.person_outline)
      : CustomPaint(
          painter: AvatarPortraitPainter(_image!.image, widget.source),
        );
}

class AvatarPortraitPainter extends CustomPainter {
  const AvatarPortraitPainter(this.image, this.source);
  final ui.Image image;
  final Rect source;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      source,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(AvatarPortraitPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.source != source;
}

class OnlineAvatarPicker extends StatelessWidget {
  const OnlineAvatarPicker({
    required this.selectedId,
    required this.onSelected,
    this.height = 420,
    super.key,
  });

  final String selectedId;
  final ValueChanged<String> onSelected;
  final double height;

  Future<void> _createAvatar(BuildContext context) async {
    final avatar = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CustomAvatarBuilderScreen(
          initialDesign: CustomAvatarDesign.tryParse(selectedId),
        ),
      ),
    );
    if (avatar != null && context.mounted) onSelected(avatar);
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      OnlineAvatarImage(
        key: const ValueKey('selected-avatar-preview'),
        avatarId: selectedId,
        size: 120,
      ),
      const SizedBox(height: 8),
      Text(
        CustomAvatarDesign.tryParse(selectedId) == null
            ? 'Selected portrait'
            : 'Your custom avatar',
      ),
      const SizedBox(height: 12),
      FilledButton.tonalIcon(
        key: const ValueKey('create-custom-avatar'),
        onPressed: () => _createAvatar(context),
        icon: const Icon(Icons.face_retouching_natural),
        label: Text(
          CustomAvatarDesign.tryParse(selectedId) == null
              ? 'Create your avatar'
              : 'Edit your avatar',
        ),
      ),
      const SizedBox(height: 12),
      const Text('Or choose a portrait'),
      const SizedBox(height: 12),
      SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) => GridView.builder(
            key: const ValueKey('human-avatar-picker'),
            padding: const EdgeInsets.all(4),
            itemCount: onlineAvatarChoices.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: (constraints.maxWidth / 100).floor().clamp(2, 6),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final avatar = onlineAvatarChoices[index];
              final selected = selectedId == avatar.id;
              return Semantics(
                label: avatar.label,
                selected: selected,
                button: true,
                child: Tooltip(
                  message: avatar.label,
                  child: InkWell(
                    key: ValueKey('avatar-${avatar.id}'),
                    onTap: () => onSelected(avatar.id),
                    customBorder: const CircleBorder(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: .18)
                            : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: OnlineAvatarImage(avatarId: avatar.id, size: 96),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}
