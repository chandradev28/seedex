import 'package:flutter_test/flutter_test.dart';
import 'package:seedex/src/services/telegram_bot_client.dart';

void main() {
  group('TelegramCommandParser', () {
    test('parses bot-addressed commands and valid hex info hashes', () {
      const magnet =
          'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567';
      final command = TelegramCommandParser.parse('/add@seedex_bot $magnet');

      expect(command.type, TelegramCommandType.add);
      expect(command.argument, magnet);
      expect(TelegramCommandParser.isValidMagnet(command.argument), isTrue);
    });

    test('accepts Base32 hashes and rejects malformed info hashes', () {
      expect(
        TelegramCommandParser.isValidMagnet(
          'magnet:?xt=urn:btih:ABCDEFGHIJKLMNOPQRSTUVWXYZ234567',
        ),
        isTrue,
      );
      expect(
        TelegramCommandParser.isValidMagnet(
          'magnet:?xt=urn:btih:0123456789abcdef',
        ),
        isFalse,
      );
      expect(
        TelegramCommandParser.isValidMagnet(
          'magnet:?xt=urn:btih:zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz',
        ),
        isFalse,
      );
    });

    test('recognizes control commands', () {
      expect(
        TelegramCommandParser.parse('/status').type,
        TelegramCommandType.status,
      );
      expect(
        TelegramCommandParser.parse('/pauseall').type,
        TelegramCommandType.pauseAll,
      );
      expect(
        TelegramCommandParser.parse('/resumeall').type,
        TelegramCommandType.resumeAll,
      );
    });

    test('requires an exact non-empty approved chat ID', () {
      expect(TelegramCommandParser.isApprovedChat('42', '42'), isTrue);
      expect(TelegramCommandParser.isApprovedChat('43', '42'), isFalse);
      expect(TelegramCommandParser.isApprovedChat('', ''), isFalse);
    });

    test('retains update IDs while ignoring non-text messages', () {
      final updates = TelegramBotClient.decodeUpdates(<Object?>[
        <String, Object?>{
          'update_id': 7,
          'message': <String, Object?>{
            'chat': <String, Object?>{'id': 42},
            'photo': <Object?>[],
          },
        },
        <String, Object?>{
          'update_id': 8,
          'message': <String, Object?>{
            'chat': <String, Object?>{'id': 42},
            'text': '/status',
          },
        },
      ]);

      expect(updates.map((TelegramUpdate item) => item.updateId), <int>[7, 8]);
      expect(updates.first.chatId, isEmpty);
      expect(updates.first.text, isEmpty);
      expect(updates.last.chatId, '42');
      expect(updates.last.text, '/status');
    });
  });
}
