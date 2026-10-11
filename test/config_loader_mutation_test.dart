import 'package:crap4dart/src/config/config.dart';
import 'package:crap4dart/src/config/config_loader.dart';
import 'package:test/test.dart';

const loader = ConfigLoader();

MutationGateConfig load(String yaml) => loader.loadString(yaml).gates.mutation;

void main() {
  defaultsAndParsingTests();
  strictValidationTests();
  knownGateTests();
}

void defaultsAndParsingTests() {
  test('is disabled by default with documented defaults', () {
    final config = load('');
    expect(config.enabled, isFalse);
    expect(config.severity, GateSeverity.error);
    expect(config.ignorable, isFalse);
    expect(config.minScore, 0.8);
    expect(config.maxSurvivors, 0);
    expect(config.execution.timeoutSeconds, 60);
    expect(config.execution.maxMutants, 500);
    expect(config.operators, mutationOperatorCategories);
    expect(config.execution.cache, isTrue);
    expect(config.execution.testArgs, ['test']);
    expect(config.exclude, contains('test/**'));
  });

  test('parses every documented key', () {
    final config = load(
      'gates:\n'
      '  mutation:\n'
      '    enabled: true\n'
      '    severity: warning\n'
      '    ignorable: true\n'
      '    min_score: 0.5\n'
      '    max_survivors: 3\n'
      '    timeout_seconds: 30\n'
      '    max_mutants: 25\n'
      '    operators: [arithmetic, boundary]\n'
      '    cache: false\n'
      "    test_args: ['test', 'test/copilot']\n"
      '    exclude: [lib/gen/**]\n',
    );
    expect(config.enabled, isTrue);
    expect(config.severity, GateSeverity.warning);
    expect(config.ignorable, isTrue);
    expect(config.minScore, 0.5);
    expect(config.maxSurvivors, 3);
    expect(config.execution.timeoutSeconds, 30);
    expect(config.execution.maxMutants, 25);
    expect(config.operators, ['arithmetic', 'boundary']);
    expect(config.execution.cache, isFalse);
    expect(config.execution.testArgs, ['test', 'test/copilot']);
    expect(config.exclude, ['lib/gen/**']);
  });

  test('rejects test_args that is not a list of non-empty strings', () {
    expect(
      () => load('gates:\n  mutation:\n    test_args: test\n'),
      throwsA(isA<ConfigException>()),
    );
    expect(
      () => load('gates:\n  mutation:\n    test_args: []\n'),
      throwsA(isA<ConfigException>()),
    );
    expect(
      () => load('gates:\n  mutation:\n    test_args: [\'\', x]\n'),
      throwsA(isA<ConfigException>()),
    );
    expect(
      () => load('gates:\n  mutation:\n    test_args: [test, 3]\n'),
      throwsA(isA<ConfigException>()),
    );
  });

  test('rejects non-boolean cache strictly', () {
    expect(
      () => load('gates:\n  mutation:\n    cache: yes\n'),
      throwsA(isA<ConfigException>()),
    );
  });
}

void strictValidationTests() {
  test('rejects unknown keys strictly', () {
    expect(
      () => load('gates:\n  mutation:\n    minscore: 0.5\n'),
      throwsA(isA<ConfigException>()),
    );
  });

  test('rejects unknown operator categories strictly', () {
    expect(
      () => load('gates:\n  mutation:\n    operators: [arithmnetic]\n'),
      throwsA(isA<ConfigException>()),
    );
  });

  test('rejects wrongly typed values', () {
    expect(
      () => load('gates:\n  mutation:\n    min_score: high\n'),
      throwsA(isA<ConfigException>()),
    );
    expect(
      () => load('gates:\n  mutation:\n    max_mutants: 2.5\n'),
      throwsA(isA<ConfigException>()),
    );
  });
}

void knownGateTests() {
  test('mutation is a known gate id for --only/--skip filtering', () {
    expect(ConfigLoader.knownGates, contains('mutation'));
  });
}
