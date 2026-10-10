// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dartchess/dartchess.dart';

import '../../services/game_display_settings.dart';
import '../../services/app_color_scheme_controller.dart';
import '../../services/app_icon_controller.dart';
import '../../services/theme_music.dart';
import '../../services/custom_set_actions.dart';
import '../credits/gold_credit_coin.dart';
import '../credits/arena_credit_header.dart';
import '../credits/credit_rules_sheet.dart';
import '../../services/arena_credit_controller.dart';
import '../profile/preferred_name.dart';
import '../profile/online_profile_settings.dart';
import '../../domain/online_player_profile.dart';
import '../../domain/animated_army_theme.dart';
import '../../domain/piece_pack.dart';
import '../play/board_appearance.dart';
import 'board_color_settings.dart';

/// Settings stay off the play surface and only cover it after an explicit tap.
/// This sheet scrolls independently and never pauses or mutates a match.
Future<void> showGameSettings({
  required BuildContext context,
  required GameDisplaySettings display,
  required VoidCallback onCustomize,
  required List<Widget> Function(VoidCallback refresh) controls,
  Future<void> Function()? onReset,
  bool inGame = true,
  ValueChanged<OnlinePlayerProfile>? onOnlineProfileChanged,
  Widget Function(VoidCallback refresh)? chessSetSelector,
}) {
  bool resetting = false;
  int resetRevision = 0;
  final creditWallet = ArenaCreditScope.maybeOf(context);
  final appColors = AppColorSchemeScope.maybeOf(context);
  final appIcons = AppIconController();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => ListenableBuilder(
        listenable: display,
        builder: (context, _) => SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Game settings',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close settings',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                      const ArenaCreditHeader(compact: true),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    key: const ValueKey('game-settings-list'),
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      if (inGame)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            'Timed games keep running while settings are open.',
                          ),
                        ),
                      const _SettingsSectionHeading(
                        icon: Icons.person_outline_rounded,
                        label: 'PROFILE & ONLINE',
                      ),
                      const PreferredNameSettingsTile(),
                      if (onOnlineProfileChanged != null)
                        OnlineProfileSettingsTile(
                          onChanged: onOnlineProfileChanged,
                        ),
                      const _SettingsSectionHeading(
                        icon: Icons.sports_esports_outlined,
                        label: 'GAMEPLAY & DISPLAY',
                      ),
                      SwitchListTile(
                        key: const ValueKey('show-captured-pieces-toggle'),
                        title: const Text('Show captured pieces'),
                        subtitle: Text(
                          display.error ??
                              'Show pieces taken by both players. Saved on this device.',
                        ),
                        value: display.showCapturedPieces,
                        onChanged: (value) =>
                            unawaited(display.setShowCapturedPieces(value)),
                        secondary: const Icon(Icons.view_module_outlined),
                      ),
                      const _SettingsSectionHeading(
                        icon: Icons.palette_outlined,
                        label: 'APPEARANCE',
                      ),
                      if (appColors != null)
                        ApplicationColorSchemePicker(controller: appColors),
                      AppIconPicker(controller: appIcons),
                      if (chessSetSelector != null)
                        chessSetSelector(() {
                          if (context.mounted && sheetContext.mounted) {
                            setSheetState(() {});
                          }
                        })
                      else
                        ListTile(
                          leading: const Icon(Icons.palette_outlined),
                          title: const Text('Chess set & theme'),
                          subtitle: Text(
                            inGame
                                ? 'Choose Classic or Animated pieces. Swipe the board left or right to switch between them.'
                                : 'Choose Animated armies or any Classic piece set',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            onCustomize();
                          },
                        ),
                      BoardColorSettingsSection(display: display),
                      const _SettingsSectionHeading(
                        icon: Icons.tune_rounded,
                        label: 'MATCH PREFERENCES',
                      ),
                      KeyedSubtree(
                        key: ValueKey(resetRevision),
                        child: Column(
                          children: controls(() {
                            if (context.mounted) setSheetState(() {});
                          }),
                        ),
                      ),
                      const _SettingsSectionHeading(
                        icon: Icons.music_note_outlined,
                        label: 'AUDIO',
                      ),
                      const ListTile(
                        leading: Icon(Icons.music_note_outlined),
                        title: Text('Theme music'),
                        trailing: MusicButton(),
                      ),
                      const BackgroundMusicPicker(),
                      const _SettingsSectionHeading(
                        icon: Icons.monetization_on_outlined,
                        label: 'CREDITS',
                      ),
                      ListTile(
                        key: const ValueKey('credit-rules-settings'),
                        leading: const GoldCreditCoin(size: 28),
                        title: const Text('How Credits Work'),
                        subtitle: const Text(
                          'See every cost, reward, free action and fairness rule.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showCreditRulesSheet(context),
                      ),
                      if (ArenaCreditController.testingCreditsEnabled &&
                          creditWallet != null)
                        ListenableBuilder(
                          listenable: creditWallet,
                          builder: (context, _) {
                            return ListTile(
                              key: const ValueKey('testing-credit-top-up'),
                              leading: const GoldCreditCoin(size: 28),
                              title: const Text('Top-up Credits'),
                              subtitle: Text(
                                '${creditWallet.credits} available · Enter a Beta Tester code.',
                              ),
                              trailing: FilledButton.tonal(
                                onPressed: () =>
                                    _showTestingTopUpDialog(context),
                                child: const Text('Top up'),
                              ),
                            );
                          },
                        ),
                      const _SettingsSectionHeading(
                        icon: Icons.restore_rounded,
                        label: 'RESET',
                      ),
                      ListTile(
                        key: const ValueKey('reset-settings'),
                        leading: const Icon(Icons.restore),
                        title: Text(
                          resetting
                              ? 'Resetting…'
                              : 'Reset settings to default',
                        ),
                        subtitle: const Text(
                          'Restore music, appearance and play preferences. Games and progress are kept.',
                        ),
                        enabled: !resetting,
                        onTap: resetting
                            ? null
                            : () async {
                                final music = MusicScope.of(context);
                                setSheetState(() => resetting = true);
                                try {
                                  await display.setShowCapturedPieces(true);
                                  await display.resetBoardColors();
                                  await appColors?.resetToDefault();
                                  await appIcons.resetToDefault();
                                  await music?.resetToDefaults();
                                  if (context.mounted &&
                                      !await restoreBuiltInChessSet(context)) {
                                    throw StateError(
                                      'Custom appearance could not be reset',
                                    );
                                  }
                                  await onReset?.call();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        display.error ??
                                            music?.saveError ??
                                            'Default settings restored. Games and progress kept.',
                                      ),
                                    ),
                                  );
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not save all settings. Please try resetting again.',
                                        ),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (context.mounted) {
                                    setSheetState(() {
                                      resetting = false;
                                      resetRevision++;
                                    });
                                  }
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ).whenComplete(appIcons.dispose);
}

