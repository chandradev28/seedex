import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.controller, super.key});

  final SeedexController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: SeedexPalette.blue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  CupertinoIcons.arrow_up_arrow_down,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 28),
              Text('Share better.', style: theme.textTheme.displaySmall),
              const SizedBox(height: 10),
              Text(
                'Seedex turns torrent sharing into clear, private progress—right on your Android device.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.textTheme.labelMedium?.color,
                ),
              ),
              const SizedBox(height: 34),
              const _Feature(
                icon: CupertinoIcons.lock_shield,
                title: 'Private by design',
                body: 'No account, hosted database, analytics, or cloud profile.',
              ),
              const _Feature(
                icon: CupertinoIcons.chart_bar_alt_fill,
                title: 'A real contribution portfolio',
                body: 'Track payload uploaded, 1:1 ratios, seeding time, and custom goals.',
              ),
              const _Feature(
                icon: CupertinoIcons.info_circle_fill,
                title: 'Your IP is visible to peers',
                body: 'Peer-to-peer sharing is public to the swarm. Seed only content you may distribute.',
              ),
              const Spacer(),
              Semantics(
                checked: _confirmed,
                label: 'Confirm legal sharing responsibility',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _confirmed = !_confirmed),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _confirmed
                                ? SeedexPalette.blue
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: _confirmed
                                  ? SeedexPalette.blue
                                  : Theme.of(context).dividerColor,
                              width: 1.5,
                            ),
                          ),
                          child: _confirmed
                              ? const Icon(CupertinoIcons.check_mark,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'I will only download and seed content I have permission to share.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _confirmed ? widget.controller.acceptNotice : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: SeedexPalette.blue,
                    disabledBackgroundColor: SeedexPalette.surfaceStrong,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: SeedexPalette.blueSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: SeedexPalette.blue, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.labelMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
