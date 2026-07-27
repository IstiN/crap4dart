import 'package:crap4dart/src/config/config_loader.dart';
import 'package:test/test.dart';

void main() {
  const loader = ConfigLoader();

  group('ConfigLoader sources', () {
    test('sources defaults to lib and bin and merges from config', () {
      expect(loader.loadString('').sources, ['lib', 'bin']);
      final config = loader.loadString('sources: [lib, tool, test]\n');
      expect(config.sources, ['lib', 'tool', 'test']);
    });

    test('invalid sources throws with the key name', () {
      expect(
        () => loader.loadString('sources: lib\n'),
        throwsA(
          isA<ConfigException>().having((e) => e.key, 'key', 'sources'),
        ),
      );
      expect(
        () => loader.loadString('sources: [lib, ""]\n'),
        throwsA(
          isA<ConfigException>().having((e) => e.key, 'key', 'sources'),
        ),
      );
      expect(
        () => loader.loadString('sources: [lib, 42]\n'),
        throwsA(
          isA<ConfigException>().having((e) => e.key, 'key', 'sources'),
        ),
      );
    });

    test('test_coverage dirs defaults to lib and merges from config', () {
      expect(
        loader.loadString('').gates.testCoverage.dirs,
        ['lib'],
      );
      final config = loader.loadString(
        'gates:\n  test_coverage:\n    dirs: [lib, test]\n',
      );
      expect(config.gates.testCoverage.dirs, ['lib', 'test']);
    });

    test('count_lambdas parses independently for crap and the gate', () {
      expect(loader.loadString('').crap.countLambdas, isTrue);
      expect(loader.loadString('').gates.complexity.countLambdas, isTrue);
      final config = loader.loadString(
        'crap:\n  count_lambdas: false\n'
        'gates:\n  complexity:\n    count_lambdas: false\n',
      );
      expect(config.crap.countLambdas, isFalse);
      expect(config.gates.complexity.countLambdas, isFalse);
    });

    test('exclude defaults to empty and merges from config', () {
      expect(loader.loadString('').exclude, isEmpty);
      final config =
          loader.loadString("exclude: ['example/**', '**.g.dart']\n");
      expect(config.exclude, ['example/**', '**.g.dart']);
    });
  });
}
