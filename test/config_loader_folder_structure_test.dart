import 'package:crap4dart/src/config/config_loader.dart';
import 'package:test/test.dart';

ConfigLoader _loader() => const ConfigLoader();

void main() {
  test('max_loose_files is the knob', () {
    final gates = _loader()
        .loadString('gates:\n'
            '  folder_structure:\n'
            '    dirs: [lib, test]\n'
            '    max_loose_files: 7\n')
        .gates;
    final gate = gates.folderStructure;
    expect(gate.maxLooseFiles, 7);
    expect(gate.dirs, ['lib', 'test']);
  });

  test('max_files is an unknown key (strict validation)', () {
    expect(
      () => _loader().loadString('gates:\n'
          '  folder_structure:\n'
          '    max_files: 3\n'),
      throwsA(isA<ConfigException>()),
    );
  });

  test('the gate works without any folder_structure section', () {
    final gates = _loader()
        .loadString('gates:\n'
            '  loc:\n'
            '    max_lines: 100\n')
        .gates;
    expect(gates.folderStructure.enabled, isTrue);
    expect(gates.folderStructure.maxLooseFiles, 0);
  });
}
