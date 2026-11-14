import 'dart:io';

import 'package:crap4dart/src/profile/collector_template.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'collector_flush_test.dart' show mergeShards;

/// Runs the collector template as a standalone script with [env] extra
/// environment (the collector's tunables and shard id are env-driven),
/// in [dir] (created when null) writing shards for [baseName].
Map<String, dynamic> runCollectorIn(
  String driverBody, {
  Map<String, String> env = const {},
  Directory? dir,
  String baseName = 'timings.json',
}) {
  final ownsDir = dir == null;
  dir ??= Directory.systemTemp.createTempSync('crap4dart_collector2_');
  if (ownsDir) addTearDown(() => dir!.deleteSync(recursive: true));
  final script = File(p.join(dir.path, 'collector_driver.dart'))
    ..writeAsStringSync('$collectorSource\n\nvoid main() {\n$driverBody}\n');
  final output = p.join(dir.path, baseName);
  final result = Process.runSync(
    Platform.resolvedExecutable,
    [script.path],
    environment: {...env, 'CRAP_PROFILE_OUTPUT': output},
  );
  expect(
    result.exitCode,
    0,
    reason: 'collector driver failed: ${result.stderr}',
  );
  return mergeShards(dir, baseName);
}
