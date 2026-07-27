import 'package:crap4dart/src/config/config_loader.dart';
import 'package:test/test.dart';

void main() {
  const loader = ConfigLoader();

  group('ConfigLoader value types', () {
    test('wrong value type throws with the key name', () {
      expect(
        () => loader.loadString('crap:\n  threshold: high\n'),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.key,
            'key',
            'crap.threshold',
          ),
        ),
      );
      expect(
        () => loader.loadString('coverage:\n  required: yes\n'),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => loader.loadString('gates:\n  loc:\n    exclude: "not-a-list"\n'),
        throwsA(isA<ConfigException>()),
      );
    });

    test('invalid count_lambdas and exclude throw with the key name', () {
      expect(
        () => loader.loadString('crap:\n  count_lambdas: maybe\n'),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.key,
            'key',
            'crap.count_lambdas',
          ),
        ),
      );
      expect(
        () =>
            loader.loadString('gates:\n  complexity:\n    count_lambdas: 1\n'),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => loader.loadString('exclude: "example/**"\n'),
        throwsA(
          isA<ConfigException>().having((e) => e.key, 'key', 'exclude'),
        ),
      );
    });
  });
}
