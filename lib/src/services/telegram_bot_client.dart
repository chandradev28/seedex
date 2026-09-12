import 'dart:convert';
import 'dart:io';

class TelegramApiException implements Exception {
  const TelegramApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TelegramBotIdentity {
  const TelegramBotIdentity({
    required this.id,
    required this.username,
    required this.displayName,
  });

  final int id;
  final String username;
  final String displayName;
}

class TelegramUpdate {
  const TelegramUpdate({
    required this.updateId,
    required this.chatId,
    required this.text,
  });

  final int updateId;
  final String chatId;
  final String text;
}

class TelegramBotClient {
  TelegramBotClient({
    required String token,
    HttpClient? httpClient,
    Uri? apiBase,
  }) : _token = token.trim(),
       _httpClient = httpClient ?? HttpClient(),
       _apiBase = apiBase ?? Uri.parse('https://api.telegram.org') {
    _httpClient.connectionTimeout = const Duration(seconds: 12);
  }

  final String _token;
  final HttpClient _httpClient;
  final Uri _apiBase;

  Future<TelegramBotIdentity> getMe() async {
    final payload = await _post('getMe');
    final result = payload['result'];
    if (result is! Map<String, Object?>) {
      throw const TelegramApiException(
        'Telegram returned an invalid bot profile.',
      );
    }
    return TelegramBotIdentity(
      id: (result['id'] as num? ?? 0).toInt(),
      username: result['username'] as String? ?? '',
      displayName: result['first_name'] as String? ?? 'Seedex bot',
    );
  }

  Future<void> sendMessage({
    required String chatId,
    required String text,
  }) async {
    await _post('sendMessage', <String, String>{
      'chat_id': chatId,
      'text': text,
      'disable_web_page_preview': 'true',
    });
  }

  Future<List<TelegramUpdate>> getUpdates({
    required int offset,
    int timeoutSeconds = 25,
  }) async {
    final payload = await _post('getUpdates', <String, String>{
      'offset': offset.toString(),
      'timeout': timeoutSeconds.clamp(0, 30).toString(),
      'allowed_updates': jsonEncode(<String>['message']),
    });
    return decodeUpdates(payload['result']);
  }

  static List<TelegramUpdate> decodeUpdates(Object? rawResult) {
    if (rawResult is! List<Object?>) return const <TelegramUpdate>[];

    final updates = <TelegramUpdate>[];
    for (final rawUpdate in rawResult) {
      if (rawUpdate is! Map<String, Object?>) continue;
      final updateId = (rawUpdate['update_id'] as num?)?.toInt();
      if (updateId == null) continue;

      var chatId = '';
      var text = '';
      final message = rawUpdate['message'];
      if (message is Map<String, Object?>) {
        final chat = message['chat'];
        final messageText = message['text'];
        final numericChatId = chat is Map<String, Object?>
            ? (chat['id'] as num?)?.toInt()
            : null;
        if (numericChatId != null && messageText is String) {
          chatId = numericChatId.toString();
          text = messageText;
        }
      }
      updates.add(
        TelegramUpdate(updateId: updateId, chatId: chatId, text: text),
      );
    }
    return updates;
  }

  Future<Map<String, Object?>> _post(
    String method, [
    Map<String, String> parameters = const <String, String>{},
  ]) async {
    if (_token.isEmpty) {
      throw const TelegramApiException('Telegram bot token is empty.');
    }
    final endpoint = _apiBase.replace(
      path: '${_apiBase.path}/bot$_token/$method'.replaceAll('//', '/'),
    );
    final request = await _httpClient.postUrl(endpoint);
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    request.write(
      parameters.entries
          .map(
            (MapEntry<String, String> entry) =>
                '${Uri.encodeQueryComponent(entry.key)}='
                '${Uri.encodeQueryComponent(entry.value)}',
          )
          .join('&'),
    );

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != HttpStatus.ok) {
      throw TelegramApiException(
        'Telegram request failed with HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?> || decoded['ok'] != true) {
      throw const TelegramApiException(
        'Telegram rejected the request. Check the bot token and chat ID.',
      );
    }
    return decoded;
  }

  void close() => _httpClient.close(force: true);
}

enum TelegramCommandType { status, add, pauseAll, resumeAll, help, unknown }

class TelegramCommand {
  const TelegramCommand({required this.type, this.argument = ''});

  final TelegramCommandType type;
  final String argument;
}

class TelegramCommandParser {
  const TelegramCommandParser._();

  static TelegramCommand parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const TelegramCommand(type: TelegramCommandType.unknown);
    }
    final separator = trimmed.indexOf(RegExp(r'\s'));
    final rawCommand = separator < 0
        ? trimmed
        : trimmed.substring(0, separator);
    final command = rawCommand.split('@').first.toLowerCase();
    final argument = separator < 0 ? '' : trimmed.substring(separator).trim();
    return switch (command) {
      '/status' => const TelegramCommand(type: TelegramCommandType.status),
      '/add' => TelegramCommand(
        type: TelegramCommandType.add,
        argument: argument,
      ),
      '/pauseall' => const TelegramCommand(type: TelegramCommandType.pauseAll),
      '/resumeall' => const TelegramCommand(
        type: TelegramCommandType.resumeAll,
      ),
      '/help' ||
      '/start' => const TelegramCommand(type: TelegramCommandType.help),
      _ => const TelegramCommand(type: TelegramCommandType.unknown),
    };
  }

  static bool isValidMagnet(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme.toLowerCase() != 'magnet') return false;

    const prefix = 'urn:btih:';
    final exactTopics = uri.queryParametersAll['xt'] ?? const <String>[];
    return exactTopics.any((String item) {
      final normalized = item.trim();
      if (!normalized.toLowerCase().startsWith(prefix)) return false;
      final infoHash = normalized.substring(prefix.length);
      return RegExp(
        r'^(?:[0-9A-Fa-f]{40}|[A-Za-z2-7]{32})$',
      ).hasMatch(infoHash);
    });
  }

  static bool isApprovedChat(String candidate, String approvedChatId) {
    return candidate.trim() == approvedChatId.trim() &&
        approvedChatId.trim().isNotEmpty;
  }
}
