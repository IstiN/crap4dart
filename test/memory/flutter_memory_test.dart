import 'package:crap4dart/src/memory/flutter_memory.dart';
import 'package:crap4dart/src/memory/gc_log.dart';
import 'package:test/test.dart';

void main() {
  group('parseTesterSpawnLine', () {
    test('parses command and environment', () {
      const line = '[   +1 ms] test 3: Starting flutter_tester process with '
          'command=[/path/to/flutter_tester, --disable-vm-service, '
          '--packages=/proj/.dart_tool/package_config.json, '
          '--flutter-assets-dir=/proj/build/unit_test_assets, '
          '/tmp/flutter_tools.AbC123/listener.dill], '
          'environment={FLUTTER_TEST: true, APP_NAME: my_app, '
          'SERVER_PORT: 56074}';
      final spawn = parseTesterSpawnLine(line);
      expect(spawn, isNotNull);
      expect(spawn!.executable, '/path/to/flutter_tester');
      expect(spawn.arguments.last, '/tmp/flutter_tools.AbC123/listener.dill');
      expect(spawn.environment['APP_NAME'], 'my_app');
      expect(spawn.environment['SERVER_PORT'], '56074');
    });

    test('rejects non-spawn lines', () {
      expect(parseTesterSpawnLine('[  +2 ms] some other trace line'), isNull);
      expect(parseTesterSpawnLine('{"type":"start","time":0}'), isNull);
      expect(parseTesterSpawnLine(''), isNull);
    });

    test('environment values may contain colons', () {
      const line = 'test 0: Starting flutter_tester process with '
          'command=[/ft, /tmp/dill], environment={FONTCONFIG_FILE: /a:b/c}';
      final spawn = parseTesterSpawnLine(line);
      expect(spawn!.environment['FONTCONFIG_FILE'], '/a:b/c');
    });
  });

  group('flattenGroup', () {
    test('flattens nested groups into ordered tests with channels', () {
      final root = <String, Object?>{
        'type': 'group',
        'name': '',
        'entries': [
          {
            'type': 'group',
            'name': 'network',
            'entries': [
              {'type': 'test', 'name': 'connects', 'channel': 1},
              {'type': 'test', 'name': 'retries', 'channel': 3},
            ],
          },
          {'type': 'test', 'name': 'standalone', 'channel': 5},
        ],
      };
      final tests = flattenGroup(root, '');
      expect(tests.map((t) => t.name), [
        'network connects',
        'network retries',
        'standalone',
      ]);
      expect(tests.map((t) => t.channel), [1, 3, 5]);
    });
  });

  group('GcLogParser.tryParseRow', () {
    test('parses a row with its own isolate name', () {
      const row = '[ main         ,    Scavenge(   new space),    1,   0.51,'
          '   0.2,   1.5,   0.3,   2.0,   1.0, 0.0, 0.0,   35.2,   35.2,'
          '   37.1,   37.1,   0.0,   0.0,   2,   1,  -1.2,    0.0, ]';
      final event = GcLogParser.tryParseRow(row);
      expect(event, isNotNull);
      expect(event!.startSeconds, closeTo(0.51, 0.01));
      expect(event.isolate, 'main');
    });

    test('returns null for non-row lines', () {
      expect(GcLogParser.tryParseRow('Memory: 12 MB'), isNull);
      expect(GcLogParser.tryParseRow(''), isNull);
    });
  });
}
