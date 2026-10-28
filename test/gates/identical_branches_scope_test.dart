import 'package:test/test.dart';

import 'identical_branches_fixtures.dart';

void main() {
  test('distinct conditions pass', () async {
    final result = await runOn('''
String classify(int x) {
  if (x < 0) {
    return 'neg';
  } else if (x == 0) {
    return 'zero';
  } else if (x < 10) {
    return 'small';
  }
  return 'other';
}
''');
    expect(result.passed, isTrue, reason: result.violations.toString());
    expect(result.summary, contains('no identical-branch findings'));
  });

  test('the same condition in two separate if statements passes', () async {
    final result = await runOn('''
String classify(int x) {
  var label = '';
  if (x == 0) {
    label = 'zero';
  }
  if (x == 0) {
    label = 'zero';
  }
  return label;
}
''');
    expect(result.passed, isTrue, reason: result.violations.toString());
  });

  test('nested ifs are separate chains, not chain links', () async {
    final result = await runOn('''
String classify(int x, int y) {
  if (x == 0) {
    if (y == 0) {
      return 'origin';
    }
    return 'x-zero';
  } else if (y == 0) {
    return 'y-zero';
  }
  return 'other';
}
''');
    expect(result.passed, isTrue, reason: result.violations.toString());
  });

  test('an if nested in an else block is its own chain', () async {
    final result = await runOn('''
String classify(int x) {
  if (x > 0) {
    return 'pos';
  } else {
    if (x == 0) {
      return 'zero';
    } else if (x == 0) {
      return 'zero!';
    }
  }
  return 'neg';
}
''');
    expect(result.passed, isFalse, reason: result.summary);
    expect(result.violations.single.line, 7);
  });
}
