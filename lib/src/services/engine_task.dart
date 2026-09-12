import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart' hide formatSpeed;

import '../core/formatters.dart';
import '../data/local_store.dart';
import '../domain/models.dart';

const String seedexTaskAdd = 'add';
const String seedexTaskPause = 'pause';
const String seedexTaskResume = 'resume';
const String seedexTaskRemove = 'remove';
const String seedexTaskRecheck = 'recheck';
const String seedexTaskConfigure = 'configure';
const String seedexTaskPauseAll = 'pauseAll';
const String seedexTaskResumeAll = 'resumeAll';

@pragma('vm:entry-point')
void startSeedexTask() {
  FlutterForegroundTask.setTaskHandler(SeedexTaskHandler());
}

class SeedexTaskHandler extends TaskHandler {
  final LocalStore _store = LocalStore();
  final Map<String, int> _engineIds = <String, int>{};
  final Map<int, TorrentInfo> _latest = <int, TorrentInfo>{};
  final Map<String, int> _seedingSeconds = <String, int>{};
  final Set<String> _userPaused = <String>{};
  final Set<String> _policyPaused = <String>{};

  late final String _sessionId;
  AppSettings _settings = const AppSettings();
  Map<String, Map<String, Map<String, int>>> _ledger =
      <String, Map<String, Map<String, int>>>{};
  StreamSubscription<Map<int, TorrentInfo>>? _torrentSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  List<ConnectivityResult> _connectivity = const <ConnectivityResult>[];
  int _tick = 0;

  LibtorrentFlutter get _engine => LibtorrentFlutter.instance;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _sessionId = timestamp.microsecondsSinceEpoch.toString();
    final snapshot = await _store.load();
    _settings = snapshot.settings;
    _ledger = await _store.loadEngineLedger();

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
    await _publish(forcePersist: true);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_onTick());
  }

  Future<void> _onTick() async {
    _tick++;
    if (_tick % 10 == 0) {
      _connectivity = await Connectivity().checkConnectivity();
      await _applyNetworkPolicy();
    }
    for (final entry in _engineIds.entries) {
      final info = _latest[entry.value];
      if (info != null && info.state == TorrentState.seeding && !info.isPaused) {
        _seedingSeconds.update(
          entry.key,
          (int value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      if (info != null &&
          !_settings.continueAfterGoal &&
          info.totalWanted > 0) {
        final record = await _recordFor(entry.key);
        if (record != null &&
            info.totalUploaded >= info.totalWanted * record.ratioTarget &&
            !info.isPaused) {
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
        final id = _engineIds[data['id'] as String? ?? ''];
        if (id != null) _engine.recheckTorrent(id);
        break;
      case seedexTaskConfigure:
        final rawSettings = data['settings'];
        if (rawSettings is Map<Object?, Object?>) {
          _settings = AppSettings.fromJson(rawSettings.map<String, Object?>(
            (Object? key, Object? value) => MapEntry<String, Object?>(
              key.toString(),
              value,
            ),
          ));
          _engine
            ..setDownloadLimit(_settings.downloadLimit)
            ..setUploadLimit(_settings.uploadLimit);
          unawaited(_applyNetworkPolicy());
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
    }
  }

  Future<void> _addRecord(TorrentRecord record) async {
    if (_engineIds.containsKey(record.id)) return;
    try {
      final engineId = switch (record.inputType) {
        TorrentInputType.magnet =>
          _engine.addMagnet(record.inputValue, record.savePath),
        TorrentInputType.file =>
          _engine.addTorrentFile(record.inputValue, record.savePath),
      };
      _engineIds[record.id] = engineId;
      if (record.paused) {
        _userPaused.add(record.id);
        _engine.pauseTorrent(engineId);
      }
    } on Object catch (error) {
      FlutterForegroundTask.sendDataToMain(<String, Object?>{
        'type': 'engineError',
        'id': record.id,
        'message': error.toString(),
      });
    }
  }

  Future<TorrentRecord?> _recordFor(String uid) async {
    final snapshot = await _store.load();
    for (final record in snapshot.torrents) {
      if (record.id == uid) return record;
    }
    return null;
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
    if (!_policyPaused.contains(uid)) _engine.resumeTorrent(engineId);
  }

  void _remove(String uid, {required bool deleteFiles}) {
    final engineId = _engineIds.remove(uid);
    if (engineId == null) return;
    _latest.remove(engineId);
    _userPaused.remove(uid);
    _policyPaused.remove(uid);
    _engine.removeTorrent(engineId, deleteFiles: deleteFiles);
    unawaited(_publish(forcePersist: true));
  }

  bool get _networkAllowed {
    if (_connectivity.contains(ConnectivityResult.none) || _connectivity.isEmpty) {
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

      items.add(<String, Object?>{
        'id': entry.key,
        'name': info.name,
        'status': info.state.label,
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
        'paused': info.isPaused,
        'error': info.errorMsg,
      });
    }

    FlutterForegroundTask.sendDataToMain(<String, Object?>{
      'type': 'snapshot',
      'items': items,
      'downloadRate': downloadRate,
      'uploadRate': uploadRate,
      'networkAllowed': _networkAllowed,
    });

    await FlutterForegroundTask.updateService(
      notificationTitle: active == 0 ? 'Seedex is ready' : '$active torrents active',
      notificationText:
          '↓ ${formatSpeed(downloadRate)}  ·  ↑ ${formatSpeed(uploadRate)}',
    );

    if (forcePersist) await _store.saveEngineLedger(_ledger);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _store.saveEngineLedger(_ledger);
    await _torrentSubscription?.cancel();
    await _connectivitySubscription?.cancel();
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'pause_all') {
      for (final uid in _engineIds.keys.toList()) {
        _pause(uid, userInitiated: true);
      }
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onNotificationDismissed() {}
}