/// Selecting a Classic set explicitly chooses the Classic page, even if the
/// Animated page currently uses Classic board icons after a swipe.
class ChessSetSelection {
  const ChessSetSelection({
    required this.animatedArena,
    required this.pack,
    required this.classicStyle,
  });

  final bool animatedArena;
  final PiecePack pack;
  final ClassicPieceStyle classicStyle;
}

class SettingsChessSetPicker extends StatelessWidget {
  const SettingsChessSetPicker({
    required this.animatedArena,
    required this.pack,
    required this.classicStyle,
    required this.onSelected,
    super.key,
  });

  final bool animatedArena;
  final PiecePack pack;
  final ClassicPieceStyle classicStyle;
  final ValueChanged<ChessSetSelection> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('settings-chess-set-picker'),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth > 10 ? (box.maxWidth - 10) / 2 : 0.0;
        Widget choices(bool animated) => Wrap(
          spacing: 10,
          runSpacing: 10,
          children: animated
              ? [
                  for (final choice in availablePiecePacks)
                    SizedBox(
                      width: width,
                      child: _ChessSetChoiceCard(
                        choiceKey: ValueKey(
                          'settings-animated-${choice.id.name}',
                        ),
                        label: AnimatedArmyTheme.forPack(
                          choice.id,
                        )!.displayName,
                        pack: choice,
                        style: classicStyle,
                        animated: true,
                        selected: animatedArena && choice.id == pack.id,
                        onTap: () => onSelected(
                          ChessSetSelection(
                            animatedArena: true,
                            pack: choice,
                            classicStyle: classicStyle,
                          ),
                        ),
                      ),
                    ),
                ]
              : [
                  for (final style in ClassicPieceStyle.values)
                    SizedBox(
                      width: width,
                      child: _ChessSetChoiceCard(
                        choiceKey: ValueKey('settings-classic-${style.name}'),
                        label: style.label,
                        pack: pack,
                        style: style,
                        animated: false,
                        selected: !animatedArena && classicStyle == style,
                        onTap: () => onSelected(
                          ChessSetSelection(
                            animatedArena: false,
                            pack: pack,
                            classicStyle: style,
                          ),
                        ),
                      ),
                    ),
                ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.style_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Chess set',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Classic sets use the traditional game page. Animated armies show character avatars and battles above the board.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Classic',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            choices(false),
            const SizedBox(height: 16),
            const Text(
              'Animated',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            choices(true),
            const SizedBox(height: 8),
            Text(
              'In an Animated game, swipe the board to change its pieces while keeping the animation.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    ),
  );
}

class _ChessSetChoiceCard extends StatelessWidget {
  const _ChessSetChoiceCard({
    required this.choiceKey,
    required this.label,
    required this.pack,
    required this.style,
    required this.animated,
    required this.selected,
    required this.onTap,
  });

  final Key choiceKey;
  final String label;
  final PiecePack pack;
  final ClassicPieceStyle style;
  final bool animated;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${animated ? 'Animated' : 'Classic'} set, $label',
      child: Material(
        color: selected ? colors.primaryContainer : colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: choiceKey,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7894AE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final side in Side.values)
                        SizedBox.square(
                          dimension: 38,
                          child: CharacterPiece(
                            piece: Piece(color: side, role: Role.knight),
                            pack: pack,
                            standard: !animated,
                            classicStyle: style,
                            showRole: false,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (selected) ...[
                      Icon(Icons.check_circle, size: 16, color: colors.primary),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSectionHeading extends StatelessWidget {
  const _SettingsSectionHeading({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
    child: Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ],
    ),
  );
}

class AppIconPicker extends StatelessWidget {
  const AppIconPicker({required this.controller, super.key});

  final AppIconController controller;

  Future<void> _showChoices(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (pickerContext) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose app icon',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose how Battle Chess Arena appears on your phone. The launcher may take a few seconds to refresh.',
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  for (final choice in AppIconChoice.values) ...[
                    Expanded(
                      child: _AppIconChoiceCard(
                        choice: choice,
                        selected: controller.choice == choice,
                        busy: controller.changing,
                        onTap: () async {
                          final changed = await controller.select(choice);
                          if (changed && pickerContext.mounted) {
                            Navigator.of(pickerContext).pop();
                          }
                        },
                      ),
                    ),
                    if (choice != AppIconChoice.values.last)
                      const SizedBox(width: 14),
                  ],
                ],
              ),
              if (controller.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  controller.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => ListTile(
      key: const ValueKey('app-icon-settings'),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.asset(controller.choice.asset, width: 42, height: 42),
      ),
      title: const Text('App icon'),
      subtitle: Text(
        controller.loading
            ? 'Loading…'
            : '${controller.choice.label} · Choose your launcher icon',
      ),
      trailing: const Icon(Icons.chevron_right),
      enabled: !controller.loading,
      onTap: controller.loading ? null : () => _showChoices(context),
    ),
  );
}

class _AppIconChoiceCard extends StatelessWidget {
  const _AppIconChoiceCard({
    required this.choice,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final AppIconChoice choice;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 2.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('app-icon-${choice.id}'),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(choice.asset, fit: BoxFit.cover),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[
                    Icon(Icons.check_circle, size: 18, color: colors.primary),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      choice.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ApplicationColorSchemePicker extends StatelessWidget {
  const ApplicationColorSchemePicker({required this.controller, super.key});

  final AppColorSchemeController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Padding(
      key: const ValueKey('application-color-scheme-picker'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.wallpaper_rounded),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Application background scheme',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            controller.error ??
                'Menus and buttons use your saved palette. Backgrounds can stay consistent or follow each chess set.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final mode in AppBackgroundMode.values) ...[
                Expanded(
                  child: _BackgroundModeCard(
                    mode: mode,
                    selected: controller.backgroundMode == mode,
                    onTap: () => controller.setBackgroundMode(mode),
                  ),
                ),
                if (mode != AppBackgroundMode.values.last)
                  const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            controller.backgroundMode == AppBackgroundMode.single
                ? 'Menus, buttons & background'
                : 'Menus & buttons',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Selected: ${controller.preset.label}',
            key: const ValueKey('selected-application-colour-scheme'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final preset in AppColorSchemePreset.values)
                    SizedBox(
                      width: width,
                      child: _BackgroundPresetCanvas(
                        preset: preset,
                        selected: controller.preset == preset,
                        onTap: () => controller.setPreset(preset),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _BackgroundModeCard extends StatelessWidget {
  const _BackgroundModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final AppBackgroundMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? Theme.of(context).colorScheme.primaryContainer
        : Colors.white.withValues(alpha: .05),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      key: ValueKey('application-background-${mode.name}'),
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          children: [
            Icon(
              mode == AppBackgroundMode.single
                  ? Icons.image_rounded
                  : Icons.auto_awesome_rounded,
            ),
            const SizedBox(height: 5),
            Text(
              mode.label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              mode.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _BackgroundPresetCanvas extends StatelessWidget {
  const _BackgroundPresetCanvas({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final AppColorSchemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      key: ValueKey('application-background-preset-${preset.name}'),
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        height: 92,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: preset.backgroundGradient,
          ),
          border: Border.all(
            color: selected ? Colors.white : Colors.white38,
            width: selected ? 3 : 1,
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              right: 10,
              top: 9,
              child: Icon(
                Icons.castle_rounded,
                color: Colors.white38,
                size: 30,
              ),
            ),
            Positioned(
              left: 10,
              right: 8,
              bottom: 9,
              child: Text(
                preset.label,
                maxLines: 2,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                ),
              ),
            ),
            if (selected)
              const Positioned(
                right: 7,
                bottom: 7,
                child: Icon(Icons.check_circle, color: Colors.white),
              ),
          ],
        ),
      ),
    ),
  );
}

/// A compact settings row backed by a checked-choice sheet instead of a
/// dropdown form field. This stays readable for both short and long catalogs.
class SettingsChoiceTile<T> extends StatelessWidget {
  const SettingsChoiceTile({
    required this.title,
    required this.value,
    required this.values,
    required this.optionLabel,
    required this.onSelected,
    this.icon = Icons.tune,
    this.supportingText,
    this.optionDescription,
    this.optionLeading,
    this.enabled = true,
    super.key,
  });

  final String title;
  final T value;
  final List<T> values;
  final String Function(T) optionLabel;
  final String Function(T)? optionDescription;
  final Widget Function(T)? optionLeading;
  final FutureOr<void> Function(T) onSelected;
  final IconData icon;
  final String? supportingText;
  final bool enabled;

  Future<void> _choose(BuildContext context) async {
    final selected = await showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (choiceContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(choiceContext).height * .7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(choiceContext).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(choiceContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                key: ValueKey('settings-choice-${title.toLowerCase()}'),
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  for (final choice in values)
                    ListTile(
                      selected: choice == value,
                      leading:
                          optionLeading?.call(choice) ??
                          Icon(
                            choice == value
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                          ),
                      title: Text(optionLabel(choice)),
                      subtitle: optionDescription == null
                          ? null
                          : Text(optionDescription!(choice)),
                      trailing: choice == value
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.pop(choiceContext, choice),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null && context.mounted) {
      await onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(
      [
        optionLabel(value),
        if (supportingText != null) supportingText!,
      ].join(' · '),
    ),
    trailing: const Icon(Icons.chevron_right),
    enabled: enabled,
    onTap: enabled ? () => _choose(context) : null,
  );
}

Future<void> _showTestingTopUpDialog(BuildContext context) async {
  final wallet = ArenaCreditScope.of(context);
  var topUpCode = '';
  String? error;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Top-up Credits'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x1FFFF3C4),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Beta Tester Top-up',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'If you are a Beta Tester, please use one of these codes:',
                      ),
                      SizedBox(height: 7),
                      _BetaTopUpCodeLine(
                        code: 'BETATESTSEP26',
                        validity: '(September 2026 only)',
                      ),
                      SizedBox(height: 3),
                      _BetaTopUpCodeLine(
                        code: 'BETATESTOCT26',
                        validity: '(October 2026 only)',
                      ),
                      SizedBox(height: 7),
                      Text(
                        'Beta Top-ups are limited to a 1,000-credit balance.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('credit-top-up-code-field'),
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Top-up code',
                  helperText: 'Enter the code for the applicable month.',
                  errorText: error,
                ),
                onChanged: (value) => topUpCode = value,
                onSubmitted: (_) {
                  if (wallet.redeemTestingTopUpCode(topUpCode)) {
                    Navigator.of(dialogContext).pop();
                  } else {
                    setDialogState(
                      () => error =
                          wallet.credits >=
                              ArenaCreditController.testingTopUpBalanceLimit
                          ? 'Beta Top-up limit reached (1,000 credits)'
                          : 'Invalid or inactive Top-up code',
                    );
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('redeem-credit-top-up-code'),
            onPressed: () {
              if (wallet.redeemTestingTopUpCode(topUpCode)) {
                Navigator.of(dialogContext).pop();
              } else {
                setDialogState(
                  () => error =
                      wallet.credits >=
                          ArenaCreditController.testingTopUpBalanceLimit
                      ? 'Beta Top-up limit reached (1,000 credits)'
                      : 'Invalid or inactive Top-up code',
                );
              }
            },
            child: const Text('Top up +100 · Max 1,000'),
          ),
        ],
      ),
    ),
  );
}

class _BetaTopUpCodeLine extends StatelessWidget {
  const _BetaTopUpCodeLine({required this.code, required this.validity});

  final String code;
  final String validity;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: SelectableText.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$code  ',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          TextSpan(
            text: validity,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      maxLines: 1,
    ),
  );
}

class BackgroundMusicPicker extends StatelessWidget {
  const BackgroundMusicPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final music = MusicScope.of(context);
    return SettingsChoiceTile<BackgroundMusic>(
      key: ValueKey('background-music-${music?.selection.name ?? 'theme'}'),
      icon: Icons.library_music_outlined,
      title: 'Background music',
      value: music?.selection ?? BackgroundMusic.theme,
      values: BackgroundMusic.values,
      optionLabel: (choice) => choice.label,
      supportingText:
          music?.saveError ??
          (music?.muted == true
              ? 'Saved. Unmute to listen.'
              : 'Plays immediately and is remembered.'),
      enabled: music != null,
      onSelected: (choice) => music?.setSelection(choice),
    );
  }
}
