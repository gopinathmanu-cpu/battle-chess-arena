// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/beta_app_info.dart';
import '../../services/theme_music.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({this.appInfo, super.key});

  final BetaAppInfo? appInfo;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  BetaAppInfo? _info;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = widget.appInfo ?? await BetaAppInfo.load();
    if (mounted) setState(() => _info = info);
  }

  Future<void> _copySource() async {
    try {
      await Clipboard.setData(const ClipboardData(text: BetaAppInfo.sourceUrl));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Source link copied')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not copy the source link.')),
        );
      }
    }
  }

  Future<void> _showNotices() async {
    try {
      final notices = await rootBundle.loadString('THIRD_PARTY_NOTICES.md');
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Third-party notices')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SelectableText(notices),
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notices could not be opened.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('About'), actions: const [MusicButton()]),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Battle Chess Arena',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          _info == null
              ? 'Reading app version…'
              : 'Version ${_info!.version} (${_info!.build})',
          key: const ValueKey('app-build-info'),
        ),
        const SizedBox(height: 20),
        const Text(
          'Choose your chess set, play locally, challenge the computer, or meet friends online.',
          style: TextStyle(fontSize: 17, height: 1.4),
        ),
        const Divider(height: 40),
        const Text(
          'Open source & licences',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Original code and artwork are GPL-3.0-or-later. Dependency licences remain with their authors.',
        ),
        const SizedBox(height: 10),
        const SelectableText(BetaAppInfo.sourceUrl),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: _copySource,
              child: const Text('Copy source link'),
            ),
            TextButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'Battle Chess Arena',
                applicationVersion: _info == null
                    ? null
                    : '${_info!.version} (${_info!.build})',
              ),
              child: const Text('Open-source licences'),
            ),
            TextButton(
              onPressed: _showNotices,
              child: const Text('Third-party notices'),
            ),
          ],
        ),
      ],
    ),
  );
}
