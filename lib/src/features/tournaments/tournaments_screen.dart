// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:math';
import 'package:dartchess/dartchess.dart';
import '../../services/last_game_storage.dart';

import '../../domain/bot_tournament.dart';
import '../../domain/adaptive_difficulty.dart';
import '../../domain/game_session.dart';
import '../../domain/game_time_control.dart';
import '../../domain/online_player_profile.dart';
import '../../domain/piece_pack.dart';
import '../../services/computer_player.dart';
import '../../services/theme_music.dart';
import '../../services/tournament_storage.dart';
import '../online/online_avatar_image.dart';
import '../play/animation_lab_screen.dart';
import '../play/board_appearance.dart';
import 'tournament_match_config.dart';
import 'tournament_journey.dart';
import 'championship_celebration.dart';

class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({
    required this.pack,
    this.storage,
    this.computerFactory,
    this.initialClassicPieces = true,
    this.initialAnimatedArena,
    this.initialClassicStyle = ClassicPieceStyle.magneticTeaching,
    this.conquests = false,
    super.key,
  });
  final PiecePack pack;
  final TournamentStorage? storage;
  final ComputerPlayer Function()? computerFactory;
  final bool initialClassicPieces;
  final bool? initialAnimatedArena;
  final ClassicPieceStyle initialClassicStyle;
  final bool conquests;

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  late final _storage = widget.storage ?? TournamentStorage();
  final _progress = <String, TournamentProgress?>{};
  final _errors = <String>{};
  bool _loading = true;
  bool _opening = false;
  List<BotTournament> get _events =>
      widget.conquests ? builtInConquests : builtInTournaments;

  TournamentPlayerScore? get _score => _errors.isNotEmpty
      ? null
      : TournamentPlayerScore.fromRuns({
          for (final cup in _events)
            if (_progress[cup.id] case final progress?) cup: progress.run,
        });

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final cup in _events) {
      try {
        _progress[cup.id] = await _storage.load(cup);
        _errors.remove(cup.id);
      } catch (_) {
        _errors.add(cup.id);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _open(BotTournament cup) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final progress = await _storage.enter(cup);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => _TournamentDetail(
            cup: cup,
            pack: widget.pack,
            storage: _storage,
            progress: progress,
            computerFactory: widget.computerFactory,
            initialClassicPieces: widget.initialClassicPieces,
            initialAnimatedArena: widget.initialAnimatedArena,
            initialClassicStyle: widget.initialClassicStyle,
          ),
        ),
      );
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open this tournament. Saved progress has been kept.',
            ),
          ),
        );
      }
    }
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.conquests ? 'Conquests' : 'Tournaments'),
      actions: const [MusicButton()],
    ),
    body: WorldBackdrop(
      pack: widget.pack,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TournamentScoreBanner(
                  score: _score,
                  conquests: widget.conquests,
                ),
                const SizedBox(height: 20),
                Text(
                  widget.conquests
                      ? 'Choose your conquest'
                      : 'Three cups. Your next challenge.',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.conquests
                      ? 'Choose a 3, 5, 10, or full 19-match campaign. Every regional opponent is mapped before you play. Win to advance; use the free cooldown or an immediate credit retry after a loss or draw.'
                      : 'The 20 built-in computer avatars compete in cups matched to their proficiency. Win each round to advance. Retry a loss or draw any time.',
                ),
                const SizedBox(height: 16),
                for (final cup in _events)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: BorderSide(
                        color: tournamentColor(cup).withValues(alpha: .4),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              TournamentTrophy(
                                size: 52,
                                earned:
                                    _progress[cup.id]?.run.completed == true,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  cup.title,
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cup.isConquest
                                ? '${cup.conquestSize?.label ?? 'Adaptive'} · ${cup.roundCount} matches · 15 min · Rapid'
                                : '${cup.level.label} · ${cup.opponents.length} bots + you · ${cup.roundCount} rounds',
                          ),
                          const SizedBox(height: 6),
                          Text(cup.description),
                          const SizedBox(height: 12),
                          Text(
                            '+${cup.pointsPerWin} points per win · ${cup.pointsPerWin * cup.roundCount} per cup',
                            style: TextStyle(
                              color: tournamentColor(cup),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value:
                                  (_progress[cup.id]?.run.wonRounds ?? 0) /
                                  cup.roundCount,
                              color: tournamentColor(cup),
                              backgroundColor: tournamentColor(
                                cup,
                              ).withValues(alpha: .12),
                              minHeight: 5,
                              semanticsLabel: '${cup.title} rounds won',
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_errors.contains(cup.id))
                            const Text(
                              'Saved progress could not be read. Try opening the cup again.',
                            )
                          else if (_progress[cup.id] case final progress?)
                            Text(
                              progress.run.completed
                                  ? 'Champion · Cup completed'
                                  : '${progress.run.wonRounds}/${cup.roundCount} rounds won',
                            ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            key: ValueKey('open-tournament-${cup.id}'),
                            onPressed: _opening ? null : () => _open(cup),
                            icon: const Icon(Icons.arrow_forward),
                            label: Text(
                              _progress[cup.id]?.run.completed == true
                                  ? (widget.conquests
                                        ? 'View conquered realms'
                                        : 'View trophy & bracket')
                                  : _progress[cup.id] == null
                                  ? (widget.conquests
                                        ? 'Begin conquest'
                                        : 'Enter tournament')
                                  : (widget.conquests
                                        ? 'Continue conquest'
                                        : 'Continue tournament'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Play offline. Progress and your adaptive conquest level are saved on this device. Fixed-level cups and the original 20 bots do not adapt.',
                  ),
                ),
              ],
            ),
    ),
  );
}

