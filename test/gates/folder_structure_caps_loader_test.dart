import 'package:crap4dart/src/config/config_loader.dart';
import 'package:test/test.dart';

void main() {
  test('config loads per-pattern caps', () {
    final gates = const ConfigLoader()
        .loadString('gates:\n'
            '  folder_structure:\n'
            '    config:\n'
            '      lib/src: 3\n'
            "      'lib/src/**': 30\n")
        .gates;
    final gate = gates.folderStructure;
    expect(gate.caps, {'lib/src': 3, 'lib/src/**': 30});
    expect(gate.dirs, ['lib']);
    expect(gate.maxLooseFiles, 0);
  });

  test('a config with a non-integer cap is a config error', () {
    expect(
      () => const ConfigLoader().loadString('gates:\n'
          '  folder_structure:\n'
          '    config:\n'
          '      lib/src: many\n'),
      throwsA(isA<ConfigException>()),
    );
  });

  test('max_files stays an unknown key (strict validation)', () {
    expect(
      () => const ConfigLoader().loadString('gates:\n'
          '  folder_structure:\n'
          '    max_files: 3\n'),
      throwsA(isA<ConfigException>()),
    );
  });
}
