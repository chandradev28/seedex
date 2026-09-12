import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart' hide formatSpeed;

import '../core/formatters.dart';
import '../data/local_store.dart';
import '../data/source_detector.dart';
import '../domain/models.dart';
import 'telegram_bot_client.dart';
import 'telegram_credentials_store.dart';

const String seedexTaskAdd = 'add';
const String seedexTaskPause = 'pause';
const String seedexTaskResume = 'resume';
const String seedexTaskRemove = 'remove';
const String seedexTaskRecheck = 'recheck';
const String seedexTaskConfigure = 'configure';
const String seedexTaskPauseAll = 'pauseAll';
const String seedexTaskResumeAll = 'resumeAll';
const String seedexTaskRefreshTelegram = 'refreshTelegram';
const String seedexTaskTelegramMessage = 'telegramMessage';

@pragma('vm:entry-point')
void startSeedexTask() {
  FlutterForegroundTask.setTaskHandler(SeedexTaskHandler());
}

enum _ExistingVerificationStage {
  waitingMetadata,
  checking,
  verified,
  failed,
}

class SeedexTaskHandler extends TaskHandler {
  final LocalStore _store = LocalStore();
  final TelegramCredentialsStore _credentialsStore =
      TelegramCredentialsStore();
  final Map<String, int> _engineIds = <String, int>{};
  final Map<String, TorrentRecord> _records = <String, TorrentRecord>{};
  final Map<int, TorrentInfo> _latest = <int, TorrentInfo>{};
  final Map<String, int> _seedingSeconds = <String, int>{};
  final Map<String, _ExistingVerificationStage> _verification =
      <String, _ExistingVerificationStage>{};
  final Map<String, int> _verificationStartedTick = <String, int>{};
  final Set<String> _userPaused = <String>{};
  final Set<String> _policyPaused = <String>{};

  late final String _sessionId;
  AppSettings _settings = const AppSettings();
  Map<String, Map<String, Map<String, int>>> _ledger =
      <String, Map<String, Map<String, int>>>{};
  Set<String> _completionMarkers = <String>{};
  StreamSubscription<Map<int, TorrentInfo>>? _torrentSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  List<ConnectivityResult> _connectivity = const <ConnectivityResult>[];
  TelegramCredentials? _telegramCredentials;
  TelegramBotClient? _telegramClient;
  int _telegramGeneration = 0;
  int _telegramOffset = 0;
  int _tick = 0;
  bool _tickRunning = false;
  bool _destroyed = false;

  LibtorrentFlutter get _engine => LibtorrentFlutter.instance;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _sessionId = timestamp.microsecondsSinceEpoch.toString();
    final snapshot = await _store.load();
    _settings = snapshot.settings;
    _ledger = await _store.loadEngineLedger();
    _completionMarkers = await _store.loadTelegramCompletionMarkers();
    _telegramOffset = await _store.loadTelegramUpdateOffset();

    await LibtorrentFlutter.init(
      downloadLimit: _settings.downloadLimit,
      uploadLimit: _settings.uploadLimit,
      defaultSavePath:
          _settings.downloadPath.isEmpty ? null : _settings.downloadPath,
      fetchTrackers: false,
      pollInterval: const Duration(milliseconds: 700),
    );

    _torrentSubscription = _engine.torrentUpdates.listen((updates) {
      _latest
        ..clear()
        ..addAll(updates);
    });

    for (final record in snapshot.torrents) {
      await _addRecord(record);
    }

