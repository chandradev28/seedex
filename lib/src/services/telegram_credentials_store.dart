import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TelegramCredentials {
  const TelegramCredentials({required this.botToken, required this.chatId});

  final String botToken;
  final String chatId;
}

class TelegramCredentialsStore {
  TelegramCredentialsStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _tokenKey = 'seedex.telegram.bot-token.v1';
  static const String _chatIdKey = 'seedex.telegram.chat-id.v1';

  final FlutterSecureStorage _storage;

  Future<TelegramCredentials?> read() async {
    final token = (await _storage.read(key: _tokenKey))?.trim() ?? '';
    final chatId = (await _storage.read(key: _chatIdKey))?.trim() ?? '';
    if (token.isEmpty || chatId.isEmpty) return null;
    return TelegramCredentials(botToken: token, chatId: chatId);
  }

  Future<void> write(TelegramCredentials credentials) async {
    final token = credentials.botToken.trim();
    final chatId = credentials.chatId.trim();
    if (token.isEmpty || chatId.isEmpty) {
      throw const FormatException('Bot token and approved chat ID are required.');
    }
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _chatIdKey, value: chatId);
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _chatIdKey);
  }
}
