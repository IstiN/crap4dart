import 'package:crap4dart/src/config/config_loader.dart';
import 'package:test/test.dart';

void main() {
  const loader = ConfigLoader();

  group('ConfigLoader validation', () {
    test('unknown top-level key throws with the key name', () {
      expect(
        () => loader.loadString('bogus: 1\n'),
        throwsA(
          isA<ConfigException>()
              .having((e) => e.key, 'key', 'bogus')
              .having((e) => e.message, 'message', contains('unknown key')),
        ),
      );
    });

    test('unknown gate id throws with the gate name', () {
      expect(
        () => loader.loadString('gates:\n  bogus_gate:\n    enabled: true\n'),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.key,
            'key',
            'gates.bogus_gate',
          ),
        ),
      );
    });

    test('unknown key inside a gate throws with the full key', () {
      expect(
        () => loader.loadString('gates:\n  loc:\n    max_linez: 100\n'),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.key,
            'key',
            'gates.loc.max_linez',
          ),
        ),
      );
    });
  });
}
