import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

class LocalStore {
  LocalStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const String stateKey = 'seedex.state.v1';
  static const String engineLedgerKey = 'seedex.engine-ledger.v1';

  final SharedPreferencesAsync _preferences;

  Future<AppSnapshot> load() async {
    final encoded = await _preferences.getString(stateKey);
    if (encoded == null || encoded.isEmpty) {
      return const AppSnapshot(
        torrents: <TorrentRecord>[],
        goals: <SeedGoal>[],
        activity: <ActivitySample>[],
        settings: AppSettings(),
      );
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?>) throw const FormatException();
      final torrentValues =
          decoded['torrents'] as List<Object?>? ?? const <Object?>[];
      final goalValues = decoded['goals'] as List<Object?>? ?? const <Object?>[];
      final activityValues =
          decoded['activity'] as List<Object?>? ?? const <Object?>[];
      final rawSettings = decoded['settings'];

      return AppSnapshot(
        torrents: torrentValues
            .whereType<Map<String, Object?>>()
            .map(TorrentRecord.fromJson)
            .toList(growable: false),
        goals: goalValues
            .whereType<Map<String, Object?>>()
            .map(SeedGoal.fromJson)
            .toList(growable: false),
        activity: activityValues
            .whereType<Map<String, Object?>>()
            .map(ActivitySample.fromJson)
            .toList(growable: false),
        settings: rawSettings is Map<String, Object?>
            ? AppSettings.fromJson(rawSettings)
            : const AppSettings(),
      );
    } on Object {
      // A damaged state file should never prevent the app from opening.
      return const AppSnapshot(
        torrents: <TorrentRecord>[],
        goals: <SeedGoal>[],
        activity: <ActivitySample>[],
        settings: AppSettings(),
      );
    }
  }

  Future<void> save(AppSnapshot snapshot) async {
    final encoded = jsonEncode(<String, Object?>{
      'version': 1,
      'torrents': snapshot.torrents.map((TorrentRecord item) => item.toJson()).toList(),
      'goals': snapshot.goals.map((SeedGoal item) => item.toJson()).toList(),
      'activity': snapshot.activity
          .map((ActivitySample item) => item.toJson())
          .toList(),
      'settings': snapshot.settings.toJson(),
    });
    await _preferences.setString(stateKey, encoded);
  }

  Future<Map<String, Map<String, Map<String, int>>>> loadEngineLedger() async {
    final encoded = await _preferences.getString(engineLedgerKey);
    if (encoded == null || encoded.isEmpty) {
      return <String, Map<String, Map<String, int>>>{};
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?>) return <String, Map<String, Map<String, int>>>{};
      final result = <String, Map<String, Map<String, int>>>{};
      for (final torrentEntry in decoded.entries) {
        final rawSessions = torrentEntry.value;
        if (rawSessions is! Map<String, Object?>) continue;
        final sessions = <String, Map<String, int>>{};
        for (final sessionEntry in rawSessions.entries) {
          final rawValues = sessionEntry.value;
          if (rawValues is! Map<String, Object?>) continue;
          sessions[sessionEntry.key] = <String, int>{
            'uploaded': (rawValues['uploaded'] as num? ?? 0).toInt(),
            'seedingSeconds':
                (rawValues['seedingSeconds'] as num? ?? 0).toInt(),
          };
        }
        result[torrentEntry.key] = sessions;
      }
      return result;
    } on Object {
      return <String, Map<String, Map<String, int>>>{};
    }
  }

  Future<void> saveEngineLedger(
    Map<String, Map<String, Map<String, int>>> ledger,
  ) async {
    await _preferences.setString(engineLedgerKey, jsonEncode(ledger));
  }
}
