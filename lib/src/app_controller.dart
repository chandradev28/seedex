import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'data/local_store.dart';
import 'data/source_detector.dart';
import 'data/torrent_metadata_parser.dart';
import 'domain/models.dart';
import 'services/engine_task.dart';
import 'services/telegram_bot_client.dart';
import 'services/telegram_credentials_store.dart';

class IncomingTorrent {
  const IncomingTorrent({
    this.magnet = '',
    this.torrentFile = '',
    this.sourceUrl = '',
  });

  final String magnet;
  final String torrentFile;
  final String sourceUrl;

  bool get isFile => torrentFile.isNotEmpty;
}

class SeedexController extends ChangeNotifier {
  SeedexController({
    LocalStore? store,
    TelegramCredentialsStore? telegramCredentialsStore,
  })  : _store = store ?? LocalStore(),
        _telegramCredentialsStore =
            telegramCredentialsStore ?? TelegramCredentialsStore();

  static const MethodChannel _intentMethods =
      MethodChannel('dev.seedex/intents');
  static const EventChannel _intentEvents =
      EventChannel('dev.seedex/intents/events');

  final LocalStore _store;
  final TelegramCredentialsStore _telegramCredentialsStore;
  final List<TorrentRecord> _torrents = <TorrentRecord>[];
  final List<SeedGoal> _goals = <SeedGoal>[];
  final List<ActivitySample> _activity = <ActivitySample>[];

  AppSettings _settings = const AppSettings();
  StreamSubscription<Object?>? _intentSubscription;
  Timer? _saveDebounce;
  DateTime? _lastActivityAt;
  IncomingTorrent? _incomingTorrent;
  bool _initialized = false;
  bool _engineRunning = false;
  bool _networkAllowed = true;
  bool _telegramConfigured = false;
  String _telegramBotName = '';
  String _engineMessage = '';
  String _celebration = '';

  List<TorrentRecord> get torrents => List.unmodifiable(_torrents);
  List<SeedGoal> get goals => List.unmodifiable(_goals);
  List<ActivitySample> get activity => List.unmodifiable(_activity);
  AppSettings get settings => _settings;
  bool get initialized => _initialized;
  bool get engineRunning => _engineRunning;
  bool get networkAllowed => _networkAllowed;
  bool get telegramConfigured => _telegramConfigured;
  String get telegramBotName => _telegramBotName;
  String get engineMessage => _engineMessage;
  String get celebration => _celebration;
  IncomingTorrent? get incomingTorrent => _incomingTorrent;

  int get totalDownloadRate => _torrents.fold(
        0,
        (int total, TorrentRecord item) => total + item.downloadRate,
      );
  int get totalUploadRate => _torrents.fold(
        0,
        (int total, TorrentRecord item) => total + item.uploadRate,
      );
  int get totalUploaded => _torrents.fold(
        0,
        (int total, TorrentRecord item) => total + item.uploadedBytes,
      );
  int get totalDownloaded => _torrents.fold(
        0,
        (int total, TorrentRecord item) =>
            total + (item.totalDone > 0 ? item.totalDone : 0),
      );
  int get totalSeedingSeconds => _torrents.fold(
        0,
        (int total, TorrentRecord item) => total + item.seedingSeconds,
      );
  int get activeCount =>
      _torrents.where((TorrentRecord item) => item.isActive).length;
  int get seedingCount =>
      _torrents.where((TorrentRecord item) => item.isSeeding).length;
  int get oneToOneCount =>
      _torrents.where((TorrentRecord item) => item.ratio >= 1).length;
  int get completedGoalCount =>
      _goals.where((SeedGoal goal) => goal.isComplete).length;

  double get overallRatio {
    if (totalDownloaded <= 0) return 0;
    return totalUploaded / totalDownloaded;
  }