    _connectivity = await Connectivity().checkConnectivity();
    await _applyNetworkPolicy();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> result) {
        _connectivity = result;
        unawaited(_applyNetworkPolicy());
      },
    );
    await _refreshTelegram();
    await _publish(forcePersist: true);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_tickRunning) return;
    _tickRunning = true;
    unawaited(_onTick().whenComplete(() => _tickRunning = false));
  }

  Future<void> _onTick() async {
    _tick++;
    if (_tick % 10 == 0) {
      _connectivity = await Connectivity().checkConnectivity();
      await _applyNetworkPolicy();
    }
    for (final entry in _engineIds.entries) {
      final info = _latest[entry.value];
      if (info == null) continue;
      _updateExistingVerification(entry.key, info);
      if (info.state == TorrentState.seeding && !info.isPaused) {
        _seedingSeconds.update(
          entry.key,
          (int value) => value + 1,
          ifAbsent: () => 1,
        );
        await _trackCompletion(entry.key, info.name);
      }
      if (!_settings.continueAfterGoal &&
          info.totalWanted > 0 &&
          !info.isPaused) {
        final record = _records[entry.key];
        if (record != null &&
            info.totalUploaded >= info.totalWanted * record.ratioTarget) {
          _engine.pauseTorrent(entry.value);
          _userPaused.add(entry.key);
        }
      }
    }
    await _publish(forcePersist: _tick % 15 == 0);
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map<Object?, Object?>) return;
    final command = data['command'] as String? ?? '';
    switch (command) {
      case seedexTaskAdd:
        final rawRecord = data['record'];
        if (rawRecord is Map<Object?, Object?>) {
          final json = rawRecord.map<String, Object?>(
            (Object? key, Object? value) => MapEntry<String, Object?>(
              key.toString(),
              value,
            ),
          );
          unawaited(_addRecord(TorrentRecord.fromJson(json)));
        }
        break;
      case seedexTaskPause:
        _pause(data['id'] as String? ?? '', userInitiated: true);
        break;
      case seedexTaskResume:
        _resume(data['id'] as String? ?? '', userInitiated: true);
        break;
      case seedexTaskRemove:
        _remove(
          data['id'] as String? ?? '',
          deleteFiles: data['deleteFiles'] as bool? ?? false,
        );
        break;
      case seedexTaskRecheck:
        _beginExistingRecheck(data['id'] as String? ?? '');
        break;
      case seedexTaskConfigure:
        final rawSettings = data['settings'];
        if (rawSettings is Map<Object?, Object?>) {
          _settings = AppSettings.fromJson(
            rawSettings.map<String, Object?>(
              (Object? key, Object? value) => MapEntry<String, Object?>(
                key.toString(),
                value,
              ),
            ),
          );
          _engine
            ..setDownloadLimit(_settings.downloadLimit)
            ..setUploadLimit(_settings.uploadLimit);
          unawaited(_applyNetworkPolicy());
          unawaited(_refreshTelegram());
        }
        break;
      case seedexTaskPauseAll:
        for (final id in _engineIds.keys.toList()) {
          _pause(id, userInitiated: true);
        }
        break;
      case seedexTaskResumeAll:
        for (final id in _engineIds.keys.toList()) {
          _resume(id, userInitiated: true);
        }
        break;
      case seedexTaskRefreshTelegram:
        unawaited(_refreshTelegram());
        break;
      case seedexTaskTelegramMessage:
        final text = data['text'] as String? ?? '';
        if (text.isNotEmpty) unawaited(_sendTelegramMessage(text));
        break;
    }
  }

  Future<void> _addRecord(TorrentRecord record) async {
    if (_engineIds.containsKey(record.id)) return;
    _records[record.id] = record;
    try {
      final engineId = switch (record.inputType) {
        TorrentInputType.magnet =>
          _engine.addMagnet(record.inputValue, record.savePath),
        TorrentInputType.file =>
          _engine.addTorrentFile(record.inputValue, record.savePath),
      };
      _engineIds[record.id] = engineId;

      if (record.startMode == TorrentStartMode.existingData) {
        if (record.inputType == TorrentInputType.magnet) {
          _verification[record.id] =
              _ExistingVerificationStage.waitingMetadata;
        } else {
          _verification[record.id] = _ExistingVerificationStage.checking;
          _verificationStartedTick[record.id] = _tick;
          _engine.pauseTorrent(engineId);
          _engine.recheckTorrent(engineId);
        }
      }
      if (record.paused) {
        _userPaused.add(record.id);
        _engine.pauseTorrent(engineId);
      }
    } on Object catch (error) {
      _sendServiceError(
        type: 'engineError',
        id: record.id,
        message: error.toString(),
      );
    }
  }

  void _updateExistingVerification(String uid, TorrentInfo info) {
    final stage = _verification[uid];
    if (stage == null || stage == _ExistingVerificationStage.verified) return;
    final engineId = _engineIds[uid];
    if (engineId == null) return;

    if (stage == _ExistingVerificationStage.waitingMetadata) {
      if (info.hasMetadata) {
        _engine.pauseTorrent(engineId);
        _engine.recheckTorrent(engineId);
        _verification[uid] = _ExistingVerificationStage.checking;
        _verificationStartedTick[uid] = _tick;
      }
      return;
    }
    if (stage == _ExistingVerificationStage.failed) return;

    final startedAt = _verificationStartedTick[uid] ?? _tick;
    if (_tick - startedAt < 3 ||
        info.state == TorrentState.checkingFiles ||
        info.state == TorrentState.checkingResume ||
        info.state == TorrentState.allocating) {
      return;
    }
    if (info.progress >= 0.9999 ||
        info.isFinished ||
        info.state == TorrentState.finished ||
        info.state == TorrentState.seeding) {
      _verification[uid] = _ExistingVerificationStage.verified;
      _verificationStartedTick.remove(uid);
      if (!_userPaused.contains(uid) &&
          !_policyPaused.contains(uid) &&
          _networkAllowed) {
        _engine.resumeTorrent(engineId);
      }
      return;
    }
    if (info.hasMetadata && info.state == TorrentState.downloading) {
      _verification[uid] = _ExistingVerificationStage.failed;
      _verificationStartedTick.remove(uid);
      _engine.pauseTorrent(engineId);
    }
  }

  void _beginExistingRecheck(String uid) {
    final engineId = _engineIds[uid];
    if (engineId == null) return;
    final record = _records[uid];
    if (record?.startMode != TorrentStartMode.existingData) {
      _engine.recheckTorrent(engineId);
      return;
    }
    if (_latest[engineId]?.hasMetadata == false &&
        record?.inputType == TorrentInputType.magnet) {
      _verification[uid] = _ExistingVerificationStage.waitingMetadata;
      if (!_userPaused.contains(uid) && !_policyPaused.contains(uid)) {
        _engine.resumeTorrent(engineId);
      }
      return;
    }
    _verification[uid] = _ExistingVerificationStage.checking;
    _verificationStartedTick[uid] = _tick;
    _engine.pauseTorrent(engineId);
    _engine.recheckTorrent(engineId);
  }

  void _pause(String uid, {required bool userInitiated}) {
    final engineId = _engineIds[uid];
    if (engineId == null) return;
    if (userInitiated) _userPaused.add(uid);
    _engine.pauseTorrent(engineId);
  }

  void _resume(String uid, {required bool userInitiated}) {
    final engineId = _engineIds[uid];
    if (engineId == null) return;
    if (userInitiated) _userPaused.remove(uid);
    if (_policyPaused.contains(uid)) return;

    final stage = _verification[uid];
    if (stage == _ExistingVerificationStage.failed) {
      _beginExistingRecheck(uid);
    } else if (stage == _ExistingVerificationStage.waitingMetadata) {
      _engine.resumeTorrent(engineId);
    } else if (stage == _ExistingVerificationStage.checking) {
      return;
    } else {
      _engine.resumeTorrent(engineId);
    }
  }

  void _remove(String uid, {required bool deleteFiles}) {
    final engineId = _engineIds.remove(uid);
    if (engineId == null) return;
    _latest.remove(engineId);
    _records.remove(uid);
    _verification.remove(uid);
    _verificationStartedTick.remove(uid);
    _userPaused.remove(uid);
    _policyPaused.remove(uid);
    _engine.removeTorrent(engineId, deleteFiles: deleteFiles);
    unawaited(_publish(forcePersist: true));
  }

  bool get _networkAllowed {
    if (_connectivity.contains(ConnectivityResult.none) ||
        _connectivity.isEmpty) {
      return false;
    }
    final hasWifi = _connectivity.contains(ConnectivityResult.wifi) ||
        _connectivity.contains(ConnectivityResult.ethernet);
    final hasMobile = _connectivity.contains(ConnectivityResult.mobile) ||
        _connectivity.contains(ConnectivityResult.satellite);
    if (_settings.wifiOnly) return hasWifi;
    if (hasMobile && !_settings.cellularAllowed && !hasWifi) return false;
    return true;
  }

  Future<void> _applyNetworkPolicy() async {
    if (_networkAllowed) {
      for (final uid in _policyPaused.toList()) {
        _policyPaused.remove(uid);
        if (!_userPaused.contains(uid)) _resume(uid, userInitiated: false);
      }
      return;
    }
    for (final uid in _engineIds.keys) {
      if (!_userPaused.contains(uid)) {
        _policyPaused.add(uid);
        _pause(uid, userInitiated: false);
      }
    }
  }

  Future<void> _trackCompletion(String uid, String name) async {
    if (_completionMarkers.contains(uid)) return;
    _completionMarkers.add(uid);
    await _store.saveTelegramCompletionMarkers(_completionMarkers);
    if (_settings.telegramEnabled &&
        _settings.telegramCompletionNotifications) {
      final record = _records[uid];
      final displayName = name.isEmpty ? record?.displayName ?? 'Torrent' : name;
      await _sendTelegramMessage(
        '✅ Seedex is now seeding\n$displayName\n'
        'The phone has verified or downloaded 100% of the payload.',
      );
    }
  }

  Future<void> _refreshTelegram() async {
    final generation = ++_telegramGeneration;
    _telegramClient?.close();
    _telegramClient = null;
    _telegramCredentials = null;
    if (!_settings.telegramEnabled || _destroyed) return;

    try {
      final credentials = await _credentialsStore.read();
      if (credentials == null || generation != _telegramGeneration) return;
      final client = TelegramBotClient(token: credentials.botToken);
      _telegramCredentials = credentials;
      _telegramClient = client;
      if (_settings.telegramRemoteCommands) {
        unawaited(_pollTelegram(generation, client, credentials));
      }
    } on Object {
      _sendServiceError(
        type: 'telegramError',
        message: 'Unable to open encrypted Telegram credentials.',
      );
    }
  }

  Future<void> _pollTelegram(
    int generation,
    TelegramBotClient client,
    TelegramCredentials credentials,
  ) async {
    while (!_destroyed && generation == _telegramGeneration) {
      try {
        final updates = await client.getUpdates(offset: _telegramOffset);
        for (final update in updates) {
          if (update.updateId >= _telegramOffset) {
            _telegramOffset = update.updateId + 1;
            await _store.saveTelegramUpdateOffset(_telegramOffset);
          }
          if (!TelegramCommandParser.isApprovedChat(
            update.chatId,
            credentials.chatId,
          )) {
            continue;
          }
          await _handleTelegramCommand(update.text);
        }
      } on Object {
        if (_destroyed || generation != _telegramGeneration) return;
        _sendServiceError(
          type: 'telegramError',
          message: 'Telegram polling is temporarily unavailable.',
        );
        await Future<void>.delayed(const Duration(seconds: 5));
      }
    }
  }

  Future<void> _handleTelegramCommand(String text) async {
    final command = TelegramCommandParser.parse(text);
    switch (command.type) {
      case TelegramCommandType.status:
        await _sendTelegramMessage(_telegramStatus());
        break;
      case TelegramCommandType.add:
        if (!TelegramCommandParser.isValidMagnet(command.argument)) {
          await _sendTelegramMessage(
            'Send /add followed by a valid magnet:?xt=urn:btih:… link.',
          );
          return;
        }
        final record = await _addTelegramMagnet(command.argument);
        await _sendTelegramMessage(
          'Added ${record.displayName}. Seedex will download the payload, '
          'then continue seeding it.',
        );
        break;
      case TelegramCommandType.pauseAll:
        for (final uid in _engineIds.keys.toList()) {
          _pause(uid, userInitiated: true);
        }
        await _persistRemotePause(paused: true);
        await _sendTelegramMessage('All Seedex torrents are paused.');
        break;
      case TelegramCommandType.resumeAll:
        for (final uid in _engineIds.keys.toList()) {
          _resume(uid, userInitiated: true);
        }
        await _persistRemotePause(paused: false);
        await _sendTelegramMessage('Seedex resumed all allowed torrents.');
        break;
      case TelegramCommandType.help:
        await _sendTelegramMessage(
          'Seedex commands\n'
          '/status — transfer summary\n'
          '/add <magnet> — download and seed\n'
          '/pauseall — pause every torrent\n'
          '/resumeall — resume every torrent',
        );
        break;
      case TelegramCommandType.unknown:
        await _sendTelegramMessage('Unknown command. Send /help for commands.');
        break;
    }
  }

  String _telegramStatus() {
    var downloadRate = 0;
    var uploadRate = 0;
    var active = 0;
    var seeding = 0;
    for (final info in _latest.values) {
      downloadRate += info.downloadRate;
      uploadRate += info.uploadRate;
      if (!info.isPaused) active++;
      if (info.state == TorrentState.seeding) seeding++;
    }
    return 'Seedex status\n'
        '${_engineIds.length} torrents · $active active · $seeding seeding\n'
        '↓ ${formatSpeed(downloadRate)} · ↑ ${formatSpeed(uploadRate)}\n'
        'Network policy: ${_networkAllowed ? 'allowed' : 'paused'}';
  }

  Future<TorrentRecord> _addTelegramMagnet(String magnet) async {
    if (_settings.downloadPath.isEmpty) {
      throw const TelegramApiException('Seedex download folder is not set.');
    }
    final normalized = magnet.trim();
    final detected = SourceDetector.fromMagnet(normalized);
    final record = TorrentRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      inputType: TorrentInputType.magnet,
      inputValue: normalized,
      displayName: SourceDetector.displayNameFromMagnet(normalized),
      savePath: _settings.downloadPath,
      addedAt: DateTime.now(),
      sourceDomain: 'telegram',
      sourceConfidence: SourceConfidence.manual,
      trackers: detected.trackers,
    );

    final snapshot = await _store.load();
    await _store.save(AppSnapshot(
      torrents: <TorrentRecord>[record, ...snapshot.torrents],
      goals: snapshot.goals,
      activity: snapshot.activity,
      settings: snapshot.settings,
    ));
    await _addRecord(record);
    FlutterForegroundTask.sendDataToMain(<String, Object?>{
      'type': 'telegramAdded',
      'record': record.toJson(),
    });
    return record;
  }

  Future<void> _persistRemotePause({required bool paused}) async {
    final snapshot = await _store.load();
    final records = snapshot.torrents.map((TorrentRecord record) {
      final updated = record.copyWith(paused: paused);
      _records[record.id] = updated;
      return updated;
    }).toList(growable: false);
    await _store.save(AppSnapshot(
      torrents: records,
      goals: snapshot.goals,
      activity: snapshot.activity,
      settings: snapshot.settings,
    ));
  }

  Future<void> _sendTelegramMessage(String text) async {
    if (!_settings.telegramEnabled || text.isEmpty) return;
    if (_telegramClient == null || _telegramCredentials == null) {
      await _refreshTelegram();
    }
    final client = _telegramClient;
    final credentials = _telegramCredentials;
    if (client == null || credentials == null) return;
    try {
      await client.sendMessage(chatId: credentials.chatId, text: text);
    } on Object {
      _sendServiceError(
        type: 'telegramError',
        message: 'Telegram could not deliver a Seedex message.',
      );
    }
  }

  void _sendServiceError({
    required String type,
    String id = '',
    required String message,
  }) {
    FlutterForegroundTask.sendDataToMain(<String, Object?>{
      'type': type,
      'id': id,
      'message': message,
    });
  }

  Future<void> _publish({required bool forcePersist}) async {
    var downloadRate = 0;
    var uploadRate = 0;
    var active = 0;
    final items = <Map<String, Object?>>[];

    for (final entry in _engineIds.entries) {
      final info = _latest[entry.value];
      if (info == null) continue;
      downloadRate += info.downloadRate;
      uploadRate += info.uploadRate;
      if (!info.isPaused) active++;

      final torrentLedger = _ledger.putIfAbsent(
        entry.key,
        () => <String, Map<String, int>>{},
      );
      torrentLedger[_sessionId] = <String, int>{
        'uploaded': math
            .max(
              info.totalUploaded,
              torrentLedger[_sessionId]?['uploaded'] ?? 0,
            )
            .toInt(),
        'seedingSeconds': math
            .max(
              _seedingSeconds[entry.key] ?? 0,
              torrentLedger[_sessionId]?['seedingSeconds'] ?? 0,
            )
            .toInt(),
      };

      final verification = _verification[entry.key];
      final status = switch (verification) {
        _ExistingVerificationStage.waitingMetadata => 'Getting metadata',
        _ExistingVerificationStage.checking => 'Checking files',
        _ExistingVerificationStage.failed => 'Files incomplete',
        _ => info.state.label,
      };
      final verificationError =
          verification == _ExistingVerificationStage.failed
              ? 'Existing files did not verify to 100%. Select the exact '
                  'content folder and run recheck.'
              : '';

      items.add(<String, Object?>{
        'id': entry.key,
        'name': info.name,
        'status': status,
        'progress': info.progress,
        'totalDone': info.totalDone,
        'totalWanted': info.totalWanted,
        'downloadRate': info.downloadRate,
        'uploadRate': info.uploadRate,
        'rawUploaded': info.totalUploaded,
        'sessionId': _sessionId,
        'sessionSeedingSeconds': _seedingSeconds[entry.key] ?? 0,
        'peers': info.numPeers,
        'seeds': info.numSeeds,
        'paused': _userPaused.contains(entry.key),
        'error': verificationError.isEmpty ? info.errorMsg : verificationError,
      });
    }

    FlutterForegroundTask.sendDataToMain(<String, Object?>{
      'type': 'snapshot',
      'items': items,
      'downloadRate': downloadRate,
      'uploadRate': uploadRate,
      'networkAllowed': _networkAllowed,
    });

    final idleTitle = _settings.telegramEnabled
        ? 'Seedex remote control is ready'
        : 'Seedex is ready';
    await FlutterForegroundTask.updateService(
      notificationTitle: active == 0 ? idleTitle : '$active torrents active',
      notificationText:
          '↓ ${formatSpeed(downloadRate)}  ·  ↑ ${formatSpeed(uploadRate)}',
    );

    if (forcePersist) await _store.saveEngineLedger(_ledger);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _destroyed = true;
    _telegramGeneration++;
    _telegramClient?.close();
    await _store.saveEngineLedger(_ledger);
    await _store.saveTelegramCompletionMarkers(_completionMarkers);
    await _torrentSubscription?.cancel();
    await _connectivitySubscription?.cancel();
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'pause_all') {
      for (final uid in _engineIds.keys.toList()) {
        _pause(uid, userInitiated: true);
      }
      unawaited(_persistRemotePause(paused: true));
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onNotificationDismissed() {}
}
