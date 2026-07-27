import 'dart:io';

import 'package:crap4dart/src/config/config_loader.dart';
import 'package:crap4dart/src/config/config_template.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  const loader = ConfigLoader();

  group('config template', () {
    test('loads the repo self-config without errors', () {
      final config = loader.load(p.normalize(Directory.current.path));
      expect(config.crap.threshold, 8.0);
      expect(config.sources, ['lib', 'bin', 'test']);
      expect(config.gates.golden.enabled, isFalse);
      expect(config.gates.testCoverage.minPercent, 70.0);
      expect(config.gates.complexity.maxComplexity, 12);
    });

    test('generated template round-trips through the loader', () {
      final config = loader.loadString(defaultConfigTemplate);
      expect(config.crap.enabled, isTrue);
      expect(config.crap.threshold, 8.0);
      expect(config.sources, ['lib', 'bin']);
      expect(config.coverage.lcovPath, 'coverage/lcov.info');
      expect(config.gates.loc.maxLines, 800);
      expect(config.gates.loc.exclude, [
        '**.g.dart',
        '**.freezed.dart',
        '**.mocks.dart',
      ]);
      expect(config.gates.testCoverage.minPercent, 80.0);
      expect(config.gates.testCoverage.dirs, ['lib']);
      expect(config.gates.golden.enabled, isTrue);
      expect(config.gates.golden.widgetDirs, ['lib']);
      expect(config.gates.golden.testDirs, ['test']);
      expect(config.gates.golden.excludeWidgets, isEmpty);
      expect(config.gates.hardcodedStrings.ignoreMarker, 'l10n:ignore');
      expect(config.gates.hardcodedStrings.checkParams, [
        'labelText',
        'hintText',
        'helperText',
        'tooltip',
      ]);
      expect(config.gates.complexity.maxComplexity, 10);
      expect(config.gates.methodSize.maxLines, 60);
      expect(config.gates.methodSize.maxParams, 6);
      expect(config.gates.publicDocs.exclude, ['test/**']);
    });
  });
}
