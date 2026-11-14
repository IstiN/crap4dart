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
    dir = Directory.systemTemp.createTempSync('crap4dart_shardtimings_');
    addTearDown(() => dir.deleteSync(recursive: true));
    output = File(p.join(dir.path, '.crap_profile.json'));
  });

  test('readTimings sorts by total and skips # diagnostics', () {
    writeShard(dir, '.crap_profile.json.s.json', {
      '#flushes': {'calls': 3},
      'A.slow': {
        'calls': 1,
        'totalMicros': 500,
        'totalSelfMicros': 100,
        'minMicros': 500,
        'maxMicros': 500,
      },
      'A.fast': {
        'calls': 2,
        'totalMicros': 10,
        'totalSelfMicros': 10,
        'minMicros': 5,
        'maxMicros': 5,
      },
      'topLevel': {
        'calls': 1,
        'totalMicros': 1,
        'totalSelfMicros': 1,
        'minMicros': 1,
        'maxMicros': 1,
      },
    });
    final timings = ProfileShardReader.readTimings(output)!;
    expect(timings, hasLength(3));
    expect(timings[0].methodName, 'slow');
    expect(timings[1].methodName, 'fast');
    expect(timings[2].className, '(top-level)');
    expect(timings[2].methodName, 'topLevel');
  });
}