class _TournamentDetail extends StatefulWidget {
  const _TournamentDetail({
    required this.cup,
    required this.pack,
    required this.storage,
    required this.progress,
    this.computerFactory,
    required this.initialClassicPieces,
    required this.initialAnimatedArena,
    required this.initialClassicStyle,
  });
  final BotTournament cup;
  final PiecePack pack;
  final TournamentStorage storage;
  final TournamentProgress progress;
  final ComputerPlayer Function()? computerFactory;
  final bool initialClassicPieces;
  final bool? initialAnimatedArena;
  final ClassicPieceStyle initialClassicStyle;

  @override
  State<_TournamentDetail> createState() => _TournamentDetailState();
}

class _TournamentDetailState extends State<_TournamentDetail> {
  late TournamentProgress _progress = widget.progress;
  final _scrollController = ScrollController();
  bool _busy = false;
  bool _reloadFailed = false;
  bool _tossForColors = false;
  AdaptiveDifficulty _player = const AdaptiveDifficulty();
  BotTournament get _cup => widget.cup;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final progress = await widget.storage.load(_cup);
      final player = await widget.storage.loadAdaptivePlayer();
      if (progress == null) throw StateError('Missing tournament');
      if (mounted) {
        setState(() {
          _progress = progress;
          _player = player;
          _reloadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _reloadFailed = true);
    }
  }

