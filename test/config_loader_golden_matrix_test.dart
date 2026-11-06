import 'package:crap4dart/src/config/config_loader.dart';
import 'package:crap4dart/src/config/config.dart';
import 'package:test/test.dart';

void main() {
  const loader = ConfigLoader();

  group('golden.require_viewport_matrix', () {
    test('parses true', () {
      final config = loader.loadString('''
gates:
  golden:
    require_viewport_matrix: true
''');
      expect(config.gates.golden.requireViewportMatrix, isTrue);
    });

    test('defaults to false', () {
      final config = loader.loadString('gates: {}');
      expect(config.gates.golden.requireViewportMatrix, isFalse);
    });

    test('rejects unknown keys', () {
      expect(
        () => loader.loadString('''
gates:
  golden:
    viewport_matrix: true
'''),
        throwsA(isA<ConfigException>()),
      );
    });
  });

  group('broken_goldens.blank_ratio', () {
    test('parses a custom ratio', () {
      final config = loader.loadString('''
gates:
  broken_goldens:
    blank_ratio: 0.7
''');
      expect(config.gates.brokenGoldens.blankRatio, 0.7);
    });

    test('defaults to 0.92', () {
      const config = BrokenGoldensGateConfig();
      expect(config.blankRatio, 0.92);
    });

    test('rejects ratios outside 0-1', () {
      expect(
        () => loader.loadString('''
gates:
  broken_goldens:
    blank_ratio: 1.5
'''),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
