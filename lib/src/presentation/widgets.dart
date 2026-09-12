import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../domain/models.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.displaySmall),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.labelMedium?.color,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.filled = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final color = filled ? Colors.white : Theme.of(context).colorScheme.primary;
    final background = filled
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.11);
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip ?? '',
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Ink(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.progress,
    this.size = 58,
    this.strokeWidth = 6,
    this.color,
    this.child,
    super.key,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress.clamp(0, 1)),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? staticChild) {
        return SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: value,
              color: color ?? Theme.of(context).colorScheme.primary,
              trackColor: Theme.of(context).dividerColor,
              strokeWidth: strokeWidth,
            ),
            child: Center(child: staticChild),
          ),
        );
      },
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas
      ..drawCircle(
        center,
        radius,
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      )
      ..drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth,
      );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.color = SeedexPalette.blue,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 16),
          Text(value, style: theme.textTheme.titleLarge),
          const SizedBox(height: 3),
          Text(
            label,
            style: theme.textTheme.labelMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.color,
    this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 42, 36, 24),
      child: Column(
        children: <Widget>[
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, size: 30, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.labelMedium?.color,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...<Widget>[const SizedBox(height: 22), action!],
        ],
      ),
    );
  }
}

class SpeedChart extends StatelessWidget {
  const SpeedChart({required this.samples, this.height = 170, super.key});

  final List<ActivitySample> samples;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SpeedChartPainter(
          samples: samples,
          downloadColor: SeedexPalette.blue,
          uploadColor: SeedexPalette.green,
          gridColor: Theme.of(context).dividerColor,
        ),
      ),
    );
  }
}

class _SpeedChartPainter extends CustomPainter {
  const _SpeedChartPainter({
    required this.samples,
    required this.downloadColor,
    required this.uploadColor,
    required this.gridColor,
  });

  final List<ActivitySample> samples;
  final Color downloadColor;
  final Color uploadColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var row = 1; row < 4; row++) {
      final y = size.height * row / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (samples.length < 2) return;
    final maxValue = samples.fold<int>(
      1,
      (int current, ActivitySample sample) =>
          math.max(current, math.max(sample.downloadRate, sample.uploadRate)),
    );
    _drawSeries(
      canvas,
      size,
      samples.map((ActivitySample item) => item.downloadRate).toList(),
      maxValue,
      downloadColor,
    );
    _drawSeries(
      canvas,
      size,
      samples.map((ActivitySample item) => item.uploadRate).toList(),
      maxValue,
      uploadColor,
    );
  }

  void _drawSeries(
    Canvas canvas,
    Size size,
    List<int> values,
    int maxValue,
    Color color,
  ) {
    final line = Path();
    final fill = Path();
    for (var index = 0; index < values.length; index++) {
      final x = size.width * index / (values.length - 1);
      final y = size.height - (values[index] / maxValue * size.height * 0.88);
      if (index == 0) {
        line.moveTo(x, y);
        fill
          ..moveTo(x, size.height)
          ..lineTo(x, y);
      } else {
        line.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill
      ..lineTo(size.width, size.height)
      ..close();
    canvas
      ..drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              color.withValues(alpha: 0.2),
              color.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      )
      ..drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_SpeedChartPainter oldDelegate) =>
      oldDelegate.samples != samples;
}

class GoalProgressLabel extends StatelessWidget {
  const GoalProgressLabel({
    required this.goal,
    required this.current,
    super.key,
  });

  final SeedGoal goal;
  final double current;

  @override
  Widget build(BuildContext context) {
    final effective = goal.metric == GoalMetric.overallRatio
        ? current
        : (current - goal.baseline).clamp(0, double.infinity);
    final text = switch (goal.metric) {
      GoalMetric.uploadedBytes =>
        '${formatBytes(effective)} of ${formatBytes(goal.target)}',
      GoalMetric.overallRatio =>
        '${effective.toStringAsFixed(2)} of ${goal.target.toStringAsFixed(2)} ratio',
      GoalMetric.torrentsAtOne =>
        '${effective.round()} of ${goal.target.round()} torrents',
      GoalMetric.seedingHours =>
        '${effective.toStringAsFixed(1)} of ${goal.target.toStringAsFixed(0)} hours',
    };
    return Text(text, style: Theme.of(context).textTheme.labelMedium);
  }
}