  Future<void> _play() async {
    if (_busy || _progress.run.completed) return;
    setState(() => _busy = true);
    try {
      final progress = await widget.storage.beginAttempt(_cup);
      final run = progress.run;
      final opponent = run.currentOpponent(_cup);
      final packId = _cup.isConquest
          ? _cup.armies[run.wonRounds].id
          : _cup.theme ?? progress.game?.homePack ?? widget.pack.id;
      final pack = piecePacks.firstWhere((item) => item.id == packId);
      final isNewToss = progress.game == null && _tossForColors;
      final saved =
          progress.game ??
          SavedGame(
            mode: PlayerMode.computer,
            humanSide: _cup.isConquest
                ? Side.white
                : isNewToss && Random.secure().nextBool()
                ? Side.black
                : Side.white,
            homePack: pack.id,
            difficulty: tournamentDifficulty(opponent.level),
            moves: const [],
            whiteMilliseconds: _cup.minutesPerSide * 60000,
            timeControl: GameTimeControl(baseMs: _cup.minutesPerSide * 60000),
            blackMilliseconds: _cup.minutesPerSide * 60000,
            fastBattles: false,
            whitePack: _cup.isConquest ? widget.pack.id : pack.id,
            blackPack: pack.id,
            boardPack: pack.id,
            updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
            classicPieces: !_cup.isConquest || widget.initialClassicPieces,
            animatedArena:
                _cup.isConquest &&
                (widget.initialAnimatedArena ?? !widget.initialClassicPieces),
            classicStyle: widget.initialClassicStyle,
          );
      // Persist the assignment before displaying it: resume must not reroll.
      if (progress.game == null) {
        await widget.storage.saveMatch(
          _cup,
          runId: run.runId,
          attempt: run.attempt,
          game: saved,
          result: null,
        );
      }
      if (!mounted) return;
      if (isNewToss) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Colour toss result'),
            content: Text(
              'You play ${saved.humanSide == Side.white ? 'White' : 'Black'}. ${opponent.name} plays ${saved.humanSide == Side.white ? 'Black' : 'White'}. White moves first.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Start round'),
              ),
            ],
          ),
        );
        if (!mounted) return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AnimationLabScreen(
            pack: pack,
            mode: PlayerMode.computer,
            difficulty: tournamentDifficulty(opponent.level),
            savedGame: saved,
            computerPlayer: widget.computerFactory?.call(),
            tournamentMatch: TournamentMatchConfig(
              title: '${_cup.title} · ${_cup.roundName(run.wonRounds)}',
              opponent: opponent,
              minutesPerSide: _cup.minutesPerSide,
              cup: _cup,
              roundIndex: run.wonRounds,
              save: (game, result) => widget.storage.saveMatch(
                _cup,
                runId: run.runId,
                attempt: run.attempt,
                game: game,
                result: result,
              ),
            ),
            initialClassicPieces: widget.initialClassicPieces,
            initialAnimatedArena: widget.initialAnimatedArena,
            initialClassicStyle: widget.initialClassicStyle,
          ),
        ),
      );
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      await _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not start the round. Please try again.'),
          ),
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  String _name(String? id) => id == tournamentHumanId
      ? 'You'
      : id == null
      ? 'Bye'
      : _cup.opponents.singleWhere((bot) => bot.id == id).name;

  @override
  Widget build(BuildContext context) {
    final run = _progress.run;
    final bracket = run.bracket(_cup);
    final opponent = run.completed ? null : run.currentOpponent(_cup);
    final retry = run.lastResult != null;
    final conquestActionLabel = run.playing
        ? 'Resume current match'
        : retry
        ? 'Retry this match'
        : 'Proceed to next match';
    return Scaffold(
      appBar: AppBar(title: Text(_cup.title), actions: const [MusicButton()]),
      bottomNavigationBar: _cup.isConquest && !run.completed && !retry
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  key: const ValueKey('conquest-proceed-button'),
                  onPressed: _busy || _reloadFailed ? null : _play,
                  icon: const Icon(Icons.flag_outlined),
                  label: Text(conquestActionLabel),
                ),
              ),
            )
          : null,
      body: WorldBackdrop(
        pack: widget.pack,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _cup.isConquest
                  ? '${_cup.conquestSize?.label ?? 'Adaptive'} conquest · ${_cup.roundCount} matches · Rapid ${_cup.minutesPerSide}+10'
                  : '${_cup.level.label} · ${_cup.opponents.length + 1} entrants · Rapid ${_cup.minutesPerSide}+10',
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a colour toss or play White. Wins advance you. Tournament and conquest retries are always free. Your clock pauses when you leave or background the app.',
            ),
            const SizedBox(height: 14),
            if (_cup.isConquest)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  'Your conquest level: ${_player.level.toStringAsFixed(1)}/20 · ${_player.games} games. Wins raise the challenge; losses ease the rematch; draws keep it steady. This is a practice level, not Elo.',
                ),
              ),
            TournamentJourney(cup: _cup, run: run),
            const SizedBox(height: 14),
            if (run.completed)
              Card(
                key: const ValueKey('tournament-champion'),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const TournamentTrophy(size: 96, earned: true),
                      Text(
                        _cup.isConquest
                            ? 'Conquest complete!'
                            : 'Tournament champion!',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'You won all ${_cup.roundCount} rounds of ${_cup.title}.',
                      ),
                      const Text(
                        'Your trophy and results are saved on this device.',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${run.pointsEarned(_cup)} points earned',
                        style: const TextStyle(
                          color: tournamentGold,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: const ValueKey('replay-championship'),
                        onPressed: () => showChampionshipCelebration(
                          context: context,
                          cup: _cup,
                          replay: true,
                        ),
                        icon: const Icon(Icons.celebration),
                        label: const Text('Relive the celebration'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _cup.roundName(run.wonRounds),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _cup.isConquest
                            ? Icon(
                                _cup.armies[run.wonRounds].icon,
                                size: 48,
                                color: _cup.armies[run.wonRounds].accent,
                              )
                            : OnlineAvatarImage(
                                avatarId: opponent!.avatarId,
                                size: 56,
                              ),
                        title: Text(opponent!.name),
                        subtitle: Text(
                          _cup.isConquest
                              ? 'Adaptive level ${run.nextConquestLevel(_player)}/20 · Computer'
                              : '${opponent.difficultyLabel} · Computer',
                        ),
                      ),
                      if (retry)
                        Text(
                          run.lastResult == TournamentRoundResult.loss
                              ? 'Round lost. Your rematch against ${opponent.name} is ready whenever you are.'
                              : 'Round drawn. Replay ${opponent.name} to decide who advances.',
                        ),
                      Text(
                        '+${_cup.pointsPerWin} points for this win · Earlier points are safe',
                        style: TextStyle(
                          color: tournamentColor(_cup),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_reloadFailed)
                        TextButton(
                          onPressed: _reload,
                          child: const Text(
                            'Could not refresh progress. Tap to retry.',
                          ),
                        ),
                      if (_progress.game == null && !_cup.isConquest)
                        SwitchListTile(
                          key: const ValueKey('tournament-colour-toss'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Toss for colours'),
                          subtitle: const Text(
                            'Randomly choose White and Black before this round.',
                          ),
                          value: _tossForColors,
                          onChanged: _busy
                              ? null
                              : (value) =>
                                    setState(() => _tossForColors = value),
                        ),
                      FilledButton.icon(
                        key: const ValueKey('play-tournament-round'),
                        onPressed: _busy || _reloadFailed ? null : _play,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          run.playing
                              ? 'Resume round'
                              : retry
                              ? 'Rematch this round'
                              : 'Play ${_cup.roundName(run.wonRounds)}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              _cup.isConquest ? 'Conquest route' : 'Tournament bracket',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            Text(
              _cup.isConquest
                  ? 'Defeat each army in order. Each new round starts with its matching animated chess set. Losses and draws keep your conquered realms safe.'
                  : 'Other bot matches are simulated. Byes advance automatically. Pairings stay fixed for this cup.',
            ),
            const SizedBox(height: 8),
            for (var round = 0; round < bracket.length; round++)
              Card(
                child: ExpansionTile(
                  key: ValueKey('tournament-round-$round-${run.wonRounds}'),
                  initiallyExpanded:
                      round == run.wonRounds ||
                      (run.completed && round == bracket.length - 1),
                  title: Text(_cup.roundName(round)),
                  leading: Icon(
                    round < run.wonRounds
                        ? Icons.check_circle
                        : round == run.wonRounds
                        ? Icons.sports_esports
                        : Icons.lock_outline,
                  ),
                  subtitle: Text(
                    round < run.wonRounds
                        ? 'Won · ${run.results[round].length} attempt(s)'
                        : round == run.wonRounds
                        ? 'Current round · ${run.results[round].length} completed attempt(s)'
                        : 'Locked',
                  ),
                  children: round > run.wonRounds
                      ? [
                          const ListTile(
                            title: Text(
                              'Win the previous round to reveal the pairings.',
                            ),
                          ),
                        ]
                      : [
                          for (final pair in bracket[round])
                            ListTile(
                              title: Text(
                                '${_name(pair.first)} vs ${_name(pair.second)}',
                              ),
                              subtitle: Text(
                                pair.winner != null
                                    ? '${_name(pair.winner)} advances${pair.involvesHuman
                                          ? ''
                                          : pair.second == null || pair.first == null
                                          ? ' · Bye'
                                          : ' · Simulated'}'
                                    : retry
                                    ? 'Rematch available'
                                    : 'Awaiting your game',
                              ),
                              leading: Icon(
                                pair.involvesHuman
                                    ? Icons.person
                                    : Icons.smart_toy_outlined,
                              ),
                            ),
                        ],
                ),
              ),
            Card(
              child: ExpansionTile(
                title: Text('Participants (${_cup.opponents.length + 1})'),
                children: [
                  const ListTile(
                    leading: Icon(Icons.person),
                    title: Text('You'),
                    subtitle: Text('Human player'),
                  ),
                  for (final bot in _cup.opponents)
                    ListTile(
                      leading: _cup.isConquest
                          ? Icon(
                              _cup
                                  .armies[_cup.opponents.indexWhere(
                                    (item) => item.id == bot.id,
                                  )]
                                  .icon,
                            )
                          : OnlineAvatarImage(avatarId: bot.avatarId),
                      title: Text(bot.name),
                      subtitle: Text(
                        _cup.isConquest
                            ? 'Adaptive army commander · Computer'
                            : '${bot.difficultyLabel} · Computer',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
