import 'package:flutter_test/flutter_test.dart';
import 'package:seedex/src/services/telegram_bot_client.dart';

void main() {
  group('TelegramCommandParser', () {
    test('parses bot-addressed commands and magnet arguments', () {
      const magnet = 'magnet:?xt=urn:btih:0123456789abcdef';
      final command = TelegramCommandParser.parse('/add@seedex_bot $magnet');

      expect(command.type, TelegramCommandType.add);
      expect(command.argument, magnet);
      expect(TelegramCommandParser.isValidMagnet(command.argument), isTrue);
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
  });
}
