import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import '../progression/progress_widgets.dart';

import '../../domain/game_session.dart';
import '../../domain/game_time_control.dart';
import '../../domain/online_player_profile.dart';
import '../../domain/piece_pack.dart';
import '../../services/computer_player.dart';
import '../../services/home_chess_set.dart';
import '../../services/custom_chess_sets.dart';
import '../../services/custom_set_actions.dart';
import '../../domain/custom_chess_set.dart';
import '../studio/chess_set_studio_screen.dart';
import '../../services/last_game_storage.dart';
import '../../services/game_history_storage.dart';
import '../../services/online_game_history.dart';
import '../../services/player_identity_controller.dart';
import '../../services/player_progress_controller.dart';
import '../../services/theme_music.dart';
import '../../services/tournament_storage.dart';
import '../online/online_lobby_screen.dart';
import '../history/game_history_screen.dart';
import '../online/online_avatar_image.dart';
import '../profile/online_profile_settings.dart';
import '../play/animation_lab_screen.dart';
import '../play/board_appearance.dart';
import '../play/player_side_selector.dart';
import '../settings/about_screen.dart';
import '../settings/game_settings_sheet.dart';
import '../credits/arena_credit_header.dart';
import '../../services/game_display_settings.dart';
import '../tournaments/tournaments_screen.dart';
import 'chess_set_carousel.dart';
import 'chess_set_family_selector.dart';

enum _ThemeFilter {
  all('All themes', null),
  myThemes('My Themes', null, custom: true),
  historical('Historical', PiecePackGroup.historical),
  legendary('Legendary', PiecePackGroup.legendary),
  original('Fantasy', PiecePackGroup.original);

  const _ThemeFilter(this.label, this.group, {this.custom = false});
  final String label;
  final PiecePackGroup? group;
  final bool custom;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _displaySettings = GameDisplaySettings();
  final _chooserKey = GlobalKey();

  @override
  void dispose() {
    _displaySettings.dispose();
    super.dispose();
  }

