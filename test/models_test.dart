import 'package:flutter_test/flutter_test.dart';
import 'package:seedex/src/domain/models.dart';

void main() {
  group('TorrentRecord', () {
    test('calculates ratio and a one-to-one target', () {
      final record = TorrentRecord(
        id: 'one',
        inputType: TorrentInputType.magnet,
        inputValue: 'magnet:?xt=urn:btih:test',
        displayName: 'Test',
        savePath: '/tmp',
        addedAt: DateTime(2026),
        totalDone: 1000,
        totalWanted: 1000,
        uploadedBytes: 750,
      );

      expect(record.ratio, 0.75);
      expect(record.ratioGoalProgress, 0.75);
      expect(record.remainingForRatio, 250);
    });

    test('round-trips start mode through local JSON', () {
      final original = TorrentRecord(
        id: 'two',
        inputType: TorrentInputType.file,
        inputValue: '/metadata/example.torrent',
        displayName: 'Example',
        savePath: '/downloads',
        addedAt: DateTime.utc(2026, 9, 12),
        startMode: TorrentStartMode.existingData,
        sourceDomain: 'example.org',
        sourceConfidence: SourceConfidence.manual,
        trackers: const <String>['tracker.example.org'],
        uploadLedger: const <String, int>{'session': 12},
      );

      final restored = TorrentRecord.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.startMode, TorrentStartMode.existingData);
      expect(restored.usesExistingData, isTrue);
      expect(restored.sourceDomain, 'example.org');
      expect(restored.trackers, <String>['tracker.example.org']);
      expect(restored.uploadLedger['session'], 12);
    });

    test('old records default to download and seed mode', () {
      final restored = TorrentRecord.fromJson(<String, Object?>{
        'id': 'legacy',
      });

      expect(restored.startMode, TorrentStartMode.downloadAndSeed);
      expect(restored.usesExistingData, isFalse);
    });
  });

  group('AppSettings', () {
    test('round-trips Telegram feature switches without credentials', () {
      const original = AppSettings(
        telegramEnabled: true,
        telegramRemoteCommands: false,
        telegramCompletionNotifications: true,
        telegramGoalNotifications: false,
      );

      final restored = AppSettings.fromJson(original.toJson());
      expect(restored.telegramEnabled, isTrue);
      expect(restored.telegramRemoteCommands, isFalse);
      expect(restored.telegramCompletionNotifications, isTrue);
      expect(restored.telegramGoalNotifications, isFalse);
      expect(restored.toJson().containsKey('botToken'), isFalse);
    });
  });

  group('SeedGoal', () {
    test('tracks progress after its baseline', () {
      final goal = SeedGoal(
        id: 'goal',
        title: 'Seed 1 TB',
        metric: GoalMetric.uploadedBytes,
        target: 1000,
        baseline: 500,
        createdAt: DateTime(2026),
      );

      expect(goal.progress(750), 0.25);
      expect(goal.progress(1500), 1);
    });
  });
}
