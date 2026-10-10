// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../domain/cinematic_replay.dart';
import '../../domain/animated_army_theme.dart';
import '../../domain/piece_pack.dart';
import '../../services/game_history_storage.dart';
import '../../services/theme_music.dart';
import '../play/board_appearance.dart';
import '../play/chess_widgets.dart';
import '../play/neon_cinematic_screen.dart';

typedef HistoryCinematicBuilder = Widget Function(GameHistoryRecord record);

enum _HistoryFilter {
  all('Show All', null),
  completed('Completed', GameHistoryStatus.completed),
  unfinished('Unfinished', GameHistoryStatus.unfinished);

  const _HistoryFilter(this.label, this.status);
  final String label;
  final GameHistoryStatus? status;
}

/// Browses durable recordings without exposing a live session or reward action.
class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({this.storage, this.cinematicBuilder, super.key});
  final GameHistoryStorage? storage;
  final HistoryCinematicBuilder? cinematicBuilder;

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  late final _storage = widget.storage ?? GameHistoryStorage();
  GameHistorySnapshot? _snapshot;
  bool _loading = true;
  bool _error = false;
  bool _opening = false;
  int _loadRevision = 0;
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final revision = ++_loadRevision;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final snapshot = await _storage.loadSnapshot();
      if (!mounted || revision != _loadRevision) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || revision != _loadRevision) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _open(GameHistoryRecord record) async {
    if (_opening) return;
    _opening = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/game-history-detail'),
          builder: (_) => GameHistoryDetailScreen(
            record: record,
            cinematicBuilder: widget.cinematicBuilder,
          ),
        ),
      );
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('game-history-screen'),
    appBar: AppBar(
      title: const Text('Game history'),
      actions: [
        IconButton(
          key: const ValueKey('history-refresh'),
          tooltip: 'Refresh history',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
        const MusicButton(),
      ],
    ),
    body: SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
          ? _HistoryMessage(
              icon: Icons.history_toggle_off,
              title: 'History could not be loaded',
              message: 'Your saved recordings have been kept. Try again.',
              action: FilledButton(
                key: const ValueKey('history-retry'),
                onPressed: _load,
                child: const Text('Try again'),
              ),
            )
          : _list(),
    ),
  );

  Widget _list() {
    final snapshot = _snapshot!;
    final records = snapshot.records.toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final visible = records
        .where(
          (record) => _filter.status == null || record.status == _filter.status,
        )
        .toList(growable: false);
    return ListView(
      key: const ValueKey('history-records'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${visible.length} ${visible.length == 1 ? 'game' : 'games'}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          _filter == _HistoryFilter.all
              ? 'Completed and unfinished games · newest first'
              : '${_filter.label} games · newest first',
        ),
        const SizedBox(height: 12),
        Semantics(
          label: 'Filter game history',
          container: true,
          child: Wrap(
            key: const ValueKey('history-filters'),
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in _HistoryFilter.values)
                ChoiceChip(
                  key: ValueKey('history-filter-${filter.name}'),
                  label: Text(filter.label),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (snapshot.unavailable.isNotEmpty) ...[
          _UnavailableNotice(count: snapshot.unavailable.length),
          const SizedBox(height: 12),
        ],
        if (visible.isEmpty)
          _HistoryMessage(
            scrollable: false,
            icon: Icons.history,
            title: records.isEmpty
                ? snapshot.unavailable.isEmpty
                      ? 'No games saved yet'
                      : 'No replayable games'
                : _filter == _HistoryFilter.completed
                ? 'No completed games yet'
                : 'No unfinished games',
            message: records.isEmpty
                ? snapshot.unavailable.isEmpty
                      ? 'Your played games will appear here with their recorded moves.'
                      : 'Saved recordings with unavailable moves are listed below.'
                : 'Choose Show All to view your other recordings.',
          ),
        for (final record in visible)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            key: ValueKey('history-record-${record.id}'),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _open(record),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            record.opponentLabel,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      record.resultTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 7,
                      children: [
                        _StatusBadge(record: record),
                        Text(record.modeLabel),
                        Text('${(record.moves.length + 1) ~/ 2} moves'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_themeLabel(record)),
                    const SizedBox(height: 5),
                    Text(
                      _dateLabel(record.recordedAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        for (final record in snapshot.unavailable)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (record.resultTitle != null) ...[
                    const SizedBox(height: 6),
                    Text(record.resultTitle!),
                  ],
                  if (record.completedAt != null) ...[
                    const SizedBox(height: 6),
                    Text(_dateLabel(record.completedAt!)),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Replay unavailable. This saved recording has been kept.',
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class GameHistoryDetailScreen extends StatefulWidget {
  const GameHistoryDetailScreen({
    required this.record,
    this.cinematicBuilder,
    super.key,
  });
  final GameHistoryRecord record;
  final HistoryCinematicBuilder? cinematicBuilder;

  @override
  State<GameHistoryDetailScreen> createState() =>
      _GameHistoryDetailScreenState();
}

class _GameHistoryDetailScreenState extends State<GameHistoryDetailScreen> {
  CinematicReplay? _replay;
  int _ply = 0;
  bool _openingMovie = false;
  GameHistoryRecord get _record => widget.record;

  @override
  void initState() {
    super.initState();
    try {
      final replay = CinematicReplay.fromMoves(
        moves: _record.moves,
        resultTitle: _record.resultTitle,
      );
      if (replay.finalPosition.fen != _record.finalFen) {
        throw const FormatException('Recorded final position disagrees');
      }
      _replay = replay;
      _ply = replay.totalPlies;
    } catch (_) {
      // Keep metadata visible even when a stale imported recording is invalid.
    }
  }

  Position get _position =>
      _ply == 0 ? _replay!.initialPosition : _replay!.scenes[_ply - 1].after;
  CinematicReplayScene? get _scene =>
      _ply == 0 ? null : _replay!.scenes[_ply - 1];

  void _seek(int ply) =>
      setState(() => _ply = ply.clamp(0, _replay!.totalPlies));

  Future<void> _watchMovie() async {
    if (_openingMovie || _replay == null) return;
    setState(() => _openingMovie = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/game-history-cinematic'),
          builder: (_) =>
              widget.cinematicBuilder?.call(_record) ??
              NeonCinematicScreen(
                moves: _record.moves,
                classicStyle: _record.classicStyle,
                theme: _recordArmyTheme(_record) ?? AnimatedArmyTheme.neon,
                resultTitle: _record.resultTitle,
                playerSide: _record.mode == GameHistoryMode.local
                    ? null
                    : _record.humanSide,
              ),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingMovie = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('game-history-detail'),
    appBar: AppBar(
      title: const Text('Recorded game'),
      actions: const [MusicButton()],
    ),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final landscape = box.maxWidth >= 600 && box.maxWidth > box.maxHeight;
          final boardSize = math.min(
            420.0,
            landscape
                ? math.max(
                    110.0,
                    math.min(box.maxWidth * .47 - 32, box.maxHeight - 108),
                  )
                : box.maxWidth - 32,
          );
          if (_replay == null) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _summary(),
                const SizedBox(height: 20),
                const _HistoryMessage(
                  icon: Icons.info_outline,
                  title: 'Replay unavailable',
                  message:
                      'The saved moves could not be verified. The recorded result has been kept.',
                ),
              ],
            );
          }
          if (landscape) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('history-board-scroll'),
                    padding: const EdgeInsets.all(16),
                    child: _board(boardSize),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('history-summary-scroll'),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _summary(),
                        const SizedBox(height: 16),
                        _movieButton(),
                        const SizedBox(height: 20),
                        _moves(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          return SingleChildScrollView(
            key: const ValueKey('history-detail-scroll'),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summary(),
                const SizedBox(height: 18),
                _board(boardSize),
                const SizedBox(height: 18),
                _movieButton(),
                const SizedBox(height: 24),
                _moves(),
              ],
            ),
          );
        },
      ),
    ),
  );

  Widget _summary() => Column(
    key: const ValueKey('history-record-summary'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _record.resultTitle,
        key: const ValueKey('history-recorded-result'),
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          _StatusBadge(record: _record),
          Text(_record.modeLabel),
        ],
      ),
      const SizedBox(height: 10),
      Text('${_record.whiteName} · White\n${_record.blackName} · Black'),
      const SizedBox(height: 8),
      Text(_record.opponentLabel),
      const SizedBox(height: 6),
      Text(_dateLabel(_record.recordedAt)),
      const SizedBox(height: 6),
      Text(_themeLabel(_record)),
      if (_record.status == GameHistoryStatus.unfinished) ...[
        const SizedBox(height: 8),
        const Text(
          'Recorded moves so far. This game was unfinished when saved.',
        ),
      ],
    ],
  );

  Widget _board(double size) {
    final custom =
        _record.whiteCustomSetId != null || _record.blackCustomSetId != null;
    final look = BoardAppearance(
      white: _pack(_record.whitePackId),
      black: _pack(_record.blackPackId),
      board: _pack(_record.boardPackId),
      standardPieces: _record.classicPieces || custom,
      classicStyle: _record.classicStyle,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: size,
          child: AbsorbPointer(
            child: ChessBoard(
              key: const ValueKey('history-replay-board'),
              position: _position,
              selected: null,
              legalTargets: const {},
              accent: look.board.accent,
              appearance: look,
              lastMoveFrom: _scene?.source,
              lastMoveTo: _scene?.target,
              onSquareTap: (_) {},
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          _ply == 0
              ? 'Opening position'
              : 'Move ${_scene!.moveNumber} · ${_scene!.side == Side.white ? 'White' : 'Black'} · ${_scene!.san}',
          key: const ValueKey('history-position-label'),
          textAlign: TextAlign.center,
        ),
        if (custom) ...[
          const SizedBox(height: 6),
          const Text(
            'Standard pieces show this custom-set recording.',
            textAlign: TextAlign.center,
          ),
        ],
        Slider(
          key: const ValueKey('history-position-slider'),
          value: _ply.toDouble(),
          min: 0,
          max: _replay!.totalPlies.toDouble(),
          divisions: _replay!.totalPlies > 0 ? _replay!.totalPlies : null,
          label: 'Position $_ply of ${_replay!.totalPlies}',
          onChanged: _replay!.totalPlies > 0
              ? (value) => _seek(value.round())
              : null,
        ),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            IconButton(
              key: const ValueKey('history-first'),
              tooltip: 'Opening position',
              onPressed: _ply > 0 ? () => _seek(0) : null,
              icon: const Icon(Icons.first_page),
            ),
            IconButton(
              key: const ValueKey('history-previous'),
              tooltip: 'Previous move',
              onPressed: _ply > 0 ? () => _seek(_ply - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              key: const ValueKey('history-next'),
              tooltip: 'Next move',
              onPressed: _ply < _replay!.totalPlies
                  ? () => _seek(_ply + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              key: const ValueKey('history-last'),
              tooltip: 'Last recorded position',
              onPressed: _ply < _replay!.totalPlies
                  ? () => _seek(_replay!.totalPlies)
                  : null,
              icon: const Icon(Icons.last_page),
            ),
          ],
        ),
      ],
    );
  }

  Widget _movieButton() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FilledButton.icon(
        key: const ValueKey('history-watch-cinematic'),
        onPressed: _openingMovie ? null : _watchMovie,
        icon: const Icon(Icons.movie_outlined),
        label: const Text('Watch cinematic'),
      ),
      if (_recordArmyTheme(_record) == null) ...[
        const SizedBox(height: 8),
        const Text(
          'Neon Dominion film interpretation',
          key: ValueKey('history-film-interpretation'),
        ),
      ],
      if (_record.status == GameHistoryStatus.unfinished) ...[
        const SizedBox(height: 6),
        const Text('Retells the recorded moves so far.'),
      ],
    ],
  );

  Widget _moves() {
    final scenes = _replay!.scenes;
    if (scenes.isEmpty) return const Text('No moves were recorded.');
    Widget cell(CinematicReplayScene? scene) => scene == null
        ? const SizedBox.shrink()
        : InkWell(
            key: ValueKey('history-move-${scene.ply}'),
            onTap: () => _seek(scene.ply),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              color: _ply == scene.ply
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: .16)
                  : null,
              child: Text(
                scene.san,
                style: TextStyle(
                  fontWeight: _ply == scene.ply
                      ? FontWeight.w800
                      : FontWeight.w500,
                ),
              ),
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Move list', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Table(
          key: const ValueKey('history-move-list'),
          columnWidths: const {
            0: FixedColumnWidth(32),
            1: FlexColumnWidth(),
            2: FlexColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            const TableRow(
              children: [
                Text('#'),
                Padding(padding: EdgeInsets.all(8), child: Text('White')),
                Padding(padding: EdgeInsets.all(8), child: Text('Black')),
              ],
            ),
            for (var index = 0; index < scenes.length; index += 2)
              TableRow(
                children: [
                  Text('${index ~/ 2 + 1}'),
                  cell(scenes[index]),
                  cell(index + 1 < scenes.length ? scenes[index + 1] : null),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.record});
  final GameHistoryRecord record;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      record.statusLabel,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('history-unavailable-notice'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '$count ${count == 1 ? 'recording is' : 'recordings are'} unavailable for replay. Saved data has been kept.',
    ),
  );
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.scrollable = true,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool scrollable;
  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
    return scrollable ? SingleChildScrollView(child: content) : content;
  }
}

PiecePack _pack(PiecePackId id) =>
    piecePacks.singleWhere((pack) => pack.id == id);
AnimatedArmyTheme? _recordArmyTheme(GameHistoryRecord record) =>
    record.whiteCustomSetId == null &&
        record.blackCustomSetId == null &&
        record.whitePackId == record.blackPackId
    ? AnimatedArmyTheme.forPack(record.whitePackId)
    : null;
String _themeLabel(GameHistoryRecord record) {
  if (record.classicPieces) return 'Classic · ${record.classicStyle.label}';
  final white = record.whiteCustomName ?? _pack(record.whitePackId).name;
  final black = record.blackCustomName ?? _pack(record.blackPackId).name;
  return white == black ? white : 'White: $white · Black: $black';
}

String _dateLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = date.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
