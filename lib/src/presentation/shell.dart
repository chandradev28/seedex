import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'activity_screen.dart';
import 'dialogs.dart';
import 'home_screen.dart';
import 'portfolio_screen.dart';
import 'settings_screen.dart';

class SeedexShell extends StatefulWidget {
  const SeedexShell({required this.controller, super.key});

  final SeedexController controller;

  @override
  State<SeedexShell> createState() => _SeedexShellState();
}

class _SeedexShellState extends State<SeedexShell> {
  int _index = 0;
  bool _handlingOverlay = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerEvent);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _handleControllerEvent(),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerEvent);
    super.dispose();
  }

  void _handleControllerEvent() {
    if (!mounted || _handlingOverlay) return;
    final incoming = widget.controller.incomingTorrent;
    final celebration = widget.controller.celebration;
    if (incoming != null) {
      _handlingOverlay = true;
      final value = widget.controller.consumeIncomingTorrent();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || value == null) return;
        await showAddTorrentSheet(
          context,
          widget.controller,
          initialMagnet: value.magnet,
          initialTorrentFile: value.torrentFile,
          initialSourceUrl: value.sourceUrl,
        );
        _handlingOverlay = false;
      });
    } else if (celebration.isNotEmpty) {
      widget.controller.clearCelebration();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: <Widget>[
                const Icon(CupertinoIcons.sparkles, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(celebration)),
              ],
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(controller: widget.controller),
      PortfolioScreen(controller: widget.controller),
      ActivityScreen(controller: widget.controller),
      SettingsScreen(controller: widget.controller),
    ];
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(key: ValueKey<int>(_index), child: pages[_index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(CupertinoIcons.arrow_down_circle),
            selectedIcon: Icon(CupertinoIcons.arrow_down_circle_fill),
            label: 'Torrents',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.chart_pie),
            selectedIcon: Icon(CupertinoIcons.chart_pie_fill),
            label: 'Portfolio',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.waveform_path_ecg),
            selectedIcon: Icon(CupertinoIcons.waveform_path_ecg),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.settings),
            selectedIcon: Icon(CupertinoIcons.settings_solid),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
