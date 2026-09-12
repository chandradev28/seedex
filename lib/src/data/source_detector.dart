class DetectedSource {
  const DetectedSource({
    required this.domain,
    required this.url,
    required this.trackers,
    required this.isExact,
  });

  final String domain;
  final String url;
  final List<String> trackers;
  final bool isExact;
}

class SourceDetector {
  const SourceDetector._();

  static final RegExp _magnetPattern = RegExp(
    r'magnet:\?[^\s<>"\']+',
    caseSensitive: false,
  );

  static final RegExp _webPattern = RegExp(
    r'https?://[^\s<>"\']+',
    caseSensitive: false,
  );

  static String? magnetFromText(String text) {
    final match = _magnetPattern.firstMatch(text);
    return match == null ? null : _trimPunctuation(match.group(0)!);
  }

  static String? webUrlFromText(String text) {
    for (final match in _webPattern.allMatches(text)) {
      final value = _trimPunctuation(match.group(0)!);
      if (!value.toLowerCase().startsWith('magnet:')) return value;
    }
    return null;
  }

  static DetectedSource fromMagnet(
    String magnet, {
    String sharedUrl = '',
    String referrer = '',
  }) {
    final trackers = <String>{};
    try {
      final uri = Uri.parse(magnet);
      for (final tracker in uri.queryParametersAll['tr'] ?? const <String>[]) {
        final domain = domainOf(tracker);
        if (domain.isNotEmpty) trackers.add(domain);
      }
    } on FormatException {
      // Validation is handled by the add flow. Source attribution stays unknown.
    }

    final exactUrl = sharedUrl.isNotEmpty ? sharedUrl : referrer;
    return DetectedSource(
      domain: exactUrl.isNotEmpty
          ? domainOf(exactUrl)
          : (trackers.isEmpty ? '' : trackers.first),
      url: exactUrl,
      trackers: trackers.toList(growable: false),
      isExact: exactUrl.isNotEmpty,
    );
  }

  static String displayNameFromMagnet(String magnet) {
    try {
      final uri = Uri.parse(magnet);
      final name = uri.queryParameters['dn'];
      if (name != null && name.trim().isNotEmpty) return name.trim();
    } on FormatException {
      // Fall through to the neutral pending name.
    }
    return 'Fetching metadata';
  }

  static String domainOf(String rawUrl) {
    try {
      final normalized = rawUrl.contains('://') ? rawUrl : 'https://$rawUrl';
      final host = Uri.parse(normalized).host.toLowerCase();
      return host.startsWith('www.') ? host.substring(4) : host;
    } on FormatException {
      return '';
    }
  }

  static String _trimPunctuation(String value) =>
      value.replaceFirst(RegExp(r'[),.;\]]+$'), '');
}
