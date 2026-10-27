import 'package:crap4dart/src/config/config.dart';
import 'package:crap4dart/src/config/config_loader.dart';
import 'package:test/test.dart';

void main() {
  test('aliases loads from yaml; the default is true', () {
    final off = const ConfigLoader().loadString('gates:\n'
        '  scattered_constants:\n'
        '    aliases: false\n');
    expect(off.gates.scatteredConstants.flagAliases, isFalse);
    final defaults = Crap4DartConfig.defaults();
    expect(defaults.gates.scatteredConstants.flagAliases, isTrue);
  });

  test('aliases under another gate stays an unknown key (strict)', () {
    expect(
      () => const ConfigLoader().loadString('gates:\n'
          '  loc:\n'
          '    aliases: false\n'),
      throwsA(isA<ConfigException>()),
    );
  });
}
