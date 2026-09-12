import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import 'dialogs.dart';
import 'widgets.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({required this.controller, super.key});

  final SeedexController controller;

  @override
  Widget build(BuildContext context) {
    final activeGoals = controller.goals
        .where((SeedGoal item) => !item.isComplete)
        .toList();
    final completedGoals = controller.goals
        .where((SeedGoal item) => item.isComplete)
        .toList();
    final sources = <String, int>{};
    for (final torrent in controller.torrents) {
      final source = torrent.sourceDomain.isEmpty
          ? 'Unknown source'
          : torrent.sourceDomain;
      sources.update(
        source,
        (int value) => value + torrent.uploadedBytes,
        ifAbsent: () => torrent.uploadedBytes,
      );
    }
    final sourceEntries = sources.entries.toList()
      ..sort(
        (MapEntry<String, int> a, MapEntry<String, int> b) =>
            b.value.compareTo(a.value),
      );

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Portfolio',
              subtitle: 'Your contribution, stored privately',
              action: RoundIconButton(
                icon: CupertinoIcons.flag_fill,
                tooltip: 'Create goal',
                filled: true,
                onPressed: () => showCreateGoalSheet(context, controller),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _PortfolioHero(controller: controller)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.38,
              children: <Widget>[
                StatTile(
                  label: 'Lifetime uploaded',
                  value: formatBytes(controller.totalUploaded),
                  icon: CupertinoIcons.arrow_up_circle_fill,
                  color: SeedexPalette.green,
                ),
                StatTile(
                  label: '1:1 torrents',
                  value: controller.oneToOneCount.toString(),
                  icon: CupertinoIcons.checkmark_seal_fill,
                  color: SeedexPalette.blue,
                ),
                StatTile(
                  label: 'Completed goals',
                  value: controller.completedGoalCount.toString(),
                  icon: CupertinoIcons.flag_fill,
                  color: SeedexPalette.orange,
                ),
                StatTile(
                  label: 'Seeding time',
                  value: formatDuration(
                    Duration(seconds: controller.totalSeedingSeconds),
                  ),
                  icon: CupertinoIcons.clock_fill,
                  color: SeedexPalette.green,
                ),
              ],
            ),
          ),
          SectionHeader(
            title: 'Active goals',
            trailing: TextButton(
              onPressed: () => showCreateGoalSheet(context, controller),
              child: const Text('New goal'),
            ),
          ),
          if (activeGoals.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyState(
                icon: CupertinoIcons.flag,
                title: 'Set your next milestone',
                body:
                    'Try uploading 1 TB, reaching a 2.0 ratio, or sharing back on 20 torrents.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.separated(
                itemCount: activeGoals.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int index) => _GoalCard(
                  goal: activeGoals[index],
                  current: controller.metricValue(activeGoals[index].metric),
                  onDelete: () => controller.deleteGoal(activeGoals[index].id),
                ),
              ),
            ),
          if (sourceEntries.isNotEmpty) ...<Widget>[
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'Contribution by source'),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.separated(
                itemCount: sourceEntries.length > 6 ? 6 : sourceEntries.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const Divider(),
                itemBuilder: (BuildContext context, int index) {
                  final entry = sourceEntries[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            CupertinoIcons.globe,
                            size: 19,
                            color: SeedexPalette.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          formatBytes(entry.value),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          if (completedGoals.isNotEmpty) ...<Widget>[
            const SliverToBoxAdapter(child: SectionHeader(title: 'Completed')),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverList.separated(
                itemCount: completedGoals.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int index) => _GoalCard(
                  goal: completedGoals[index],
                  current: controller.metricValue(completedGoals[index].metric),
                  onDelete: () =>
                      controller.deleteGoal(completedGoals[index].id),
                ),
              ),
            ),
          ] else
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }
}

class _PortfolioHero extends StatelessWidget {
  const _PortfolioHero({required this.controller});

  final SeedexController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF267857), Color(0xFF46A171)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: SeedexPalette.green.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            ProgressRing(
              progress: (controller.overallRatio / 2).clamp(0, 1),
              size: 84,
              strokeWidth: 8,
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    formatRatio(controller.overallRatio),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'ratio',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Lifetime share ratio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'A weighted ratio based on total payload uploaded and downloaded.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.current,
    required this.onDelete,
  });

  final SeedGoal goal;
  final double current;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = goal.progress(current);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: <Widget>[
          ProgressRing(
            progress: progress,
            color: goal.isComplete ? SeedexPalette.green : SeedexPalette.blue,
            child: Icon(
              goal.isComplete
                  ? CupertinoIcons.check_mark
                  : CupertinoIcons.flag_fill,
              color: goal.isComplete ? SeedexPalette.green : SeedexPalette.blue,
              size: 17,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(goal.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 5),
                GoalProgressLabel(goal: goal, current: current),
                if (goal.deadline != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Due ${compactDate(goal.deadline!)}',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete goal',
            onPressed: onDelete,
            icon: const Icon(CupertinoIcons.ellipsis, size: 20),
          ),
        ],
      ),
    );
  }
}
