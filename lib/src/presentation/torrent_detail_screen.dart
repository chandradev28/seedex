import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import 'widgets.dart';

class TorrentDetailScreen extends StatelessWidget {
  const TorrentDetailScreen({
    required this.controller,
    required this.torrentId,
    super.key,
  });

  final SeedexController controller;
  final String torrentId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final matching = controller.torrents.where(
          (TorrentRecord item) => item.id == torrentId,
        );
        if (matching.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: CupertinoIcons.trash,
              title: 'Torrent removed',
              body: 'This torrent is no longer in your Seedex portfolio.',
            ),
          );
        }
        return _TorrentDetailBody(
          controller: controller,
          record: matching.first,
        );
      },
    );
  }
}

class _TorrentDetailBody extends StatelessWidget {
  const _TorrentDetailBody({required this.controller, required this.record});

  final SeedexController controller;
  final TorrentRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(CupertinoIcons.back),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'More actions',
            onPressed: () => _showActions(context),
            icon: const Icon(CupertinoIcons.ellipsis_circle),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
          children: <Widget>[
            Hero(
              tag: 'torrent-${record.id}',
              child: Material(
                color: theme.cardTheme.color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(color: theme.dividerColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: <Widget>[
                      ProgressRing(
                        progress: record.progress,
                        size: 118,
                        strokeWidth: 10,
                        color: record.isSeeding
                            ? SeedexPalette.green
                            : SeedexPalette.blue,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              formatPercent(record.progress),
                              style: theme.textTheme.headlineMedium,
                            ),
                            Text(
                              record.paused ? 'Paused' : record.status,
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        record.displayName,
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        record.totalWanted > 0
                            ? '${formatBytes(record.totalDone)} of ${formatBytes(record.totalWanted)}'
                            : 'Waiting for torrent metadata',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.labelMedium?.color,
                        ),
                      ),
                      if (record.error.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          record.error,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: SeedexPalette.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _PrimaryControl(
                    icon: record.paused
                        ? CupertinoIcons.play_fill
                        : CupertinoIcons.pause_fill,
                    label: record.paused ? 'Resume' : 'Pause',
                    onPressed: () => record.paused
                        ? controller.resumeTorrent(record.id)
                        : controller.pauseTorrent(record.id),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PrimaryControl(
                    icon: CupertinoIcons.refresh,
                    label: 'Recheck',
                    onPressed: () => controller.recheckTorrent(record.id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Transfer', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                StatTile(
                  label: 'Download',
                  value: formatSpeed(record.downloadRate),
                  icon: CupertinoIcons.arrow_down,
                ),
                StatTile(
                  label: 'Upload',
                  value: formatSpeed(record.uploadRate),
                  icon: CupertinoIcons.arrow_up,
                  color: SeedexPalette.green,
                ),
                StatTile(
                  label: 'Peers',
                  value: record.peers.toString(),
                  icon: CupertinoIcons.person_2_fill,
                ),
                StatTile(
                  label: 'Seeds',
                  value: record.seeds.toString(),
                  icon: CupertinoIcons.cloud_upload_fill,
                  color: SeedexPalette.green,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Sharing goal', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        '${record.ratioTarget.toStringAsFixed(record.ratioTarget % 1 == 0 ? 0 : 1)}:1 target',
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Text(
                        'Ratio ${formatRatio(record.ratio)}',
                        style: theme.textTheme.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: record.ratioGoalProgress,
                      minHeight: 8,
                      backgroundColor: theme.dividerColor,
                      color: SeedexPalette.green,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    record.remainingForRatio == 0 && record.ratioGoalBytes > 0
                        ? 'Sharing target reached'
                        : '${formatBytes(record.uploadedBytes)} uploaded · ${formatBytes(record.remainingForRatio)} remaining',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Source', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          CupertinoIcons.globe,
                          color: SeedexPalette.blue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              record.sourceDomain.isEmpty
                                  ? 'Unknown source'
                                  : record.sourceDomain,
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              _confidenceLabel(record.sourceConfidence),
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (record.trackers.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 15),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'TRACKER NETWORKS',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: record.trackers
                          .take(5)
                          .map(
                            (String tracker) => StatusPill(
                              label: tracker,
                              color: SeedexPalette.secondary,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _confidenceLabel(SourceConfidence confidence) => switch (confidence) {
    SourceConfidence.exact => 'Exact · shared from the source page',
    SourceConfidence.manual => 'Manually provided',
    SourceConfidence.tracker => 'Inferred from tracker metadata',
    SourceConfidence.unknown => 'Original website unavailable',
  };

  Future<void> _showActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(CupertinoIcons.refresh),
                title: const Text('Recheck downloaded data'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  controller.recheckTorrent(record.id);
                },
              ),
              ListTile(
                leading: const Icon(
                  CupertinoIcons.trash,
                  color: SeedexPalette.red,
                ),
                title: const Text('Remove from Seedex'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmRemoval(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemoval(BuildContext context) async {
    var deleteFiles = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, void Function(void Function()) setState) {
          return AlertDialog(
            title: const Text('Remove torrent?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'The portfolio record will be removed. This cannot be undone.',
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Also delete downloaded files'),
                  value: deleteFiles,
                  onChanged: (bool? value) =>
                      setState(() => deleteFiles = value ?? false),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: SeedexPalette.red),
                ),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed == true) {
      await controller.removeTorrent(record.id, deleteFiles: deleteFiles);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _PrimaryControl extends StatelessWidget {
  const _PrimaryControl({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
    );
  }
}
