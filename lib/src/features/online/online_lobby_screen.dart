// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import 'online_game_screen.dart';
import '../play/board_appearance.dart';
import '../../services/theme_music.dart';

import '../../domain/piece_pack.dart';
import '../../services/online_match_client.dart';

class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({required this.pack, this.client, super.key});
  final PiecePack pack;
  final OnlineMatchClient? client;

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  static const _configuredEndpoint = String.fromEnvironment(
    'ONLINE_SERVER_URL',
    defaultValue: 'wss://battle-chess-arena-server.onrender.com',
  );
  late final _client = widget.client ?? OnlineMatchClient();
  final _endpoint = TextEditingController(text: _configuredEndpoint);
  bool _openedGame = false;
  final _gameId = TextEditingController();
  _OnlineTimeControl _timeControl = _timeControls.last;

  static const _timeControls = <_OnlineTimeControl>[
    _OnlineTimeControl('3 min', 180000, 0),
    _OnlineTimeControl('5 min', 300000, 0),
    _OnlineTimeControl('10 min', 600000, 0),
  ];

  @override
  void initState() {
    super.initState();
    _client.addListener(_refresh);
  }

  @override
  void dispose() {
    _client.removeListener(_refresh);
    if (widget.client == null) _client.dispose();
    _endpoint.dispose();
    _gameId.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
    if (!_openedGame &&
        _client.state?.status == 'active' &&
        _client.connected) {
      _openedGame = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openGame();
      });
    }
  }

  void _openGame() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnlineGameScreen(client: _client, pack: widget.pack),
      ),
    );
  }

  Future<void> _connect() async {
    final uri = Uri.tryParse(_endpoint.text.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'ws' && uri.scheme != 'wss')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid ws:// or wss:// endpoint')),
      );
      return;
    }
    await _client.connect(uri);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.pack.accent;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Match Lobby'),
        actions: const [MusicButton()],
      ),
      body: WorldBackdrop(
        pack: widget.pack,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: .28),
                    const Color(0xFF151725),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MULTIPLAYER ARENA',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Find an opponent automatically or create a private room for a friend. The board opens when both players are ready.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _endpoint,
              decoration: const InputDecoration(
                labelText: 'WebSocket endpoint',
                helperText: 'Secure online multiplayer server',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _client.connection == MatchConnection.disconnected
                  ? _connect
                  : null,
              icon: const Icon(Icons.link),
              label: Text(
                _client.connection == MatchConnection.disconnected
                    ? 'Connect'
                    : _client.connectionLabel,
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<_OnlineTimeControl>(
              key: const ValueKey('online-time-control'),
              initialValue: _timeControl,
              decoration: const InputDecoration(
                labelText: 'Time control',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
              items: [
                for (final control in _timeControls)
                  DropdownMenuItem(value: control, child: Text(control.label)),
              ],
              onChanged: _client.gameId == null
                  ? (control) {
                      if (control != null) {
                        setState(() => _timeControl = control);
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('quick-match-button'),
              onPressed:
                  _client.connected && !_client.busy && _client.gameId == null
                  ? () => _client.quickMatch(
                      baseMs: _timeControl.baseMs,
                      incrementMs: _timeControl.incrementMs,
                    )
                  : null,
              icon: const Icon(Icons.bolt),
              label: Text('Quick Match · ${_timeControl.label}'),
            ),
            if (_client.searchingForOpponent) ...[
              const SizedBox(height: 18),
              Card(
                key: const ValueKey('matchmaking-waiting'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      LinearProgressIndicator(color: accent),
                      const SizedBox(height: 12),
                      const Text(
                        'Searching for an opponent…',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text('${_timeControl.label} · Your seat is reserved'),
                      TextButton(
                        onPressed: _client.busy
                            ? null
                            : _client.cancelMatchmaking,
                        child: const Text('Cancel search'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_client.gameId == null) ...[
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('PRIVATE ROOM'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _client.connected && !_client.busy
                    ? () => _client.createGame(
                        baseMs: _timeControl.baseMs,
                        incrementMs: _timeControl.incrementMs,
                      )
                    : null,
                icon: const Icon(Icons.add),
                label: Text('Create ${_timeControl.label} private room'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _gameId,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Friend’s Game ID',
                  prefixIcon: Icon(Icons.key),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed:
                    _client.connected &&
                        !_client.busy &&
                        _gameId.text.trim().isNotEmpty
                    ? () => _client.joinGame(_gameId.text)
                    : null,
                icon: const Icon(Icons.login),
                label: const Text('Join private room'),
              ),
            ],
            if (_client.gameId != null && !_client.searchingForOpponent) ...[
              const SizedBox(height: 22),
              SelectableText(
                'Game ID: ${_client.gameId}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text('Seat: ${_client.seat == 'w' ? 'White' : 'Black'}'),
              Text('Status: ${_client.state?.status ?? 'waiting'}'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => copyGameId(context, _client.gameId),
                icon: const Icon(Icons.copy),
                label: const Text('Copy Game ID to share'),
              ),
              if (_client.state?.status != 'waiting')
                FilledButton(
                  onPressed: _openGame,
                  child: const Text('Return to game'),
                ),
              const Text(
                'Keep this lobby open to retain your seat. Returning home or closing the app forgets it.',
                style: TextStyle(color: Colors.white60),
              ),
            ],
            if (_client.error != null) ...[
              const SizedBox(height: 16),
              Text(
                _client.error!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OnlineTimeControl {
  const _OnlineTimeControl(this.label, this.baseMs, this.incrementMs);

  final String label;
  final int baseMs;
  final int incrementMs;
}
