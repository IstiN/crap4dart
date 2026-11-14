import 'dart:io';

import 'package:crap4dart/src/config/config.dart';
import 'package:crap4dart/src/gates/gate_context.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

GateContext _context(Directory project, {int budget = 1 << 20}) => GateContext(
      projectRoot: project.path,
      config: Crap4DartConfig.defaults(),
      files: const [],
      cacheBudgetBytes: budget,
    );

void main() {
  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('parsed returns the cached unit on repeat access', () {
    writeFile(project, 'lib/a.dart', 'int a() => 1;\n');
    final context = _context(project);
    final first = context.parsed('${project.path}/lib/a.dart');
    final second = context.parsed('${project.path}/lib/a.dart');
    expect(identical(first, second), isTrue);
  });

  test('parsed evicts least recently used entries over the budget', () {
    // Two files of ~200 bytes each with a 300-byte budget: the second
    // parse evicts the first; a fresh access re-parses (new unit).
    final bigA = 'int a() => 1; // ${'a' * 180}\n';
    final bigB = 'int b() => 2; // ${'b' * 180}\n';
    writeFile(project, 'lib/a.dart', bigA);
    writeFile(project, 'lib/b.dart', bigB);
    final pathA = '${project.path}/lib/a.dart';
    final pathB = '${project.path}/lib/b.dart';
    final context = _context(project, budget: 300);
    final unitA = context.parsed(pathA);
    final unitB = context.parsed(pathB);
    expect(identical(context.parsed(pathB), unitB), isTrue,
        reason: 'most recently used survives');
    expect(identical(context.parsed(pathA), unitA), isFalse,
        reason: 'evicted entry is re-parsed');
  });

  test('parsed refreshes recency on access', () {
    final bigA = 'int a() => 1; // ${'a' * 180}\n';
    final bigB = 'int b() => 2; // ${'b' * 180}\n';
    final bigC = 'int c() => 3; // ${'c' * 180}\n';
    writeFile(project, 'lib/a.dart', bigA);
    writeFile(project, 'lib/b.dart', bigB);
    writeFile(project, 'lib/c.dart', bigC);
    final pathA = '${project.path}/lib/a.dart';
    final pathB = '${project.path}/lib/b.dart';
    final pathC = '${project.path}/lib/c.dart';
    final context = _context(project, budget: 620);
    final unitA = context.parsed(pathA);
    context.parsed(pathB);
    context.parsed(pathA); // refresh A: B is now the LRU candidate
    context.parsed(pathC); // evicts B, not A
    expect(identical(context.parsed(pathA), unitA), isTrue);
  });

  test('line cache evicts and re-reads over the budget', () {
    writeFile(project, 'lib/a.dart', 'one\ntwo\nthree\n');
    writeFile(project, 'lib/b.dart', '${'x' * 400}\n');
    final pathA = '${project.path}/lib/a.dart';
    final context = _context(project, budget: 200);
    expect(context.line(pathA, 2), 'two');
    context.line('${project.path}/lib/b.dart', 1); // evicts a.dart
    expect(context.line(pathA, 3), 'three',
        reason: 're-read after eviction still reports correct lines');
  });
}
