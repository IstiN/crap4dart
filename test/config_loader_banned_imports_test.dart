import 'package:crap4dart/src/config/config_loader.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigLoader banned_imports rules', () {
    test('parses a rule with an optional message', () {
      final config = const ConfigLoader().loadString('''
gates:
  banned_imports:
    rules:
      - from: 'lib/ui/**'
        forbid:
          - 'dart:io'
        message: UI must not touch IO
''');
      final rules = config.gates.bannedImports.rules;
      expect(rules, hasLength(1));
      expect(rules.single.from, 'lib/ui/**');
      expect(rules.single.forbid, ['dart:io']);
      expect(rules.single.message, 'UI must not touch IO');
    });

    _invalidRulesTests();
  });
}

/// Error paths of `gates.banned_imports.rules`.
void _invalidRulesTests() {
  const loader = ConfigLoader();

  test('rejects rules that are not a list', () {
    expect(
      () => loader.loadString(_rules('rules: nope\n')),
      _throwsAt('gates.banned_imports.rules'),
    );
  });

  test('rejects a rule that is not a map', () {
    expect(
      () => loader.loadString(_rules('rules:\n  - just-a-string\n')),
      _throwsAt('gates.banned_imports.rules'),
    );
  });

  test('rejects an empty from glob', () {
    expect(
      () => loader.loadString(_rules('''
rules:
  - from: ''
    forbid: ['dart:io']
''')),
      _throwsAt('gates.banned_imports.rules.from'),
    );
  });

  test('rejects an empty forbid list', () {
    expect(
      () => loader.loadString(_rules('''
rules:
  - from: 'lib/**'
    forbid: []
''')),
      _throwsAt('gates.banned_imports.rules.forbid'),
    );
  });

  test('rejects a non-string message', () {
    expect(
      () => loader.loadString(_rules('''
rules:
  - from: 'lib/**'
    forbid: ['dart:io']
    message: 42
''')),
      _throwsAt('gates.banned_imports.rules.message'),
    );
  });

  test('rejects unknown keys in a rule', () {
    expect(
      () => loader.loadString(_rules('''
rules:
  - from: 'lib/**'
    forbid: ['dart:io']
    unknown: true
''')),
      _throwsAt('gates.banned_imports.rules.unknown'),
    );
  });
}

/// Wraps [inner] under `gates.banned_imports`, indenting it one level.
String _rules(String inner) => 'gates:\n  banned_imports:\n'
    '${inner.split('\n').map((l) => '    $l').join('\n')}';

/// Expects a [ConfigException] whose key starts with [key].
Matcher _throwsAt(String key) => throwsA(
      isA<ConfigException>().having(
        (e) => e.key,
        'key',
        startsWith(key),
      ),
    );
