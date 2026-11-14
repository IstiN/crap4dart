import 'dart:convert';
import 'dart:io';

import 'package:crap4dart/src/profile/profile_shard_reader.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late File output;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('crap4dart_shardreader_');
    addTearDown(() => dir.deleteSync(recursive: true));
    output = File(p.join(dir.path, '.crap_profile.json'));
  });

  void writeShard(String name, Object json) {
    File(p.join(dir.path, name)).writeAsStringSync(jsonEncode(json));
  }

  test('null when no output exists', () {
    expect(ProfileShardReader.read(output), isNull);
    expect(ProfileShardReader.readTimings(output), isNull);
  });

  test('sums calls and totals across shards, keeps min/max extremes', () {
    writeShard('.crap_profile.json.a.json', {
      'A.b': {
        'calls': 10,
        'totalMicros': 100,
        'totalSelfMicros': 80,
        'minMicros': 5,
        'maxMicros': 20,
      },
    });
    writeShard('.crap_profile.json.b.json', {
      'A.b': {
        'calls': 2,
        'totalMicros': 30,
        'totalSelfMicros': 20,
        'minMicros': 9,
        'maxMicros': 21,
      },
    });
    final json = ProfileShardReader.read(output)!;
    expect(json['A.b']['calls'], 12);
    expect(json['A.b']['totalMicros'], 130);
    expect(json['A.b']['totalSelfMicros'], 100);
    expect(json['A.b']['minMicros'], 5);
    expect(json['A.b']['maxMicros'], 21);
  });

  test('plain output file merges alongside shards (legacy/debug)', () {
    output.writeAsStringSync(jsonEncode({
      'A.b': {
        'calls': 1,
        'totalMicros': 7,
        'totalSelfMicros': 7,
        'minMicros': 7,
        'maxMicros': 7,
      },
    }));
    writeShard('.crap_profile.json.s.json', {
      'A.b': {
        'calls': 1,
        'totalMicros': 3,
        'totalSelfMicros': 3,
        'minMicros': 2,
        'maxMicros': 3,
      },
    });
    final json = ProfileShardReader.read(output)!;
    expect(json['A.b']['calls'], 2);
    expect(json['A.b']['minMicros'], 2);
  });
}
