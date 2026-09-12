import 'dart:math' as math;

String formatBytes(num bytes, {int decimals = 1}) {
  if (bytes <= 0) return '0 B';
  const units = <String>['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  final index = math.min(
    (math.log(bytes) / math.log(1000)).floor(),
    units.length - 1,
  );
  final value = bytes / math.pow(1000, index);
  return '${value.toStringAsFixed(index == 0 ? 0 : decimals)} ${units[index]}';
}

String formatSpeed(num bytesPerSecond) => '${formatBytes(bytesPerSecond)}/s';

String formatRatio(double ratio) {
  if (!ratio.isFinite) return '—';
  return ratio.toStringAsFixed(2);
}

String formatPercent(double value) => '${(value.clamp(0, 1) * 100).round()}%';

String formatDuration(Duration duration) {
  if (duration.inDays > 0) {
    return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
  }
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }
  if (duration.inMinutes > 0) return '${duration.inMinutes}m';
  return '${duration.inSeconds}s';
}

String compactDate(DateTime value) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

String etaFor({required int wanted, required int done, required int rate}) {
  if (done >= wanted && wanted > 0) return 'Complete';
  if (rate <= 0 || wanted <= 0) return 'Calculating';
  return formatDuration(Duration(seconds: (wanted - done) ~/ rate));
}

int bytesFromAmount(double amount, String unit) {
  const multipliers = <String, int>{
    'MB': 1000 * 1000,
    'GB': 1000 * 1000 * 1000,
    'TB': 1000 * 1000 * 1000 * 1000,
  };
  return (amount * (multipliers[unit] ?? 1)).round();
}
