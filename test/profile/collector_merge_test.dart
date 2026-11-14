import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'collector_driver_harness.dart';
import 'collector_flush_test.dart' show mergeShards;

/// Driver bodies, kept top-level so `main` stays under the repo's
/// method-size gate.
const isolateOneDriver = '''
  final c = CrapCollector.instance;
  for (var i = 0; i < 10; i++) {
    c.enter('A.b');
    c.exit('A.b');
  }
  c.flush();
''';

const isolateTwoDriver = '''
  final c = CrapCollector.instance;
  for (var i = 0; i < 32; i++) {
    c.enter('A.b');
    c.exit('A.b');
  }
  c.flush();
''';

const manyMethodsDriver = '''
  final c = CrapCollector.instance;
  for (var i = 0; i < 300; i++) {
    for (var k = 0; k < 10; k++) {
      c.enter('C.m\$i');
      c.exit('C.m\$i');
    }
  }
  c.flush();
''';

/// Shard file names (excluding tmp files) inside [dir].
List<String> shardNames(Directory dir) => dir
    .listSync()
    .whereType<File>()
    .map((f) => p.basename(f.path))
    .where((n) => n.startsWith('timings.json.') && n.endsWith('.json'))
    .toList();

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('crap4dart_merge_');
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  test(
    // Two isolates (separate processes here) write their own cumulative
    // shards into the same directory; the merge must sum them without
    // losing either side — the old shared-file read-merge-write could
    // drop a concurrent isolate's delta entirely.
    'two isolates merge without losing updates',
    () {
      runCollectorIn(
        isolateOneDriver,
        env: const {'CRAP_PROFILE_SHARD': 'iso-one'},
        dir: dir,
      );
      runCollectorIn(
        isolateTwoDriver,
        env: const {'CRAP_PROFILE_SHARD': 'iso-two'},
        dir: dir,
      );
      final json = mergeShards(dir, 'timings.json');
      expect(json['A.b']['calls'], 42);
      // Exactly two shard files, both still present (replace semantics,
      // no clobbering across isolates).
      expect(shardNames(dir), hasLength(2));
    },
  );

  test('min/max merge across isolates keeps the extremes', () {
    runCollectorIn(
      isolateOneDriver,
      env: const {'CRAP_PROFILE_SHARD': 'iso-one'},
      dir: dir,
    );
    runCollectorIn(
      isolateTwoDriver,
      env: const {'CRAP_PROFILE_SHARD': 'iso-two'},
      dir: dir,
    );
    final json = mergeShards(dir, 'timings.json');
    final stats = json['A.b'];
    // 10 + 32 calls from the two isolates, summed.
    expect(stats['calls'], 42);
    expect(stats['minMicros'], lessThanOrEqualTo(stats['maxMicros']));
  });

  test('many distinct methods stay bounded: one method-count-sized shard', () {
    final json = runCollectorIn(manyMethodsDriver, dir: dir);
    final methodKeys = json.keys.where((k) => !k.startsWith('#')).toList();
    expect(methodKeys, hasLength(300));
    // One flush per outermost exit (3000 top-level exits: 300 methods
    // x 10 calls, no outer frame) + the explicit final flush. Full
    // delivery; writes are cheap (each <= 300 methods of stats).
    expect(json['#flushes']['calls'], 3001);
    final shardFile = dir
        .listSync()
        .whereType<File>()
        .firstWhere((f) => shardNames(dir).contains(p.basename(f.path)));
    // 300 methods x ~120 bytes - bounded by the METHOD count, never by
    // the call count.
    expect(shardFile.lengthSync(), lessThan(256 * 1024));
  });
}