  Future<void> initialize() async {
    final snapshot = await _store.load();
    _torrents.addAll(snapshot.torrents);
    _goals.addAll(snapshot.goals);
    _activity.addAll(snapshot.activity);
    _settings = snapshot.settings;

    if (_settings.downloadPath.isEmpty) {
      final external = await getExternalStorageDirectory();
      final fallback = await getApplicationDocumentsDirectory();
      _settings = _settings.copyWith(downloadPath: (external ?? fallback).path);
    }

    try {
      _telegramConfigured = await _telegramCredentialsStore.read() != null;
    } on Object {
      _telegramConfigured = false;
      _settings = _settings.copyWith(telegramEnabled: false);
    }

    await _mergePersistedLedger();
    _initializeForegroundService();
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    _listenForAndroidIntents();
    _initialized = true;
    notifyListeners();

    if (_settings.acceptedNotice &&
        (_settings.telegramEnabled ||
            _torrents.any((TorrentRecord item) => !item.paused))) {
      await ensureEngineRunning();
    }
    _scheduleSave();
  }

  void _initializeForegroundService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'seedex_torrent_service',
        channelName: 'Torrent transfers',
        channelDescription: 'Shows active Seedex downloads and seeding progress.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> ensureEngineRunning() async {
    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (!await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.startService(
        serviceId: 8031,
        serviceTypes: const <ForegroundServiceTypes>[
          ForegroundServiceTypes.dataSync,
        ],
        notificationTitle: 'Seedex is starting',
        notificationText: 'Preparing the torrent engine…',
        notificationButtons: const <NotificationButton>[
          NotificationButton(id: 'pause_all', text: 'Pause all'),
        ],
        notificationInitialRoute: '/',
        callback: startSeedexTask,
      );
    }
    _engineRunning = true;
    notifyListeners();
  }

  Future<void> acceptNotice() async {
    _settings = _settings.copyWith(acceptedNotice: true);
    _scheduleSave(immediate: true);
    notifyListeners();
  }

  Future<TorrentRecord> addMagnet({
    required String magnet,
    String sourceUrl = '',
    String manualSource = '',
    double ratioTarget = 1,
    TorrentStartMode startMode = TorrentStartMode.downloadAndSeed,
    String existingDataPath = '',
  }) async {
    final normalized = magnet.trim();
    if (!TelegramCommandParser.isValidMagnet(normalized)) {
      throw const FormatException('Enter a valid BitTorrent magnet link.');
    }
    final savePath = await _resolveSavePath(startMode, existingDataPath);

    final detected = SourceDetector.fromMagnet(normalized, sharedUrl: sourceUrl);
    final manualDomain = SourceDetector.domainOf(manualSource);
    final record = TorrentRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      inputType: TorrentInputType.magnet,
      inputValue: normalized,
      displayName: SourceDetector.displayNameFromMagnet(normalized),
      savePath: savePath,
      addedAt: DateTime.now(),
      startMode: startMode,
      sourceDomain: manualDomain.isNotEmpty ? manualDomain : detected.domain,
      sourceUrl: manualSource.isNotEmpty ? manualSource : detected.url,
      sourceConfidence: manualDomain.isNotEmpty
          ? SourceConfidence.manual
          : detected.isExact
              ? SourceConfidence.exact
              : detected.trackers.isNotEmpty
                  ? SourceConfidence.tracker
                  : SourceConfidence.unknown,
      trackers: detected.trackers,
      status: startMode == TorrentStartMode.existingData
          ? 'Getting metadata'
          : 'Queued',
      ratioTarget: ratioTarget,
    );

    await _startRecord(record);
    return record;
  }

  Future<TorrentRecord> addTorrentFile({
    required String originalPath,
    String manualSource = '',
    double ratioTarget = 1,
    TorrentStartMode startMode = TorrentStartMode.downloadAndSeed,
    String existingDataPath = '',
  }) async {
    var readablePath = originalPath;
    if (originalPath.startsWith('content://')) {
      readablePath = await _intentMethods.invokeMethod<String>(
            'copyContentUri',
            <String, Object?>{'uri': originalPath},
          ) ??
          '';
    } else if (originalPath.startsWith('file://')) {
      readablePath = Uri.parse(originalPath).toFilePath();
    }
    if (readablePath.isEmpty || !await File(readablePath).exists()) {
      throw const FileSystemException(
        'The selected torrent file is unavailable.',
      );
    }

    final metadataDirectory = Directory(
      path.join(
        (await getApplicationSupportDirectory()).path,
        'torrent_metadata',
      ),
    );
    await metadataDirectory.create(recursive: true);
    final persistedPath = path.join(
      metadataDirectory.path,
      '${DateTime.now().microsecondsSinceEpoch}.torrent',
    );
    await File(readablePath).copy(persistedPath);

    TorrentMetadataHint hint = const TorrentMetadataHint();
    try {
      hint = TorrentMetadataParser.parse(
        await File(persistedPath).readAsBytes(),
      );
    } on FormatException {
      // libtorrent performs authoritative validation after record creation.
    }

    final savePath = await _resolveSavePath(startMode, existingDataPath);
    final manualDomain = SourceDetector.domainOf(manualSource);
    final fallbackName = path.basenameWithoutExtension(
      Uri.tryParse(originalPath)?.path ?? originalPath,
    );
    final record = TorrentRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      inputType: TorrentInputType.file,
      inputValue: persistedPath,
      displayName: hint.name.isNotEmpty ? hint.name : fallbackName,
      savePath: savePath,
      addedAt: DateTime.now(),
      startMode: startMode,
      sourceDomain: manualDomain.isNotEmpty
          ? manualDomain
          : (hint.trackers.isEmpty ? '' : hint.trackers.first),
      sourceUrl: manualSource,
      sourceConfidence: manualDomain.isNotEmpty
          ? SourceConfidence.manual
          : hint.trackers.isNotEmpty
              ? SourceConfidence.tracker
              : SourceConfidence.unknown,
      trackers: hint.trackers,
      status: startMode == TorrentStartMode.existingData
          ? 'Checking files'
          : 'Queued',
      totalWanted: hint.totalBytes,
      ratioTarget: ratioTarget,
    );

    await _startRecord(record);
    return record;
  }

  Future<String> _resolveSavePath(
    TorrentStartMode startMode,
    String existingDataPath,
  ) async {
    if (startMode == TorrentStartMode.downloadAndSeed) {
      return _settings.downloadPath;
    }
    final selected = existingDataPath.trim();
    if (selected.isEmpty) {
      throw const FormatException(
        'Choose the folder that already contains the exact torrent files.',
      );
    }
    final directory = Directory(selected);
    if (!await directory.exists()) {
      throw const FileSystemException(
        'The selected content folder is unavailable.',
      );
    }
    return directory.path;
  }

  Future<void> _startRecord(TorrentRecord record) async {
    _torrents.insert(0, record);
    await _persist();
    await ensureEngineRunning();
    FlutterForegroundTask.sendDataToTask(<String, Object?>{
      'command': seedexTaskAdd,
      'record': record.toJson(),
    });
    notifyListeners();
  }

  Future<void> pauseTorrent(String id) async {
    _replaceTorrent(id, (TorrentRecord item) => item.copyWith(paused: true));
    FlutterForegroundTask.sendDataToTask(<String, Object?>{
      'command': seedexTaskPause,
      'id': id,
    });
    _scheduleSave();
  }

  Future<void> resumeTorrent(String id) async {
    _replaceTorrent(id, (TorrentRecord item) => item.copyWith(paused: false));
    await ensureEngineRunning();
    FlutterForegroundTask.sendDataToTask(<String, Object?>{
      'command': seedexTaskResume,
      'id': id,
    });
    _scheduleSave();
  }

  void recheckTorrent(String id) {
    FlutterForegroundTask.sendDataToTask(<String, Object?>{
      'command': seedexTaskRecheck,
      'id': id,
    });
  }

  Future<void> removeTorrent(String id, {required bool deleteFiles}) async {
    final index = _torrents.indexWhere((TorrentRecord item) => item.id == id);
    if (index < 0) return;
    final record = _torrents.removeAt(index);
    final canDeletePayload =
        record.startMode == TorrentStartMode.downloadAndSeed && deleteFiles;
    FlutterForegroundTask.sendDataToTask(<String, Object?>{
      'command': seedexTaskRemove,
      'id': id,
      'deleteFiles': canDeletePayload,
    });
    if (record.inputType == TorrentInputType.file) {
      try {
        await File(record.inputValue).delete();
      } on FileSystemException {
        // Metadata may already have been cleaned by Android.
      }
    }
    await _persist();
    if (_torrents.isEmpty &&
        !_settings.telegramEnabled &&
        await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
      _engineRunning = false;
    }
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings value) async {
    _settings = value;
    if (value.telegramEnabled && _telegramConfigured) {
      await ensureEngineRunning();
    }
    FlutterForegroundTask.sendDataToTask(<String, Object?>{
      'command': seedexTaskConfigure,
      'settings': value.toJson(),
    });
    if (!value.telegramEnabled &&
        _torrents.isEmpty &&
        await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
      _engineRunning = false;
    }
    _scheduleSave();
    notifyListeners();
  }

  Future<String> testTelegramCredentials({
    required String botToken,
    required String chatId,
  }) async {
    final credentials = _validatedTelegramCredentials(botToken, chatId);
    final client = TelegramBotClient(token: credentials.botToken);
    try {
      final identity = await client.getMe();
      await client.sendMessage(
        chatId: credentials.chatId,
        text: 'Seedex connection successful. This chat is now verified.',
      );
      return identity.username.isEmpty
          ? identity.displayName
          : '@${identity.username}';
    } finally {
      client.close();
    }
  }

  Future<String> configureTelegram({
    required String botToken,
    required String chatId,
  }) async {
    final credentials = _validatedTelegramCredentials(botToken, chatId);
    final botName = await testTelegramCredentials(
      botToken: credentials.botToken,
      chatId: credentials.chatId,
    );
    await _telegramCredentialsStore.write(credentials);
    _telegramConfigured = true;
    _telegramBotName = botName;
    _settings = _settings.copyWith(
      telegramEnabled: true,
      telegramRemoteCommands: true,
      telegramCompletionNotifications: true,
      telegramGoalNotifications: true,
    );
    await _persist();
    await ensureEngineRunning();
    FlutterForegroundTask.sendDataToTask(<String, Object?>{
      'command': seedexTaskConfigure,
      'settings': _settings.toJson(),
    });
    FlutterForegroundTask.sendDataToTask(<String, Object?>{
      'command': seedexTaskRefreshTelegram,
    });
    notifyListeners();
    return botName;
  }

  TelegramCredentials _validatedTelegramCredentials(
    String botToken,
    String chatId,
  ) {
    final token = botToken.trim();
    final approvedChat = chatId.trim();
    if (!RegExp(r'^\d+:[A-Za-z0-9_-]{20,}$').hasMatch(token)) {
      throw const FormatException('Enter a valid Telegram Bot API token.');
    }
    if (!RegExp(r'^-?\d+$').hasMatch(approvedChat)) {
      throw const FormatException('Enter a numeric Telegram chat ID.');
    }
    return TelegramCredentials(botToken: token, chatId: approvedChat);
  }

  Future<void> disconnectTelegram() async {
    await _telegramCredentialsStore.clear();
    _telegramConfigured = false;
    _telegramBotName = '';
    _settings = _settings.copyWith(
      telegramEnabled: false,
      telegramRemoteCommands: false,
      telegramCompletionNotifications: false,
      telegramGoalNotifications: false,
    );
    await _persist();
    FlutterForegroundTask.sendDataToTask(<String, Object?>{
      'command': seedexTaskConfigure,
      'settings': _settings.toJson(),
    });
    FlutterForegroundTask.sendDataToTask(<String, Object?>{
      'command': seedexTaskRefreshTelegram,
    });
    if (_torrents.isEmpty && await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
      _engineRunning = false;
    }
    notifyListeners();
  }

  void addGoal({
    required String title,
    required GoalMetric metric,
    required double target,
    DateTime? deadline,
  }) {
    final goal = SeedGoal(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      metric: metric,
      target: target,
      baseline: metric == GoalMetric.overallRatio ? 0 : metricValue(metric),
      createdAt: DateTime.now(),
      deadline: deadline,
    );
    _goals.insert(0, goal);
    _scheduleSave();
    notifyListeners();
  }

  void deleteGoal(String id) {
    _goals.removeWhere((SeedGoal item) => item.id == id);
    _scheduleSave();
    notifyListeners();
  }

  double metricValue(GoalMetric metric) => switch (metric) {
        GoalMetric.uploadedBytes => totalUploaded.toDouble(),
        GoalMetric.overallRatio => overallRatio,
        GoalMetric.torrentsAtOne => oneToOneCount.toDouble(),
        GoalMetric.seedingHours => totalSeedingSeconds / 3600,
      };

  void clearCelebration() {
    _celebration = '';
    notifyListeners();
  }

  IncomingTorrent? consumeIncomingTorrent() {
    final incoming = _incomingTorrent;
    _incomingTorrent = null;
    return incoming;
  }

  Future<void> chooseDownloadPath(String newPath) async {
    if (newPath.isEmpty) return;
    await updateSettings(_settings.copyWith(downloadPath: newPath));
  }

  void _onTaskData(Object data) {
    if (data is! Map<Object?, Object?>) return;
    final type = data['type'];
    if (type == 'engineError' || type == 'telegramError') {
      final id = data['id'] as String? ?? '';
      final message = data['message'] as String? ?? 'Seedex service error';
      if (id.isNotEmpty) {
        _replaceTorrent(id, (TorrentRecord item) {
          return item.copyWith(error: message);
        });
      }
      _engineMessage = message;
      _scheduleSave();
      notifyListeners();
      return;
    }
    if (type == 'telegramAdded') {
      final rawRecord = data['record'];
      if (rawRecord is Map<Object?, Object?>) {
        final record = TorrentRecord.fromJson(
          rawRecord.map<String, Object?>(
            (Object? key, Object? value) => MapEntry<String, Object?>(
              key.toString(),
              value,
            ),
          ),
        );
        if (!_torrents.any((TorrentRecord item) => item.id == record.id)) {
          _torrents.insert(0, record);
          _scheduleSave();
        }
      }
      notifyListeners();
      return;
    }
    if (type != 'snapshot') return;

    _networkAllowed = data['networkAllowed'] as bool? ?? true;
    final rawItems = data['items'];
    if (rawItems is List<Object?>) {
      for (final rawItem in rawItems) {
        if (rawItem is Map<Object?, Object?>) _mergeEngineItem(rawItem);
      }
    }
    _engineRunning = true;
    _recordActivity();
    _completeReachedGoals();
    _scheduleSave();
    notifyListeners();
  }

  void _mergeEngineItem(Map<Object?, Object?> value) {
    final id = value['id'] as String? ?? '';
    final index = _torrents.indexWhere((TorrentRecord item) => item.id == id);
    if (index < 0) return;
    final current = _torrents[index];
    final sessionId = value['sessionId'] as String? ?? '';
    final rawUploaded = (value['rawUploaded'] as num? ?? 0).toInt();
    final rawSeconds =
        (value['sessionSeedingSeconds'] as num? ?? 0).toInt();
    final ledger = Map<String, int>.from(current.uploadLedger);
    var uploaded = current.uploadedBytes;
    var seedingSeconds = current.seedingSeconds;
    if (sessionId.isNotEmpty) {
      final previousUpload = ledger[sessionId] ?? 0;
      final previousSeconds = ledger['seed:$sessionId'] ?? 0;
      uploaded += (rawUploaded - previousUpload).clamp(0, rawUploaded).toInt();
      seedingSeconds +=
          (rawSeconds - previousSeconds).clamp(0, rawSeconds).toInt();
      ledger[sessionId] = rawUploaded;
      ledger['seed:$sessionId'] = rawSeconds;
    }

    final engineName = value['name'] as String? ?? '';
    _torrents[index] = current.copyWith(
      displayName: engineName.isEmpty ? current.displayName : engineName,
      status: value['status'] as String? ?? current.status,
      progress: (value['progress'] as num? ?? current.progress).toDouble(),
      totalDone: (value['totalDone'] as num? ?? current.totalDone).toInt(),
      totalWanted:
          (value['totalWanted'] as num? ?? current.totalWanted).toInt(),
      uploadedBytes: uploaded,
      downloadRate: (value['downloadRate'] as num? ?? 0).toInt(),
      uploadRate: (value['uploadRate'] as num? ?? 0).toInt(),
      peers: (value['peers'] as num? ?? 0).toInt(),
      seeds: (value['seeds'] as num? ?? 0).toInt(),
      paused: value['paused'] as bool? ?? current.paused,
      error: value['error'] as String? ?? '',
      uploadLedger: ledger,
      seedingSeconds: seedingSeconds,
    );
  }

  Future<void> _mergePersistedLedger() async {
    final ledger = await _store.loadEngineLedger();
    for (var index = 0; index < _torrents.length; index++) {
      final record = _torrents[index];
      final sessions = ledger[record.id];
      if (sessions == null) continue;
      final seen = Map<String, int>.from(record.uploadLedger);
      var uploaded = record.uploadedBytes;
      var seconds = record.seedingSeconds;
      for (final entry in sessions.entries) {
        final rawUpload = entry.value['uploaded'] ?? 0;
        final rawSeconds = entry.value['seedingSeconds'] ?? 0;
        uploaded +=
            (rawUpload - (seen[entry.key] ?? 0)).clamp(0, rawUpload).toInt();
        seconds += (rawSeconds - (seen['seed:${entry.key}'] ?? 0))
            .clamp(0, rawSeconds)
            .toInt();
        seen[entry.key] = rawUpload;
        seen['seed:${entry.key}'] = rawSeconds;
      }
      _torrents[index] = record.copyWith(
        uploadedBytes: uploaded,
        seedingSeconds: seconds,
        uploadLedger: seen,
      );
    }
  }

  void _recordActivity() {
    final now = DateTime.now();
    if (_lastActivityAt != null &&
        now.difference(_lastActivityAt!).inSeconds < 10) {
      return;
    }
    _lastActivityAt = now;
    _activity.add(ActivitySample(
      timestamp: now,
      downloadRate: totalDownloadRate,
      uploadRate: totalUploadRate,
    ));
    if (_activity.length > 144) {
      _activity.removeRange(0, _activity.length - 144);
    }
  }

  void _completeReachedGoals() {
    for (var index = 0; index < _goals.length; index++) {
      final goal = _goals[index];
      if (!goal.isComplete && goal.progress(metricValue(goal.metric)) >= 1) {
        final completed = goal.copyWith(completedAt: DateTime.now());
        _goals[index] = completed;
        _celebration = '${goal.title} completed';
        if (_settings.telegramEnabled &&
            _settings.telegramGoalNotifications) {
          FlutterForegroundTask.sendDataToTask(<String, Object?>{
            'command': seedexTaskTelegramMessage,
            'text': '🎯 Seedex goal completed\n${completed.title}',
          });
        }
      }
    }
  }

  void _replaceTorrent(
    String id,
    TorrentRecord Function(TorrentRecord current) update,
  ) {
    final index = _torrents.indexWhere((TorrentRecord item) => item.id == id);
    if (index < 0) return;
    _torrents[index] = update(_torrents[index]);
    notifyListeners();
  }

  void _listenForAndroidIntents() {
    _intentSubscription = _intentEvents.receiveBroadcastStream().listen(
      _handleIntentPayload,
      onError: (Object _) {},
    );
    unawaited(
      _intentMethods
          .invokeMapMethod<String, Object?>('getInitialPayload')
          .then((Map<String, Object?>? value) {
        if (value != null) _handleIntentPayload(value);
      }),
    );
  }

  void _handleIntentPayload(Object? raw) {
    if (raw is! Map<Object?, Object?>) return;
    final value = raw['value'] as String? ?? '';
    final magnet = SourceDetector.magnetFromText(value);
    final source = SourceDetector.webUrlFromText(value) ??
        (raw['referrer'] as String? ?? '');
    if (magnet != null) {
      _incomingTorrent = IncomingTorrent(
        magnet: magnet,
        sourceUrl: source,
      );
      notifyListeners();
      return;
    }

    final mimeType = (raw['mimeType'] as String? ?? '').toLowerCase();
    final isTorrentFile = mimeType == 'application/x-bittorrent' ||
        value.toLowerCase().contains('.torrent') ||
        value.startsWith('content://');
    if (!isTorrentFile || value.isEmpty) return;
    _incomingTorrent = IncomingTorrent(
      torrentFile: value,
      sourceUrl: source,
    );
    notifyListeners();
  }

  void _scheduleSave({bool immediate = false}) {
    _saveDebounce?.cancel();
    if (immediate) {
      unawaited(_persist());
      return;
    }
    _saveDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_persist());
    });
  }

  Future<void> _persist() => _store.save(AppSnapshot(
        torrents: _torrents,
        goals: _goals,
        activity: _activity,
        settings: _settings,
      ));

  @override
  void dispose() {
    _saveDebounce?.cancel();
    unawaited(_persist());
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    unawaited(_intentSubscription?.cancel());
    super.dispose();
  }
}
