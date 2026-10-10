import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain/piece_pack.dart';
import 'features/credits/arena_credit_header.dart';
import 'features/home/home_screen.dart';
import 'features/online/online_lobby_screen.dart';
import 'services/arena_credit_controller.dart';
import 'services/app_color_scheme_controller.dart';
import 'services/player_progress_controller.dart';
import 'services/player_identity_controller.dart';
import 'services/game_invite_links.dart';
import 'services/custom_chess_sets.dart';
import 'services/theme_music.dart';
import 'services/app_diagnostics.dart';
import 'services/online_activity_controller.dart';
import 'theme/app_theme.dart';

class BattleChessArenaApp extends StatefulWidget {
  const BattleChessArenaApp({this.musicOutput, this.incomingLinks, super.key});
  final MusicOutput? musicOutput;
  final Stream<Uri>? incomingLinks;
  @override
  State<BattleChessArenaApp> createState() => _BattleChessArenaAppState();
}

class _BattleChessArenaAppState extends State<BattleChessArenaApp>
    with WidgetsBindingObserver {
  ThemeMusic? _music;
  final _customSets = CustomChessSets();
  final _credits = ArenaCreditController();
  final _progress = PlayerProgressController();
  final _identity = PlayerIdentityController();
  final _appColors = AppColorSchemeController();
  final _activity = OnlineActivityController();
  late final _activityNavigation = OnlineActivityNavigation(_activity);
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _linkSubscription;
  String? _pendingInviteGameId;
  String? _pendingSharedInviteId;
  String? _lastInviteGameId;
  DateTime? _lastInviteReceivedAt;
  final _diagnosticNavigation = DiagnosticNavigationObserver(
    AppDiagnostics.instance,
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _linkSubscription = (widget.incomingLinks ?? AppLinks().uriLinkStream)
        .listen(_handleInviteLink);
    unawaited(_credits.restore());
    unawaited(_progress.restore());
    unawaited(_identity.restore());
    unawaited(_appColors.restore());
    _initializeMusic();
    unawaited(_activity.start());
    unawaited(
      _activity.initializePush(
        (gameId) => _handleInviteLink(
          Uri(
            scheme: 'battlechessarena',
            host: 'join',
            queryParameters: {'game': gameId},
          ),
        ),
      ),
    );
  }

  void _handleInviteLink(Uri uri) {
    final gameId = gameIdFromInviteUri(uri);
    final sharedId = sharedInviteIdFromUri(uri);
    final key = sharedId == null ? gameId : 'invite:$sharedId';
    if (key == null) return;
    final now = DateTime.now();
    if (key == _lastInviteGameId &&
        _lastInviteReceivedAt != null &&
        now.difference(_lastInviteReceivedAt!) < const Duration(seconds: 1)) {
      return;
    }
    _lastInviteGameId = key;
    _lastInviteReceivedAt = now;
    _pendingInviteGameId = gameId;
    _pendingSharedInviteId = sharedId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingInvite());
  }

  void _openPendingInvite() {
    final gameId = _pendingInviteGameId;
    final sharedId = _pendingSharedInviteId;
    final key = sharedId == null ? gameId : 'invite:$sharedId';
    final navigator = _navigatorKey.currentState;
    if (key == null || navigator == null) return;
    _pendingInviteGameId = null;
    _pendingSharedInviteId = null;
    _lastInviteGameId = key;
    navigator
        .push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/online-invite'),
            builder: (_) => OnlineLobbyScreen(
              pack: piecePacks.first,
              initialGameId: gameId,
              initialSharedInviteId: sharedId,
            ),
          ),
        )
        .then((_) {
          if (_lastInviteGameId == key) _lastInviteGameId = null;
        });
  }

  Future<void> _initializeMusic() async {
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {}
    if (!mounted) return;
    final music = ThemeMusic(
      output: widget.musicOutput ?? AssetMusicOutput(),
      muted: preferences?.getBool('musicMuted') ?? false,
      selection: backgroundMusicFromName(
        preferences?.getString(ThemeMusic.selectionKey),
      ),
      saveSelection: (value) async {
        final prefs = preferences ?? await SharedPreferences.getInstance();
        if (!await prefs.setString(ThemeMusic.selectionKey, value.name)) {
          throw StateError('Music preference was not saved');
        }
      },
      saveMuted: (value) async {
        final prefs = preferences ?? await SharedPreferences.getInstance();
        if (!await prefs.setBool('musicMuted', value)) {
          throw StateError('Sound preference was not saved');
        }
      },
    );
    music.setActive(
      WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
    setState(() => _music = music);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _music?.setActive(state == AppLifecycleState.resumed);
    _activity.active = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused) AppDiagnostics.instance.flush();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    _music?.dispose();
    _activity.dispose();
    _customSets.dispose();
    _credits.dispose();
    _progress.dispose();
    _identity.dispose();
    _appColors.dispose();
    super.dispose();
  }

  Widget _activityFrame(Widget child) => ListenableBuilder(
    listenable: _activity,
    builder: (context, _) => Stack(
      children: [
        child,
        if (_activity.alerts.isNotEmpty)
          Positioned(
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            child: FloatingActionButton.small(
              heroTag: 'online-activity',
              key: const ValueKey('online-activity-alerts'),
              tooltip: 'Other games: ${_activity.alerts.length} updates',
              backgroundColor: const Color(0xFF286D83),
              onPressed: _showGameAlerts,
              child: Badge(
                label: Text('${_activity.alerts.length}'),
                child: const Icon(
                  Icons.notifications_active,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  void _showGameAlerts() {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListenableBuilder(
          listenable: _activity,
          builder: (context, _) => ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Online game updates')),
              for (final alert in _activity.alerts)
                ListTile(
                  leading: const Icon(Icons.sports_esports),
                  title: Text(
                    alert.game.state.opponentFor(alert.game.seat).name,
                  ),
                  subtitle: Text(alert.message),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _activity.viewGame(alert.game.gameId);
                    _navigatorKey.currentState?.push(
                      MaterialPageRoute<void>(
                        builder: (_) => OnlineLobbyScreen(
                          pack: piecePacks.first,
                          initialGameId: alert.game.gameId,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _appColors,
    builder: (context, _) => MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Battle Chess Arena',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(_appColors.preset),
      navigatorObservers: [
        musicRoutes,
        _diagnosticNavigation,
        _activityNavigation,
      ],
      builder: (context, child) => AppColorSchemeScope(
        controller: _appColors,
        child: PlayerIdentityScope(
          controller: _identity,
          child: PlayerProgressScope(
            controller: _progress,
            child: ArenaCreditScope(
              controller: _credits,
              child: CustomChessSetScope(
                controller: _customSets,
                child: _music == null
                    ? ArenaCreditAppFrame(child: _activityFrame(child!))
                    : MusicScope(
                        controller: _music!,
                        child: ArenaCreditAppFrame(
                          child: _activityFrame(child!),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    ),
  );
}
