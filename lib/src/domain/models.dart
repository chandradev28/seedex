import 'dart:math' as math;

enum TorrentInputType { magnet, file }

enum TorrentStartMode { downloadAndSeed, existingData }

enum SourceConfidence { exact, manual, tracker, unknown }

enum GoalMetric { uploadedBytes, overallRatio, torrentsAtOne, seedingHours }

class TorrentRecord {
  const TorrentRecord({
    required this.id,
    required this.inputType,
    required this.inputValue,
    required this.displayName,
    required this.savePath,
    required this.addedAt,
    this.startMode = TorrentStartMode.downloadAndSeed,
    this.sourceDomain = '',
    this.sourceUrl = '',
    this.sourceConfidence = SourceConfidence.unknown,
    this.trackers = const <String>[],
    this.paused = false,
    this.status = 'Queued',
    this.progress = 0,
    this.totalDone = 0,
    this.totalWanted = 0,
    this.uploadedBytes = 0,
    this.downloadRate = 0,
    this.uploadRate = 0,
    this.peers = 0,
    this.seeds = 0,
    this.error = '',
    this.ratioTarget = 1,
    this.uploadLedger = const <String, int>{},
    this.seedingSeconds = 0,
  });

  final String id;
  final TorrentInputType inputType;
  final String inputValue;
  final String displayName;
  final String savePath;
  final DateTime addedAt;
  final TorrentStartMode startMode;
  final String sourceDomain;
  final String sourceUrl;
  final SourceConfidence sourceConfidence;
  final List<String> trackers;
  final bool paused;
  final String status;
  final double progress;
  final int totalDone;
  final int totalWanted;
  final int uploadedBytes;
  final int downloadRate;
  final int uploadRate;
  final int peers;
  final int seeds;
  final String error;
  final double ratioTarget;
  final Map<String, int> uploadLedger;
  final int seedingSeconds;

  double get ratio {
    final denominator = totalDone > 0 ? totalDone : totalWanted;
    if (denominator <= 0) return 0;
    return uploadedBytes / denominator;
  }

  int get ratioGoalBytes => (totalWanted * ratioTarget).round();

  double get ratioGoalProgress {
    if (ratioGoalBytes <= 0) return 0;
    return (uploadedBytes / ratioGoalBytes).clamp(0, 1).toDouble();
  }

  int get remainingForRatio => math.max(0, ratioGoalBytes - uploadedBytes);

  bool get isSeeding => status.toLowerCase() == 'seeding';

  bool get usesExistingData => startMode == TorrentStartMode.existingData;

  bool get isActive {
    final normalized = status.toLowerCase();
    return !paused &&
        (normalized == 'downloading' ||
            normalized == 'seeding' ||
            normalized == 'getting metadata' ||
            normalized == 'checking files');
  }

