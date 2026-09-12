import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:seedex/src/data/torrent_metadata_parser.dart';

void main() {
  group('TorrentMetadataParser', () {
    test('extracts a single-file name, payload size, and tracker', () {
      const encoded =
          'd8:announce32:https://tracker.example/announce4:info'
          'd6:lengthi12345e4:name10:sample.binee';

      final hint = TorrentMetadataParser.parse(
        Uint8List.fromList(ascii.encode(encoded)),
      );

      expect(hint.name, 'sample.bin');
      expect(hint.totalBytes, 12345);
      expect(hint.trackers, <String>['tracker.example']);
    });

    test('sums file lengths for a multi-file torrent', () {
      const encoded =
          'd4:infod5:filesl'
          'd6:lengthi10e4:pathl7:one.binee'
          'd6:lengthi15e4:pathl7:two.bineee'
          '4:name6:folderee';

      final hint = TorrentMetadataParser.parse(
        Uint8List.fromList(ascii.encode(encoded)),
      );

      expect(hint.name, 'folder');
      expect(hint.totalBytes, 25);
    });
  });
}
