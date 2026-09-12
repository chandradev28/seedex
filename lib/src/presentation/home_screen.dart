import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import 'dialogs.dart';
import 'torrent_detail_screen.dart';
import 'widgets.dart';

enum _TorrentFilter { all, active, seeding }

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.controller, super.key});

  final SeedexController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _TorrentFilter _filter = _TorrentFilter.all;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final records = controller.torrents.where((TorrentRecord item) {
      return switch (_filter) {
        _TorrentFilter.all => true,
        _TorrentFilter.active => item.isActive,
        _TorrentFilter.seeding => item.isSeeding,
      };
    }).toList();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Seedex',
              subtitle: controller.engineRunning
                  ? '${controller.activeCount} active · ${controller.seedingCount} seeding'
                  : 'Your private sharing portfolio',
              action: RoundIconButton(
                icon: CupertinoIcons.add,
                tooltip: 'Add torrent',
                filled: true,
                onPressed: () => showAddTorrentSheet(context, controller),
              ),
            ),
          ),
          if (!controller.networkAllowed)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: _NetworkNotice(controller: controller),
              ),
            ),
          SliverToBoxAdapter(child: _TransferHero(controller: controller)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
              child: CupertinoSlidingSegmentedControl<_TorrentFilter>(
                groupValue: _filter,
                thumbColor: Theme.of(context).cardTheme.color ?? Colors.white,
                onValueChanged: (_TorrentFilter? value) {
                  if (value != null) setState(() => _filter = value);
                },
                children: const <_TorrentFilter, Widget>{
                  _TorrentFilter.all: Padding(
                    padding: EdgeInsets.symmetric(vertical: 9),
                    child: Text('All'),
                  ),
                  _TorrentFilter.active: Padding(
                    padding: EdgeInsets.symmetric(vertical: 9),
                    child: Text('Active'),
                  ),
                  _TorrentFilter.seeding: Padding(
                    padding: EdgeInsets.symmetric(vertical: 9),
                    child: Text('Seeding'),
                  ),
                },
              ),
            ),
          ),
          if (records.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: CupertinoIcons.arrow_down_doc,
                title: controller.torrents.isEmpty ? 'Add your first torrent' : 'Nothing here yet',
                body: controller.torrents.isEmpty
                    ? 'Paste a magnet link or select a .torrent file. Seedex keeps every record on this device.'
                    : 'Try another filter to see your torrents.',
                action: controller.torrents.isEmpty
                    ? FilledButton.icon(
                        onPressed: () => showAddTorrentSheet(context, controller),
                        icon: const Icon(CupertinoIcons.add, size: 18),
                        label: const Text('Add torrent'),
                      )
                    : null,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              sliver: SliverList.separated(
                itemCount: records.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 12),
                itemBuilder: (BuildContext context, int index) {
                  final record = records[index];
                  return _TorrentCard(
                    record: record,
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => TorrentDetailScreen(
                          controller: controller,
                          torrentId: record.id,
                        ),
                      ),
                    ),
                    onToggle: () => record.paused
                        ? controller.resumeTorrent(record.id)
                        : controller.pauseTorrent(record.id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TransferHero extends StatelessWidget {
  const _TransferHero({required this.controller});

  final SeedexController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF1C6FC2), Color(0xFF2783DE), Color(0xFF4B9BE8)],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: SeedexPalette.blue.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(CupertinoIcons.waveform_path, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  'LIVE TRANSFER',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white70,
                        letterSpacing: 0.9,
                      ),
                ),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: controller.activeCount > 0
                        ? const Color(0xFF9FE4BC)
                        : Colors.white54,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: _SpeedValue(
                    icon: CupertinoIcons.arrow_down,
                    value: formatSpeed(controller.totalDownloadRate),
                    label: 'Download',
                  ),
                ),
                Container(width: 1, height: 48, color: Colors.white24),
                const SizedBox(width: 20),
                Expanded(
                  child: _SpeedValue(
                    icon: CupertinoIcons.arrow_up,
                    value: formatSpeed(controller.totalUploadRate),
                    label: 'Upload',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedValue extends StatelessWidget {
  const _SpeedValue({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, color: Colors.white70, size: 15),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _TorrentCard extends StatelessWidget {
  const _TorrentCard({
    required this.record,
    required this.onTap,
    required this.onToggle,
  });

  final TorrentRecord record;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = record.error.isNotEmpty
        ? SeedexPalette.red
        : record.isSeeding
            ? SeedexPalette.green
            : record.paused
                ? SeedexPalette.secondary
                : SeedexPalette.blue;
    return Hero(
      tag: 'torrent-${record.id}',
      child: Material(
        color: theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: theme.dividerColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                ProgressRing(
                  progress: record.progress,
                  color: statusColor,
                  child: Text(
                    '${(record.progress * 100).round()}',
                    style: theme.textTheme.labelMedium?.copyWith(color: statusColor),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        record.displayName,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: <Widget>[
                          StatusPill(label: record.paused ? 'Paused' : record.status, color: statusColor),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              record.sourceDomain.isEmpty ? 'Unknown source' : record.sourceDomain,
                              style: theme.textTheme.labelMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      Row(
                        children: <Widget>[
                          Text('↓ ${formatSpeed(record.downloadRate)}',
                              style: theme.textTheme.labelMedium?.copyWith(color: SeedexPalette.blue)),
                          const SizedBox(width: 12),
                          Text('↑ ${formatSpeed(record.uploadRate)}',
                              style: theme.textTheme.labelMedium?.copyWith(color: SeedexPalette.green)),
                          const Spacer(),
                          Text('R ${formatRatio(record.ratio)}', style: theme.textTheme.labelMedium),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: record.paused ? 'Resume' : 'Pause',
                  onPressed: onToggle,
                  icon: Icon(
                    record.paused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NetworkNotice extends StatelessWidget {
  const _NetworkNotice({required this.controller});

  final SeedexController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SeedexPalette.orange.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SeedexPalette.orange.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(CupertinoIcons.wifi_slash, color: SeedexPalette.orange, size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Transfers are paused by your network policy.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
