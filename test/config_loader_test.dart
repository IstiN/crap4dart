import 'dart:io';

import 'package:crap4dart/src/config/config_loader.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  const loader = ConfigLoader();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('crap4dart_config_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('ConfigLoader basics', () {
    test('returns defaults when no config file exists', () {
      final config = loader.load(tempDir.path);
      expect(config.crap.enabled, isTrue);
      expect(config.crap.threshold, 8.0);
      expect(config.coverage.lcovPath, 'coverage/lcov.info');
      expect(config.coverage.required, isTrue);
      expect(config.gates.loc.maxLines, 800);
      expect(config.gates.testCoverage.minPercent, 80.0);
      expect(config.gates.complexity.maxComplexity, 10);
      expect(config.gates.methodSize.maxParams, 6);
      expect(
        config.gates.accessibility.requireLabelFor,
        ['IconButton', 'Image', 'GestureDetector', 'InkWell'],
      );
    });

    test('merges a partial config with defaults', () {
      final config = loader.loadString('''
crap:
  threshold: 12.5
gates:
  complexity:
    max_complexity: 6
  method_size:
    enabled: false
''');
      expect(config.crap.threshold, 12.5);
      expect(config.crap.enabled, isTrue);
      expect(config.gates.complexity.maxComplexity, 6);
      expect(config.gates.methodSize.enabled, isFalse);
      expect(config.gates.methodSize.maxLines, 60);
      expect(config.gates.loc.maxLines, 800);
    });

    test('empty document yields defaults', () {
      expect(loader.loadString('').crap.threshold, 8.0);
    });

    test('explicit config path must exist', () {
      expect(
        () => loader.load(
          tempDir.path,
          configPath: p.join(tempDir.path, 'missing.yaml'),
        ),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