  void _openHomeSettings() {
    showGameSettings(
      context: context,
      display: _displaySettings,
      inGame: false,
      onCustomize: () {
        final target = _chooserKey.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 250),
          );
        }
      },
      onReset: () => _changeChessSet(() {
        _selected = piecePacks.first;
        _classicPieces = true;
        _classicStyle = ClassicPieceStyle.magneticTeaching;
      }),
      onOnlineProfileChanged: (profile) {
        if (mounted) setState(() => _onlineProfile = profile);
      },
      chessSetSelector: (refresh) => SettingsChessSetPicker(
        animatedArena: !_classicPieces,
        pack: _selected,
        classicStyle: _classicStyle,
        onSelected: (selection) async {
          await _changeChessSet(() {
            _classicPieces = !selection.animatedArena;
            _selected = selection.pack;
            _classicStyle = selection.classicStyle;
          });
          refresh();
        },
      ),
      controls: (_) => const [],
    );
  }

  PiecePack _selected = piecePacks.first;
  bool _classicPieces = true;
  ClassicPieceStyle _classicStyle = ClassicPieceStyle.magneticTeaching;
  ComputerDifficulty _difficulty = ComputerDifficulty.medium;
  bool _savedPromptOpen = false;
  TournamentPlayerScore? _tournamentScore;
  OnlinePlayerProfile? _onlineProfile;
  int _selectionRevision = 0;
  Future<void> _pendingSelectionSave = Future.value();
  String? _selectionError;
  _ThemeFilter _themeFilter = _ThemeFilter.all;

  List<PiecePack> get _visiblePacks => _themeFilter.custom
      ? const []
      : _themeFilter.group == null
      ? availablePiecePacks
      : availablePiecePacks
            .where((pack) => pack.group == _themeFilter.group)
            .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _loadTournamentScore();
    _loadChessSet();
    _loadOnlineProfile();
  }

  Future<void> _loadOnlineProfile() async {
    final profile = await OnlineGameHistory.loadProfile();
    if (mounted) setState(() => _onlineProfile = profile);
  }

  Future<void> _loadTournamentScore() async {
    try {
      final score = await TournamentStorage().loadPlayerScore();
      if (mounted) setState(() => _tournamentScore = score);
    } catch (_) {
      if (mounted) setState(() => _tournamentScore = null);
    }
  }

  Future<void> _openTournaments({bool conquests = false}) async {
    final customSelected = CustomChessSetScope.maybeOf(context)?.active != null;
    final classicPieces = !conquests || (!customSelected && _classicPieces);
    final animatedArena = conquests && !customSelected && !_classicPieces;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: conquests ? '/conquests' : '/tournament'),
        builder: (_) => TournamentsScreen(
          pack: _selected,
          conquests: conquests,
          initialClassicPieces: classicPieces,
          initialAnimatedArena: animatedArena,
          initialClassicStyle: _classicStyle,
        ),
      ),
    );
    await _loadTournamentScore();
  }

  Future<void> _loadChessSet() async {
    try {
      final saved = await HomeChessSet.load();
      if (!mounted || _selectionRevision != 0) return;
      setState(() {
        _selected = availablePiecePacks.firstWhere(
          (pack) => pack.id == saved.pack,
          orElse: () => availablePiecePacks.first,
        );
        _classicPieces = saved.classic;
        _classicStyle = saved.style;
      });
    } catch (_) {
      // A storage failure must not prevent starting a game.
    }
  }

  Future<bool> _changeChessSet(
    VoidCallback change, {
    bool keepCustomSet = false,
  }) async {
    if (!keepCustomSet && !await restoreBuiltInChessSet(context)) return false;
    if (!mounted) return false;
    final revision = ++_selectionRevision;
    setState(() {
      change();
      _selectionError = null;
    });
    final selection = HomeChessSet(
      pack: _selected.id,
      classic: _classicPieces,
      style: _classicStyle,
    );
    // Rapid swipes are saved in order, so the final selection wins.
    _pendingSelectionSave = _pendingSelectionSave.then((_) async {
      try {
        await selection.save();
      } catch (_) {
        if (mounted && revision == _selectionRevision) {
          setState(
            () => _selectionError =
                'Selected for this visit; could not save for next time.',
          );
        }
      }
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final custom = CustomChessSetScope.maybeOf(context)?.active;
    return Scaffold(
      body: SizedBox.expand(
        child: WorldBackdrop(
          pack: _selected,
          customSet: custom,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 680;
              final shortWide = wide && constraints.maxHeight < 400;
              final chooser = _buildChooser();
              final modeButtons = _buildModes(
                compact: constraints.maxHeight < 620,
              );
              final modes = shortWide
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: _headerActions(),
                          ),
                        ),
                        const SizedBox(height: 4),
                        modeButtons,
                      ],
                    )
                  : modeButtons;
              return SingleChildScrollView(
                key: const ValueKey('home-scroll'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      children: [
                        if (!shortWide) ...[
                          _buildHeader(),
                          const SizedBox(height: 8),
                        ],
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: chooser),
                              const SizedBox(width: 24),
                              Expanded(flex: 4, child: modes),
                            ],
                          )
                        else ...[
                          chooser,
                          const SizedBox(height: 12),
                          modes,
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final accent = Theme.of(context).colorScheme.primary;
    final profile = _onlineProfile;
    final progress = PlayerProgressScope.maybeOf(context)?.progress;
    final displayName =
        profile?.name ?? PlayerIdentityScope.maybeOf(context)?.nickname;
    return Container(
      key: const ValueKey('home-welcome-banner'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: .72), width: 1.2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF29283C), accent, .34)!,
            const Color(0xFF171927).withValues(alpha: .96),
            Color.lerp(const Color(0xFF171927), accent, .16)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .2),
            blurRadius: 22,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: .06),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Stack(
          children: [
            Positioned(
              right: -28,
              top: -42,
              child: IgnorePointer(
                child: Container(
                  width: 126,
                  height: 126,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: .18),
                        accent.withValues(alpha: .08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 7, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (profile == null) ...[
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .22),
                            ),
                          ),
                          child: Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                            color: Color.lerp(accent, Colors.white, .34),
                          ),
                        ),
                        const SizedBox(width: 9),
                      ] else ...[
                        OnlineAvatarImage(
                          key: const ValueKey('home-avatar-image'),
                          avatarId: profile.avatarId,
                          size: 60,
                        ),
                        const SizedBox(width: 11),
                      ],
                      Expanded(
                        child: displayName == null
                            ? Row(
                                key: const ValueKey('home-guest-profile'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Flexible(
                                    child: Text(
                                      'Guest',
                                      key: ValueKey('home-guest-name'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 19,
                                        height: 1.05,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: .15,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  IconButton(
                                    key: const ValueKey(
                                      'edit-home-guest-profile',
                                    ),
                                    tooltip: 'Add your name and avatar',
                                    visualDensity: VisualDensity.compact,
                                    iconSize: 18,
                                    onPressed: _editGuestProfile,
                                    icon: const Icon(Icons.edit_rounded),
                                  ),
                                ],
                              )
                            : profile != null
                            ? Column(
                                key: const ValueKey('home-avatar-profile'),
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    key: const ValueKey('home-avatar-name'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      height: 1.05,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: .15,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  HomeExperienceSummary(
                                    experience: progress?.experience ?? 0,
                                    trophies: progress?.trophies ?? 0,
                                    key: const ValueKey('home-avatar-details'),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : Align(
                                key: const ValueKey('home-avatar-profile'),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  displayName,
                                  key: const ValueKey('home-avatar-name'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    height: 1.05,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .15,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 6),
                      const ArenaCreditHeader(compact: true),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Expanded(
                        child: ProgressBadgeSummary(showTitle: false),
                      ),
                      IconButtonTheme(
                        data: IconButtonThemeData(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: .08,
                            ),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(32, 32),
                            maximumSize: const Size(32, 32),
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: _headerActions(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _headerActions() => [
    const MusicButton(),
    IconButton(
      key: const ValueKey('home-settings-button'),
      tooltip: 'Settings',
      onPressed: _openHomeSettings,
      icon: const Icon(Icons.settings_outlined),
    ),
    IconButton(
      key: const ValueKey('about-button'),
      tooltip: 'About',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
      ),
      icon: const Icon(Icons.info_outline),
    ),
  ];

  Future<void> _editGuestProfile() async {
    final profile = await showOnlineProfileSettings(
      context,
      initialProfile: _onlineProfile,
    );
    if (!mounted || profile == null) return;
    setState(() => _onlineProfile = profile);
  }

  Widget _buildChooser() {
    final library = CustomChessSetScope.maybeOf(context);
    final custom = library?.active;
    final visibleFilter = custom != null ? _ThemeFilter.myThemes : _themeFilter;
    return Column(
      key: _chooserKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(
          icon: Icons.palette_outlined,
          title: 'Choose your set',
          accent: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 8),
        ChessSetFamilySelector(
          pack: _selected,
          classic: _classicPieces,
          style: _classicStyle,
          customActive: custom != null,
          onChanged: (classic) => _changeChessSet(() {
            _classicPieces = classic;
            if (_themeFilter.custom) _themeFilter = _ThemeFilter.all;
          }),
        ),
        const SizedBox(height: 10),
        if (visibleFilter.custom)
          _myThemesCategory(library)
        else
          ChessSetCarousel(
            key: ValueKey('chess-set-filter-${_themeFilter.name}'),
            pack: _selected,
            themedPacks: _visiblePacks,
            classic: _classicPieces,
            style: _classicStyle,
            onDoubleTap: () => _openGame(PlayerMode.computer),
            onChanged: (index) => _changeChessSet(() {
              if (_classicPieces) {
                _classicStyle = ClassicPieceStyle.values[index];
              } else {
                _selected = piecePacks[index];
              }
            }),
          ),
        if (!_classicPieces)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Align(
              alignment: Alignment.center,
              child: Semantics(
                label: 'Filter animated chess sets',
                child: DropdownButton<_ThemeFilter>(
                  key: const ValueKey('chess-set-group-filter'),
                  value: visibleFilter,
                  isDense: true,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHigh,
                  style: Theme.of(context).textTheme.bodyMedium,
                  items: [
                    for (final filter in _ThemeFilter.values.where(
                      (filter) =>
                          (filter.custom &&
                              (library?.sets.isNotEmpty ?? false)) ||
                          (!filter.custom && filter.group == null) ||
                          availablePiecePacks.any(
                            (pack) => pack.group == filter.group,
                          ),
                    ))
                      DropdownMenuItem(
                        value: filter,
                        child: Text(
                          filter.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (filter) async {
                    if (filter == null) return;
                    if (filter.custom) {
                      setState(() => _themeFilter = filter);
                      final first = library?.sets.firstOrNull;
                      if (library?.active == null && first != null) {
                        await library!.activate(first.id);
                      }
                      return;
                    }
                    await _changeChessSet(() {
                      _themeFilter = filter;
                      if (!_visiblePacks.any(
                        (pack) => pack.id == _selected.id,
                      )) {
                        _selected = _visiblePacks.first;
                      }
                    });
                  },
                ),
              ),
            ),
          ),
        if (library != null && custom != null)
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  key: const ValueKey('edit-custom-theme'),
                  onPressed: () =>
                      _openCustomSetEditor(library, setId: custom.id),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('delete-custom-theme'),
                  onPressed: () => _deleteCustomSet(library, custom),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        if (_selectionError != null)
          Text(
            _selectionError!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.amber),
          ),
      ],
    );
  }

  Future<void> _openCustomSetEditor(
    CustomChessSets library, {
    required String setId,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/chess-set-studio/editor'),
        builder: (_) => ChessSetStudioScreen(initialSetId: setId),
      ),
    );
    if (!mounted || library.sets.isEmpty) return;
    setState(() => _themeFilter = _ThemeFilter.myThemes);
  }

  Future<void> _deleteCustomSet(
    CustomChessSets library,
    CustomChessSet set,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this chess set?'),
        content: Text(
          '“${set.name}” will be permanently removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            key: const ValueKey('confirm-delete-custom-theme'),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final deleted = await library.delete(set.id);
    if (!mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            library.error ?? 'Could not delete the chess set. Try again.',
          ),
        ),
      );
      return;
    }

    final next = library.sets.firstOrNull;
    if (next != null) {
      await library.activate(next.id);
      if (mounted) setState(() => _themeFilter = _ThemeFilter.myThemes);
    } else {
      setState(() {
        _themeFilter = _ThemeFilter.all;
        _classicPieces = true;
      });
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('“${set.name}” deleted.')));
    }
  }

  Widget _myThemesCategory(CustomChessSets? library) {
    final sets = library?.sets ?? const <CustomChessSet>[];
    if (sets.isEmpty) {
      return const Card(
        key: ValueKey('my-themes-empty'),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFC857)),
              SizedBox(height: 8),
              Text(
                'My Themes',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4),
              Text('No saved chess sets.', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    final active = library?.active ?? sets.first;
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: Color(0xFFFFC857),
            ),
            SizedBox(width: 6),
            Text(
              'My Themes',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CustomChessSetCarousel(
          sets: sets,
          active: active,
          basePack: _selected,
          onChanged: (set) => library?.activate(set.id),
          onDoubleTap: () => _openGame(PlayerMode.computer),
        ),
      ],
    );
  }

  Widget _buildModes({required bool compact}) {
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(
          icon: Icons.sports_esports_outlined,
          title: 'Choose how to play',
          accent: accent,
        ),
        const SizedBox(height: 8),
        _ModeButton(
          key: const ValueKey('play-computer-button'),
          icon: Icons.smart_toy_outlined,
          title: 'Play Computer',
          subtitle: compact ? null : 'Choose side & difficulty',
          accent: accent,
          onTap: () => _openGame(PlayerMode.computer),
        ),
        const SizedBox(height: 8),
        _ModeButton(
          icon: Icons.people_alt_outlined,
          title: 'Play Online',
          subtitle: compact ? null : 'Friends & rivals',
          accent: accent,
          onTap: _openOnline,
        ),
        const SizedBox(height: 8),
        _ModeButton(
          icon: Icons.emoji_events_outlined,
          title: 'Tournaments',
          subtitle: compact
              ? null
              : _tournamentScore == null
              ? 'Three cups to conquer'
              : '${_tournamentScore!.points} points · ${_tournamentScore!.trophies} trophies',
          accent: accent,
          onTap: () => _openTournaments(),
        ),
        const SizedBox(height: 8),
        _ModeButton(
          key: const ValueKey('conquests-button'),
          icon: Icons.explore_outlined,
          title: 'Conquests',
          subtitle: compact ? null : 'History & Fantasy · Adaptive opponents',
          accent: accent,
          onTap: () => _openTournaments(conquests: true),
        ),
        const SizedBox(height: 8),
        _ModeButton(
          key: const ValueKey('game-history-button'),
          icon: Icons.history,
          title: 'Game history',
          subtitle: compact ? null : 'Past games & cinematic replays',
          accent: accent,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/game-history'),
              builder: (_) => const GameHistoryScreen(),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _promptForSavedGame({PlayerMode? requestedMode}) async {
    if (_savedPromptOpen) return;
    _savedPromptOpen = true;
    try {
      // Recover any retained completion before the resume loader clears it.
      await GameHistoryStorage().migrateRetainedGames();
      await _showSavedGamePrompt(requestedMode: requestedMode);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save this game to history. Please try again.',
            ),
          ),
        );
      }
    } finally {
      _savedPromptOpen = false;
    }
  }

  Future<void> _showSavedGamePrompt({PlayerMode? requestedMode}) async {
    final saved = await LastGameStorage.load();
    if (!mounted || saved == null) {
      if (requestedMode != null) await _startNewGame(requestedMode);
      return;
    }
    final choice = await showDialog<_SavedGameChoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Resume last game?'),
        content: Text(
          '${saved.mode == PlayerMode.computer ? 'Computer game' : 'Local game'} '
          'with ${saved.moves.length} moves is still open.\n\n'
          'Starting a new game replaces this resumable game. Its played moves stay in Game history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _SavedGameChoice.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _SavedGameChoice.newGame),
            child: const Text('New Game'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, _SavedGameChoice.resume),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Resume Last Game'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == _SavedGameChoice.resume) {
      final pack = piecePacks.firstWhere((pack) => pack.id == saved.homePack);
      setState(() {
        _selected = availablePiecePacks.firstWhere(
          (available) => available.id == pack.id,
          orElse: () => availablePiecePacks.first,
        );
        if (_themeFilter.group != null &&
            _selected.group != _themeFilter.group) {
          _themeFilter = _ThemeFilter.all;
        }
        _difficulty = saved.difficulty;
        _classicPieces = saved.classicPieces;
        _classicStyle = saved.classicStyle;
      });
      _pushGame(
        mode: saved.mode,
        pack: pack,
        difficulty: saved.difficulty,
        savedGame: saved,
      );
    } else if (choice == _SavedGameChoice.newGame) {
      try {
        await GameHistoryStorage().save(GameHistoryRecord.fromSavedGame(saved));
        await LastGameStorage.clear();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not save this game to history. Please try again.',
              ),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      await _startNewGame(requestedMode ?? saved.mode);
    }
  }

  Future<void> _startNewGame(PlayerMode mode) async {
    final pack = _selected;
    final customSelected = CustomChessSetScope.maybeOf(context)?.active != null;
    final classicPieces = !customSelected && _classicPieces;
    final animatedArena = !customSelected && !_classicPieces;
    final classicStyle = _classicStyle;
    if (mode != PlayerMode.computer) {
      _pushGame(
        mode: mode,
        pack: pack,
        classicPieces: classicPieces,
        initialAnimatedArena: animatedArena,
        classicStyle: classicStyle,
      );
      return;
    }
    var humanSide = Side.white;
    var timeControl = GameTimeControl.practice;
    var selectedDifficulty = _difficulty;
    final difficulty = await showDialog<ComputerDifficulty>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          scrollable: true,
          key: const ValueKey('computer-difficulty-dialog'),
          title: const Text('Choose computer difficulty'),
          contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlayerSideSelector(
                side: humanSide,
                onChanged: (side) => update(() => humanSide = side),
              ),
              DropdownButtonFormField<GameTimeControl>(
                isExpanded: true,
                initialValue: timeControl,
                decoration: const InputDecoration(labelText: 'Game clock'),
                items: const [
                  DropdownMenuItem(
                    value: GameTimeControl.practice,
                    child: Text('Unlimited (No timer limit)'),
                  ),
                  DropdownMenuItem(
                    value: GameTimeControl.rapid,
                    child: Text('15 min · Rapid'),
                  ),
                ],
                onChanged: (value) => update(() => timeControl = value!),
              ),
              for (final option in ComputerDifficulty.values)
                ListTile(
                  key: ValueKey('computer-difficulty-${option.name}'),
                  selected: option == selectedDifficulty,
                  leading: Icon(
                    option == selectedDifficulty
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(option.label),
                  subtitle: Text(option.description),
                  onTap: () => update(() => selectedDifficulty = option),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              key: const ValueKey('start-computer-game'),
              onPressed: () => Navigator.pop(dialogContext, selectedDifficulty),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Game'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || difficulty == null) return;
    setState(() => _difficulty = difficulty);
    _pushGame(
      mode: mode,
      difficulty: difficulty,
      pack: pack,
      classicPieces: classicPieces,
      initialAnimatedArena: animatedArena,
      classicStyle: classicStyle,
      humanSide: humanSide,
      timeControl: timeControl,
    );
  }

  void _openGame(PlayerMode mode) => _promptForSavedGame(requestedMode: mode);

  void _pushGame({
    required PlayerMode mode,
    PiecePack? pack,
    ComputerDifficulty? difficulty,
    SavedGame? savedGame,
    bool? classicPieces,
    bool? initialAnimatedArena,
    ClassicPieceStyle? classicStyle,
    Side humanSide = Side.white,
    GameTimeControl timeControl = GameTimeControl.rapid,
  }) {
    final selectedPack = pack ?? _selected;
    final selectedClassicPieces = classicPieces ?? _classicPieces;
    final selectedClassicStyle = classicStyle ?? _classicStyle;
    final animatedArena = savedGame == null
        ? initialAnimatedArena ?? !selectedClassicPieces
        : savedGame.animatedArena;
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(
          name: mode == PlayerMode.computer ? '/computer' : '/local',
        ),
        builder: (_) => AnimationLabScreen(
          pack: selectedPack,
          mode: mode,
          difficulty: difficulty ?? _difficulty,
          savedGame: savedGame,
          humanSide: humanSide,
          timeControl: timeControl,
          initialClassicPieces: selectedClassicPieces,
          initialClassicStyle: selectedClassicStyle,
          initialAnimatedArena: animatedArena,
        ),
      ),
    );
  }

  Future<void> _openOnline() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/online'),
        builder: (_) => OnlineLobbyScreen(
          pack: _selected,
          initialClassicPieces: true,
          initialAnimatedArena: false,
          initialClassicStyle: _classicStyle,
        ),
      ),
    );
    if (mounted) await _loadOnlineProfile();
  }
}

enum _SavedGameChoice { cancel, newGame, resume }

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final Color accent;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: accent.withValues(alpha: .42)),
        ),
        child: Icon(
          icon,
          size: 16,
          color: Color.lerp(accent, Colors.white, .2),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: .2,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent.withValues(alpha: .48), Colors.transparent],
            ),
          ),
        ),
      ),
    ],
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .09),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: .42)),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color.lerp(const Color(0xFF202334), accent, .18)!,
                const Color(0xFF151725),
              ],
            ),
          ),
          child: ListTile(
            onTap: onTap,
            dense: true,
            visualDensity: subtitle == null
                ? VisualDensity.standard
                : const VisualDensity(vertical: -2),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: .34),
                    accent.withValues(alpha: .15),
                  ],
                ),
                border: Border.all(color: accent.withValues(alpha: .34)),
              ),
              child: Icon(icon, color: Color.lerp(accent, Colors.white, .14)),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: subtitle == null
                ? null
                : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Icon(
              Icons.arrow_forward_rounded,
              color: Color.lerp(accent, Colors.white, .24),
            ),
          ),
        ),
      ),
    );
  }
}