  TorrentRecord copyWith({
    String? displayName,
    String? savePath,
    TorrentStartMode? startMode,
    String? sourceDomain,
    String? sourceUrl,
    SourceConfidence? sourceConfidence,
    List<String>? trackers,
    bool? paused,
    String? status,
    double? progress,
    int? totalDone,
    int? totalWanted,
    int? uploadedBytes,
    int? downloadRate,
    int? uploadRate,
    int? peers,
    int? seeds,
    String? error,
    double? ratioTarget,
    Map<String, int>? uploadLedger,
    int? seedingSeconds,
  }) {
    return TorrentRecord(
      id: id,
      inputType: inputType,
      inputValue: inputValue,
      displayName: displayName ?? this.displayName,
      savePath: savePath ?? this.savePath,
      addedAt: addedAt,
      startMode: startMode ?? this.startMode,
      sourceDomain: sourceDomain ?? this.sourceDomain,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceConfidence: sourceConfidence ?? this.sourceConfidence,
      trackers: trackers ?? this.trackers,
      paused: paused ?? this.paused,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      totalDone: totalDone ?? this.totalDone,
      totalWanted: totalWanted ?? this.totalWanted,
      uploadedBytes: uploadedBytes ?? this.uploadedBytes,
      downloadRate: downloadRate ?? this.downloadRate,
      uploadRate: uploadRate ?? this.uploadRate,
      peers: peers ?? this.peers,
      seeds: seeds ?? this.seeds,
      error: error ?? this.error,
      ratioTarget: ratioTarget ?? this.ratioTarget,
      uploadLedger: uploadLedger ?? this.uploadLedger,
      seedingSeconds: seedingSeconds ?? this.seedingSeconds,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'inputType': inputType.name,
    'inputValue': inputValue,
    'displayName': displayName,
    'savePath': savePath,
    'addedAt': addedAt.toIso8601String(),
    'startMode': startMode.name,
    'sourceDomain': sourceDomain,
    'sourceUrl': sourceUrl,
    'sourceConfidence': sourceConfidence.name,
    'trackers': trackers,
    'paused': paused,
    'status': status,
    'progress': progress,
    'totalDone': totalDone,
    'totalWanted': totalWanted,
    'uploadedBytes': uploadedBytes,
    'downloadRate': downloadRate,
    'uploadRate': uploadRate,
    'peers': peers,
    'seeds': seeds,
    'error': error,
    'ratioTarget': ratioTarget,
    'uploadLedger': uploadLedger,
    'seedingSeconds': seedingSeconds,
  };

  factory TorrentRecord.fromJson(Map<String, Object?> json) {
    final rawTrackers = json['trackers'] as List<Object?>? ?? const <Object?>[];
    final rawLedger =
        json['uploadLedger'] as Map<Object?, Object?>? ??
        const <Object?, Object?>{};
    return TorrentRecord(
      id: json['id'] as String,
      inputType: TorrentInputType.values.byName(
        json['inputType'] as String? ?? TorrentInputType.magnet.name,
      ),
      inputValue: json['inputValue'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Untitled torrent',
      savePath: json['savePath'] as String? ?? '',
      addedAt:
          DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
      startMode: TorrentStartMode.values.byName(
        json['startMode'] as String? ?? TorrentStartMode.downloadAndSeed.name,
      ),
      sourceDomain: json['sourceDomain'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      sourceConfidence: SourceConfidence.values.byName(
        json['sourceConfidence'] as String? ?? SourceConfidence.unknown.name,
      ),
      trackers: rawTrackers.whereType<String>().toList(growable: false),
      paused: json['paused'] as bool? ?? false,
      status: json['status'] as String? ?? 'Queued',
      progress: (json['progress'] as num? ?? 0).toDouble(),
      totalDone: (json['totalDone'] as num? ?? 0).toInt(),
      totalWanted: (json['totalWanted'] as num? ?? 0).toInt(),
      uploadedBytes: (json['uploadedBytes'] as num? ?? 0).toInt(),
      downloadRate: (json['downloadRate'] as num? ?? 0).toInt(),
      uploadRate: (json['uploadRate'] as num? ?? 0).toInt(),
      peers: (json['peers'] as num? ?? 0).toInt(),
      seeds: (json['seeds'] as num? ?? 0).toInt(),
      error: json['error'] as String? ?? '',
      ratioTarget: (json['ratioTarget'] as num? ?? 1).toDouble(),
      uploadLedger: rawLedger.map<String, int>(
        (Object? key, Object? value) =>
            MapEntry<String, int>(key.toString(), (value as num? ?? 0).toInt()),
      ),
      seedingSeconds: (json['seedingSeconds'] as num? ?? 0).toInt(),
    );
  }
}

class SeedGoal {
  const SeedGoal({
    required this.id,
    required this.title,
    required this.metric,
    required this.target,
    required this.createdAt,
    this.baseline = 0,
    this.deadline,
    this.completedAt,
  });

  final String id;
  final String title;
  final GoalMetric metric;
  final double target;
  final double baseline;
  final DateTime createdAt;
  final DateTime? deadline;
  final DateTime? completedAt;

  bool get isComplete => completedAt != null;

  double progress(double currentValue) {
    final effective = metric == GoalMetric.overallRatio
        ? currentValue
        : math.max(0, currentValue - baseline);
    if (target <= 0) return 0;
    return (effective / target).clamp(0, 1).toDouble();
  }

  SeedGoal copyWith({DateTime? completedAt}) => SeedGoal(
    id: id,
    title: title,
    metric: metric,
    target: target,
    baseline: baseline,
    createdAt: createdAt,
    deadline: deadline,
    completedAt: completedAt ?? this.completedAt,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'metric': metric.name,
    'target': target,
    'baseline': baseline,
    'createdAt': createdAt.toIso8601String(),
    'deadline': deadline?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  factory SeedGoal.fromJson(Map<String, Object?> json) => SeedGoal(
    id: json['id'] as String,
    title: json['title'] as String? ?? 'Sharing goal',
    metric: GoalMetric.values.byName(
      json['metric'] as String? ?? GoalMetric.uploadedBytes.name,
    ),
    target: (json['target'] as num? ?? 0).toDouble(),
    baseline: (json['baseline'] as num? ?? 0).toDouble(),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    deadline: DateTime.tryParse(json['deadline'] as String? ?? ''),
    completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
  );
}

class ActivitySample {
  const ActivitySample({
    required this.timestamp,
    required this.downloadRate,
    required this.uploadRate,
  });

  final DateTime timestamp;
  final int downloadRate;
  final int uploadRate;

  Map<String, Object?> toJson() => <String, Object?>{
    'timestamp': timestamp.toIso8601String(),
    'downloadRate': downloadRate,
    'uploadRate': uploadRate,
  };

  factory ActivitySample.fromJson(Map<String, Object?> json) => ActivitySample(
    timestamp:
        DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    downloadRate: (json['downloadRate'] as num? ?? 0).toInt(),
    uploadRate: (json['uploadRate'] as num? ?? 0).toInt(),
  );
}

class AppSettings {
  const AppSettings({
    this.wifiOnly = true,
    this.cellularAllowed = false,
    this.downloadLimit = 0,
    this.uploadLimit = 0,
    this.darkMode = false,
    this.continueAfterGoal = true,
    this.downloadPath = '',
    this.acceptedNotice = false,
    this.telegramEnabled = false,
    this.telegramRemoteCommands = true,
    this.telegramCompletionNotifications = true,
    this.telegramGoalNotifications = true,
  });

  final bool wifiOnly;
  final bool cellularAllowed;
  final int downloadLimit;
  final int uploadLimit;
  final bool darkMode;
  final bool continueAfterGoal;
  final String downloadPath;
  final bool acceptedNotice;
  final bool telegramEnabled;
  final bool telegramRemoteCommands;
  final bool telegramCompletionNotifications;
  final bool telegramGoalNotifications;

  AppSettings copyWith({
    bool? wifiOnly,
    bool? cellularAllowed,
    int? downloadLimit,
    int? uploadLimit,
    bool? darkMode,
    bool? continueAfterGoal,
    String? downloadPath,
    bool? acceptedNotice,
    bool? telegramEnabled,
    bool? telegramRemoteCommands,
    bool? telegramCompletionNotifications,
    bool? telegramGoalNotifications,
  }) {
    return AppSettings(
      wifiOnly: wifiOnly ?? this.wifiOnly,
      cellularAllowed: cellularAllowed ?? this.cellularAllowed,
      downloadLimit: downloadLimit ?? this.downloadLimit,
      uploadLimit: uploadLimit ?? this.uploadLimit,
      darkMode: darkMode ?? this.darkMode,
      continueAfterGoal: continueAfterGoal ?? this.continueAfterGoal,
      downloadPath: downloadPath ?? this.downloadPath,
      acceptedNotice: acceptedNotice ?? this.acceptedNotice,
      telegramEnabled: telegramEnabled ?? this.telegramEnabled,
      telegramRemoteCommands:
          telegramRemoteCommands ?? this.telegramRemoteCommands,
      telegramCompletionNotifications:
          telegramCompletionNotifications ??
          this.telegramCompletionNotifications,
      telegramGoalNotifications:
          telegramGoalNotifications ?? this.telegramGoalNotifications,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'wifiOnly': wifiOnly,
    'cellularAllowed': cellularAllowed,
    'downloadLimit': downloadLimit,
    'uploadLimit': uploadLimit,
    'darkMode': darkMode,
    'continueAfterGoal': continueAfterGoal,
    'downloadPath': downloadPath,
    'acceptedNotice': acceptedNotice,
    'telegramEnabled': telegramEnabled,
    'telegramRemoteCommands': telegramRemoteCommands,
    'telegramCompletionNotifications': telegramCompletionNotifications,
    'telegramGoalNotifications': telegramGoalNotifications,
  };

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
    wifiOnly: json['wifiOnly'] as bool? ?? true,
    cellularAllowed: json['cellularAllowed'] as bool? ?? false,
    downloadLimit: (json['downloadLimit'] as num? ?? 0).toInt(),
    uploadLimit: (json['uploadLimit'] as num? ?? 0).toInt(),
    darkMode: json['darkMode'] as bool? ?? false,
    continueAfterGoal: json['continueAfterGoal'] as bool? ?? true,
    downloadPath: json['downloadPath'] as String? ?? '',
    acceptedNotice: json['acceptedNotice'] as bool? ?? false,
    telegramEnabled: json['telegramEnabled'] as bool? ?? false,
    telegramRemoteCommands: json['telegramRemoteCommands'] as bool? ?? true,
    telegramCompletionNotifications:
        json['telegramCompletionNotifications'] as bool? ?? true,
    telegramGoalNotifications:
        json['telegramGoalNotifications'] as bool? ?? true,
  );
}

class AppSnapshot {
  const AppSnapshot({
    required this.torrents,
    required this.goals,
    required this.activity,
    required this.settings,
  });

  final List<TorrentRecord> torrents;
  final List<SeedGoal> goals;
  final List<ActivitySample> activity;
  final AppSettings settings;
}
