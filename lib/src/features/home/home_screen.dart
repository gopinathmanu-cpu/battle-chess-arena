import 'package:flutter/material.dart';
import 'package:dartchess/dartchess.dart';
import '../play/board_appearance.dart';
import '../../services/theme_music.dart';

import '../../domain/piece_pack.dart';
import '../../domain/game_session.dart';
import '../../services/computer_player.dart';
import '../../services/last_game_storage.dart';
import '../play/animation_lab_screen.dart';
import '../online/online_lobby_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PiecePack _selected = piecePacks.first;
  ComputerDifficulty _difficulty = ComputerDifficulty.medium;
  bool _savedPromptOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptForSavedGame());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WorldBackdrop(
        pack: _selected,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _selected.accent.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.sports_esports, color: _selected.accent),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BATTLE CHESS ARENA',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Every capture tells a story',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                const MusicButton(),
              ],
            ),
            const SizedBox(height: 26),
            _HeroCard(pack: _selected),
            const SizedBox(height: 16),
            for (final side in Side.values) ...[
              Text(
                _selected.armyName(side),
                style: TextStyle(
                  color: _selected.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(
                height: 62,
                child: Row(
                  children: [
                    for (final role in CharacterPiece.roles)
                      Expanded(
                        child: CharacterPiece(
                          piece: Piece(color: side, role: role),
                          pack: _selected,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 26),
            const Text(
              'Choose your army',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: piecePacks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final pack = piecePacks[index];
                  final selected = pack.id == _selected.id;
                  return _PackCard(
                    pack: pack,
                    selected: selected,
                    onTap: () => setState(() => _selected = pack),
                  );
                },
              ),
            ),
            const SizedBox(height: 26),
            Card(
              child: ListTile(
                leading: Icon(Icons.tune, color: _selected.accent),
                title: const Text('Computer difficulty'),
                subtitle: Text(_difficulty.description),
                trailing: DropdownButton<ComputerDifficulty>(
                  key: const ValueKey('home-difficulty-selector'),
                  value: _difficulty,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final difficulty in ComputerDifficulty.values)
                      DropdownMenuItem(
                        value: difficulty,
                        child: Text(difficulty.label),
                      ),
                  ],
                  onChanged: (difficulty) {
                    if (difficulty != null) {
                      setState(() => _difficulty = difficulty);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ModeButton(
              icon: Icons.smart_toy_outlined,
              title: 'Play Computer',
              subtitle: '${_difficulty.label} opponent with animated captures',
              accent: _selected.accent,
              onTap: () => _openGame(PlayerMode.computer),
            ),
            const SizedBox(height: 12),
            _ModeButton(
              icon: Icons.public,
              title: 'Play Online',
              subtitle: 'Create or join a server-authoritative match',
              accent: _selected.accent,
              onTap: _openOnline,
            ),
            const SizedBox(height: 12),
            _ModeButton(
              icon: Icons.emoji_events_outlined,
              title: 'Tournaments',
              subtitle: 'Arena, Swiss and private events',
              accent: _selected.accent,
              onTap: () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Coming Soon!!!'))),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptForSavedGame({PlayerMode? requestedMode}) async {
    if (_savedPromptOpen) return;
    final saved = await LastGameStorage.load();
    if (!mounted || saved == null) {
      if (requestedMode != null) _pushGame(mode: requestedMode);
      return;
    }
    _savedPromptOpen = true;
    final choice = await showDialog<_SavedGameChoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Resume last game?'),
        content: Text(
          '${saved.mode == PlayerMode.computer ? 'Computer game' : 'Local game'} '
          'with ${saved.moves.length} moves is still open.\n\n'
          'Starting a new game will permanently delete this saved position.',
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
    _savedPromptOpen = false;
    if (!mounted) return;
    if (choice == _SavedGameChoice.resume) {
      final pack = piecePacks.firstWhere((pack) => pack.id == saved.homePack);
      setState(() {
        _selected = pack;
        _difficulty = saved.difficulty;
      });
      _pushGame(
        mode: saved.mode,
        pack: pack,
        difficulty: saved.difficulty,
        savedGame: saved,
      );
    } else if (choice == _SavedGameChoice.newGame) {
      await LastGameStorage.clear();
      if (!mounted) return;
      _pushGame(mode: requestedMode ?? saved.mode);
    }
  }

  void _openGame(PlayerMode mode) => _promptForSavedGame(requestedMode: mode);

  void _pushGame({
    required PlayerMode mode,
    PiecePack? pack,
    ComputerDifficulty? difficulty,
    SavedGame? savedGame,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnimationLabScreen(
          pack: pack ?? _selected,
          mode: mode,
          difficulty: difficulty ?? _difficulty,
          savedGame: savedGame,
        ),
      ),
    );
  }

  void _openOnline() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OnlineLobbyScreen(pack: _selected)),
    );
  }
}

enum _SavedGameChoice { cancel, newGame, resume }

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.pack});
  final PiecePack pack;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 190),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [pack.accent.withValues(alpha: .32), const Color(0xFF171829)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: pack.accent.withValues(alpha: .38)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pack.name.toUpperCase(),
                  style: TextStyle(
                    color: pack.accent,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Strategy becomes spectacle.',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Short, skippable battles for every capture.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Icon(pack.icon, size: 72, color: pack.accent),
        ],
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.selected,
    required this.onTap,
  });
  final PiecePack pack;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 138,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? pack.accent.withValues(alpha: .16)
              : const Color(0xFF151725),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? pack.accent : Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(pack.icon, color: pack.accent, size: 30),
            const Spacer(),
            Text(
              pack.name,
              maxLines: 2,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      tileColor: const Color(0xFF151725),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      leading: CircleAvatar(
        backgroundColor: accent.withValues(alpha: .14),
        child: Icon(icon, color: accent),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
