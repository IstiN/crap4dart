import 'dart:convert';
import 'dart:io';

import 'package:crap4dart/src/profile/collector_template.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Executes the REAL collector template as a standalone script and returns
/// the merged timing JSON it produced.
///
/// The collector runs inside instrumented projects in production, so the
/// only faithful way to regression-test its flush math is to materialize
/// the template and drive it with the actual Dart VM (a temp fixture, not
/// this project's test suite).
///
/// Since the shard redesign each isolate writes its own cumulative shard
/// file (`timings.json.<shardId>.json`); this helper merges them the same
/// way [profile_runner] does: calls/totals summed, min minimized, max
/// maximized.
Map<String, dynamic> runCollector(String driverBody) {
  final dir = Directory.systemTemp.createTempSync('crap4dart_collector_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final script = File(p.join(dir.path, 'collector_driver.dart'))
    ..writeAsStringSync('$collectorSource\n\nvoid main() {\n$driverBody}\n');
  final output = p.join(dir.path, 'timings.json');
  final result = Process.runSync(
    Platform.resolvedExecutable,
    [script.path],
    environment: {'CRAP_PROFILE_OUTPUT': output},
  );
  expect(
    result.exitCode,
    0,
    reason: 'collector driver failed: ${result.stderr}',
  );
  return mergeShards(dir, 'timings.json');
}

/// Merges every shard of [baseName] in [dir] the way the profile runner
/// merges collector shards.
Map<String, dynamic> mergeShards(Directory dir, String baseName) {
  final merged = <String, dynamic>{};
  final shardPaths = dir
      .listSync()
      .whereType<File>()
      .map((f) => p.basename(f.path))
      .where(
        (name) =>
            name.startsWith('$baseName.') &&
            name.endsWith('.json') &&
            !name.contains('.tmp.'),
      )
      .toList()
    ..sort();
  expect(shardPaths, isNotEmpty, reason: 'collector wrote no shard files');
  for (final name in shardPaths) {
    final shard = jsonDecode(File(p.join(dir.path, name)).readAsStringSync())
        as Map<String, dynamic>;
    for (final entry in shard.entries) {
      final key = entry.key;
      final stats = entry.value;
      final existing = merged[key];
      if (existing == null) {
        merged[key] = Map<String, dynamic>.from(stats);
        continue;
      }
      int stat(String name2) => existing[name2] as int? ?? 0;
      existing['calls'] = stat('calls') + (stats['calls'] as int? ?? 0);
      existing['totalMicros'] =
          stat('totalMicros') + (stats['totalMicros'] as int? ?? 0);
      existing['totalSelfMicros'] =
          stat('totalSelfMicros') + (stats['totalSelfMicros'] as int? ?? 0);
      existing['minMicros'] = [
        stat('minMicros'),
        stats['minMicros'] as int? ?? 0,
      ].reduce((a, b) => a < b ? a : b);
      existing['maxMicros'] = [
        stat('maxMicros'),
        stats['maxMicros'] as int? ?? 0,
      ].reduce((a, b) => a > b ? a : b);
    }
  }
  return merged;
}

void main() {
  group('collector template', () {
    test(
      // Regression: the flush used to merge the CUMULATIVE in-memory
      // counters into the output file on every flush (every 5 calls),
      // inflating calls and total time quadratically — a hot loop with
      // millions of real calls reported tens of billions of calls (48.5G
      // seen on flutter_agent) and impossible TOTALs like 3538h in a
      // 10-second run. Deltas must be merged instead.
      'repeated flushes keep counters exact (no quadratic inflation)',
      () {
        final json = runCollector('''
  final c = CrapCollector.instance;
  for (var i = 0; i < 43; i++) {
    c.enter('A.b');
    c.exit('A.b');
  }
  c.flush();
''');
        // Old bug: 8 automatic flushes re-added the cumulative counters,
        // producing calls = 5+10+...+40 = 180 instead of 43.
        expect(json['A.b']['calls'], 43);
        final totalMicros = json['A.b']['totalMicros'] as int;
        expect(totalMicros, lessThan(10000));
        expect(json['A.b']['totalSelfMicros'], totalMicros);
      },
    );

    test('self time excludes nested instrumented call time', () {
      final json = runCollector('''
  final c = CrapCollector.instance;
  c.enter('A.outer');
  c.enter('B.inner');
  c.exit('B.inner');
  c.exit('A.outer');
  c.flush();
''');
      final outer = json['A.outer'] as Map<String, dynamic>;
      final inner = json['B.inner'] as Map<String, dynamic>;
      expect(outer['calls'], 1);
      expect(inner['calls'], 1);
      final outerTotal = outer['totalMicros'] as int;
      final outerSelf = outer['totalSelfMicros'] as int;
      final innerTotal = inner['totalMicros'] as int;
      final innerSelf = inner['totalSelfMicros'] as int;
      // Nested call is fully contained in the parent's inclusive time.
      expect(outerTotal, greaterThanOrEqualTo(innerTotal));
      // Parent's self time excludes the nested call; child keeps its own.
      expect(outerSelf, lessThanOrEqualTo(outerTotal - innerTotal));
      expect(innerSelf, lessThanOrEqualTo(innerTotal));
      expect(outerSelf, greaterThanOrEqualTo(0));
      expect(innerSelf, greaterThanOrEqualTo(0));
    });
  });
}
