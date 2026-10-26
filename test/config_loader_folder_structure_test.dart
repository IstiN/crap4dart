import 'package:crap4dart/src/config/config_loader.dart';
import 'package:test/test.dart';

ConfigLoader _loader() => const ConfigLoader();

void main() {
  test('max_files is the primary knob', () {
    final gates = _loader()
        .loadString('gates:\n'
            '  folder_structure:\n'
            '    dirs: [lib, test]\n'
            '    max_files: 7\n')
        .gates;
    final gate = gates.folderStructure;
    expect(gate.maxFiles, 7);
    expect(gate.dirs, ['lib', 'test']);
  });

  test('max_loose_files still loads as the deprecated alias', () {
    final gates = _loader()
        .loadString('gates:\n'
            '  folder_structure:\n'
            '    max_loose_files: 3\n')
        .gates;
    expect(gates.folderStructure.maxFiles, 3);
  });

  test('setting both keys is a config error', () {
    expect(
      () => _loader().loadString('gates:\n'
          '  folder_structure:\n'
          '    max_files: 3\n'
          '    max_loose_files: 5\n'),
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
    expect(gates.folderStructure.maxFiles, 0);
  });
}
