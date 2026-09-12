import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/home/home_screen.dart';
import 'services/theme_music.dart';
import 'theme/app_theme.dart';

class BattleChessArenaApp extends StatefulWidget {
  const BattleChessArenaApp({this.musicOutput, super.key});
  final MusicOutput? musicOutput;
  @override
  State<BattleChessArenaApp> createState() => _BattleChessArenaAppState();
}

class _BattleChessArenaAppState extends State<BattleChessArenaApp>
    with WidgetsBindingObserver {
  ThemeMusic? _music;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeMusic();
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
      saveMuted: (value) async {
        await preferences?.setBool('musicMuted', value);
      },
    );
    music.setActive(
      WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
    setState(() => _music = music);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _music?.setActive(state == AppLifecycleState.resumed);
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _music?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Battle Chess Arena',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    navigatorObservers: [musicRoutes],
    builder: (context, child) => _music == null
        ? child!
        : MusicScope(controller: _music!, child: child!),
    home: const HomeScreen(),
  );
}
