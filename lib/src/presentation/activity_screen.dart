import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import 'widgets.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({required this.controller, super.key});

  final SeedexController controller;

  @override
  Widget build(BuildContext context) {
    final samples = controller.activity.length > 60
        ? controller.activity.sublist(controller.activity.length - 60)
        : controller.activity;
    final peakDown = samples.fold<int>(
      0,
      (int value, ActivitySample item) => item.downloadRate > value ? item.downloadRate : value,
    );
    final peakUp = samples.fold<int>(
      0,
      (int value, ActivitySample item) => item.uploadRate > value ? item.uploadRate : value,
    );

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: <Widget>[
          const SliverToBoxAdapter(
            child: PageHeader(
              title: 'Activity',
              subtitle: 'Recent transfer speed on this device',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        _Legend(color: SeedexPalette.blue, label: 'Download'),
                        const SizedBox(width: 16),
                        _Legend(color: SeedexPalette.green, label: 'Upload'),
                        const Spacer(),
                        Text('Last 10 min', style: Theme.of(context).textTheme.labelMedium),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SpeedChart(samples: samples),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.4,
              children: <Widget>[
                StatTile(
                  label: 'Peak download',
                  value: formatSpeed(peakDown),
                  icon: CupertinoIcons.arrow_down_circle_fill,
                ),
                StatTile(
                  label: 'Peak upload',
                  value: formatSpeed(peakUp),
                  icon: CupertinoIcons.arrow_up_circle_fill,
                  color: SeedexPalette.green,
                ),
                StatTile(
                  label: 'Downloaded',
                  value: formatBytes(controller.totalDownloaded),
                  icon: CupertinoIcons.tray_arrow_down_fill,
                ),
                StatTile(
                  label: 'Uploaded',
                  value: formatBytes(controller.totalUploaded),
                  icon: CupertinoIcons.tray_arrow_up_fill,
                  color: SeedexPalette.green,
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SectionHeader(title: 'How activity is measured')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(CupertinoIcons.lock_fill, color: Theme.of(context).colorScheme.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Samples are saved locally every ten seconds. Payload totals exclude hosted analytics and are never uploaded by Seedex.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
