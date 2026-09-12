import 'dart:convert';
import 'dart:typed_data';

import 'source_detector.dart';

class TorrentMetadataHint {
  const TorrentMetadataHint({
    this.trackers = const <String>[],
    this.comment = '',
    this.createdBy = '',
  });

  final List<String> trackers;
  final String comment;
  final String createdBy;
}

class TorrentMetadataParser {
  const TorrentMetadataParser._();

  static TorrentMetadataHint parse(Uint8List bytes) {
    if (bytes.length > 8 * 1024 * 1024) {
      throw const FormatException('Torrent metadata is unexpectedly large');
    }
    final value = _BencodeReader(bytes).read();
    if (value is! Map<String, Object?>) {
      throw const FormatException('Torrent metadata must be a dictionary');
    }

    final trackerUrls = <String>{};
    final announce = _string(value['announce']);
    if (announce.isNotEmpty) trackerUrls.add(announce);
    _collectStrings(value['announce-list'], trackerUrls);

    final domains = trackerUrls
        .map(SourceDetector.domainOf)
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);

    return TorrentMetadataHint(
      trackers: domains,
      comment: _string(value['comment']),
      createdBy: _string(value['created by']),
    );
  }

  static void _collectStrings(Object? value, Set<String> output) {
    if (value is Uint8List) {
      final decoded = _string(value);
      if (decoded.isNotEmpty) output.add(decoded);
    } else if (value is List<Object?>) {
      for (final child in value) {
        _collectStrings(child, output);
      }
    }
  }

  static String _string(Object? value) {
    if (value is! Uint8List) return '';
    return utf8.decode(value, allowMalformed: true).trim();
  }
}

class _BencodeReader {
  _BencodeReader(this.bytes);

  final Uint8List bytes;
  int offset = 0;

  Object? read() {
    final value = _readValue();
    if (offset != bytes.length) {
      throw const FormatException('Trailing torrent metadata');
    }
    return value;
  }

  Object? _readValue() {
    if (offset >= bytes.length) throw const FormatException('Unexpected end');
    final marker = bytes[offset];
    if (marker == 105) return _readInteger(); // i
    if (marker == 108) return _readList(); // l
    if (marker == 100) return _readDictionary(); // d
    if (marker >= 48 && marker <= 57) return _readBytes();
    throw FormatException('Unknown bencode marker at $offset');
  }

  int _readInteger() {
    offset++;
    final end = _indexOf(101); // e
    final raw = ascii.decode(bytes.sublist(offset, end));
    offset = end + 1;
    final value = int.tryParse(raw);
    if (value == null) throw const FormatException('Invalid bencode integer');
    return value;
  }

  List<Object?> _readList() {
    offset++;
    final result = <Object?>[];
    while (_peek() != 101) {
      result.add(_readValue());
    }
    offset++;
    return result;
  }

  Map<String, Object?> _readDictionary() {
    offset++;
    final result = <String, Object?>{};
    while (_peek() != 101) {
      final keyBytes = _readBytes();
      final key = utf8.decode(keyBytes, allowMalformed: true);
      result[key] = _readValue();
    }
    offset++;
    return result;
  }

  Uint8List _readBytes() {
    final colon = _indexOf(58); // :
    final rawLength = ascii.decode(bytes.sublist(offset, colon));
    final length = int.tryParse(rawLength);
    if (length == null || length < 0) {
      throw const FormatException('Invalid byte string length');
    }
    offset = colon + 1;
    final end = offset + length;
    if (end > bytes.length) throw const FormatException('Truncated byte string');
    final value = Uint8List.sublistView(bytes, offset, end);
    offset = end;
    return value;
  }

  int _peek() {
    if (offset >= bytes.length) throw const FormatException('Unexpected end');
    return bytes[offset];
  }

  int _indexOf(int byte) {
    for (var index = offset; index < bytes.length; index++) {
      if (bytes[index] == byte) return index;
    }
    throw const FormatException('Missing bencode delimiter');
  }
}
