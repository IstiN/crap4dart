import 'package:crap4dart/src/config/config_loader.dart';
import 'package:test/test.dart';

void main() {
  test('a map with a non-integer cap is a config error', () {
    expect(
      () => const ConfigLoader().loadString('gates:\n'
          '  folder_structure:\n'
          '    dirs:\n'
          '      lib/src: many\n'),
      throwsA(isA<ConfigException>()),
    );
  });

  test('the map form rejects max_loose_files', () {
    expect(
      () => const ConfigLoader().loadString('gates:\n'
          '  folder_structure:\n'
          '    dirs:\n'
          '      lib/src: 3\n'
          '    max_loose_files: 5\n'),
      throwsA(isA<ConfigException>()),
    );
  });

  test('the map form loads per-pattern caps', () {
    final gates = const ConfigLoader()
        .loadString('gates:\n'
            '  folder_structure:\n'
            '    dirs:\n'
            '      lib/src: 3\n'
            "      'lib/src/**': 30\n")
        .gates;
    final gate = gates.folderStructure;
    expect(gate.dirs, ['lib/src', 'lib/src/**']);
    expect(gate.dirCaps, {'lib/src': 3, 'lib/src/**': 30});
    expect(gate.maxLooseFiles, 0);
  });
}
