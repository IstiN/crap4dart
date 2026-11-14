import 'dart:convert';
import 'dart:io';

import 'package:crap4dart/src/profile/profile_shard_reader.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Writes a shard file named [name] with [json] content into [dir].
void writeShard(Directory dir, String name, Object json) {
  File(p.join(dir.path, name)).writeAsStringSync(jsonEncode(json));
}

void main() {
  late Directory dir;
  late File output;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('crap4dart_shardedge_');
    addTearDown(() => dir.deleteSync(recursive: true));
    output = File(p.join(dir.path, '.crap_profile.json'));
  });

  test('corrupt shard is skipped, valid shards still report', () {
    writeShard(dir, '.crap_profile.json.bad.json', {'A': 'not a map'});
    File(p.join(dir.path, '.crap_profile.json.corrupt.json'))
        .writeAsStringSync('{not json');
    writeShard(dir, '.crap_profile.json.good.json', {
      'A.b': {
        'calls': 4,
        'totalMicros': 40,
        'totalSelfMicros': 40,
        'minMicros': 10,
        'maxMicros': 10,
      },
    });
    final json = ProfileShardReader.read(output)!;
    expect(json['A.b']['calls'], 4);
  });

  test('tmp files are excluded', () {
    writeShard(dir, '.crap_profile.json.s.json.tmp.0', {
      'T.tmp': {
        'calls': 99,
        'totalMicros': 99,
        'totalSelfMicros': 99,
        'minMicros': 99,
        'maxMicros': 99,
      },
    });
    expect(ProfileShardReader.read(output), isNull);
  });
}
