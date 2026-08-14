import 'package:crap4dart/src/config/config_loader.dart';
import 'package:test/test.dart';

void main() {
  const loader = ConfigLoader();

  test('file_naming gate config is merged with defaults', () {
    final config = loader.loadString('''
gates:
  file_naming:
    enabled: false
    allow: [mqtt5, CoAP3]
''');
    expect(config.gates.fileNaming.enabled, isFalse);
    expect(config.gates.fileNaming.allow, ['mqtt5', 'CoAP3']);
    expect(config.gates.fileNaming.exclude, contains('test/**'));
  });

  test('file_naming rejects unknown keys', () {
    expect(
      () => loader.loadString('gates:\n  file_naming:\n    max_len: 5\n'),
      throwsA(isA<ConfigException>()),
    );
  });
}
