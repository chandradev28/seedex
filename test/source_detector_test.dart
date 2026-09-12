import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:seedex/src/data/source_detector.dart';
import 'package:seedex/src/data/torrent_metadata_parser.dart';

void main() {
  test('extracts a shared magnet and exact page URL', () {
    const text =
        'Download https://example.org/releases/42 magnet:?xt=urn:btih:ABC&dn=Open%20Data';
    final magnet = SourceDetector.magnetFromText(text);
    final page = SourceDetector.webUrlFromText(text);
    final source = SourceDetector.fromMagnet(magnet!, sharedUrl: page!);

    expect(magnet, contains('urn:btih:ABC'));
    expect(source.domain, 'example.org');
    expect(source.isExact, isTrue);
    expect(SourceDetector.displayNameFromMagnet(magnet), 'Open Data');
  });

  test('labels a magnet tracker as inferred', () {
    const magnet =
        'magnet:?xt=urn:btih:ABC&tr=udp%3A%2F%2Ftracker.example.net%3A80';
    final source = SourceDetector.fromMagnet(magnet);

    expect(source.domain, 'tracker.example.net');
    expect(source.isExact, isFalse);
    expect(source.trackers, contains('tracker.example.net'));
  });

  test('reads tracker domains from bencoded torrent metadata', () {
    final bytes = Uint8List.fromList(
      ascii.encode('d8:announce23:udp://tracker.test:80/ae'),
    );
    final hint = TorrentMetadataParser.parse(bytes);
    expect(hint.trackers, <String>['tracker.test']);
  });
}
