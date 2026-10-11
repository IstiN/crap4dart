import 'dart:io';

import 'package:crap4dart/src/gates/mutation_engine.dart';
import 'package:crap4dart/src/gates/mutation_operators.dart';
import 'package:test/test.dart';

MutationSite site(String file, {String mutant = 'X', int offset = 0}) =>
    MutationSite(
      file: file,
      line: 1,
      method: null,
      category: 'arithmetic',
      original: 'a',
      mutant: mutant,
      offset: offset,
      length: 1,
    );

void main() {
  late Directory dir;
  late String file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('crap4dart_mutation_engine_');
    file = '${dir.path}/a.txt';
    File(file).writeAsStringSync('a + b');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('mutates one site at a time and restores the file', () async {
    final seen = <String>[];
    final engine = MutationEngine(runner: (root, timeout, args) async {
      seen.add(File(file).readAsStringSync());
      return MutantOutcome.killed;
    });
    final result = await engine.run(
      projectRoot: dir.path,
      sites: [
        site(file, mutant: 'X', offset: 0),
        site(file, mutant: 'Y', offset: 4),
      ],
      timeout: const Duration(seconds: 5),
    );
    expect(seen, ['X + b', 'a + Y']);
    expect(File(file).readAsStringSync(), 'a + b');
    expect(result.killed, 2);
    expect(result.score, 1.0);
  });

  test('restores the file when the runner throws', () async {
    final engine = MutationEngine(
      runner: (root, timeout, args) => throw MutationTestUnavailableException(
        'dart not found on PATH: no such file',
      ),
    );
    expect(
      () => engine.run(
        projectRoot: dir.path,
        sites: [site(file)],
        timeout: const Duration(seconds: 5),
      ),
      throwsA(isA<MutationTestUnavailableException>()),
    );
    expect(File(file).readAsStringSync(), 'a + b');
  });
}
