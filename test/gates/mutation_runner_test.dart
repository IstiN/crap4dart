import 'dart:async';
import 'dart:io';

import 'package:crap4dart/src/gates/mutation_engine.dart';
import 'package:test/test.dart';

/// A [Process] double with a programmable exit code; [hang] models a
/// test suite that never finishes.
class FakeProcess implements Process {
  FakeProcess({this.exitCodeValue = 0, this.hang = false});

  final int exitCodeValue;
  final bool hang;
  var killed = false;

  @override
  int get pid => 0;

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  IOSink get stdin => throw UnimplementedError('not used by the runner');

  @override
  Future<int> get exitCode =>
      hang ? Completer<int>().future : Future.value(exitCodeValue);

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    return true;
  }
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('crap4dart_runner_'));

  tearDown(() => dir.deleteSync(recursive: true));

  test('exit code zero survives, non-zero kills', () async {
    final survived = await runMutantTests(
      dir.path,
      const Duration(seconds: 5),
      spawn: (_, __, {workingDirectory}) =>
          Future.value(FakeProcess(exitCodeValue: 0)),
    );
    final killed = await runMutantTests(
      dir.path,
      const Duration(seconds: 5),
      spawn: (_, __, {workingDirectory}) =>
          Future.value(FakeProcess(exitCodeValue: 1)),
    );
    expect(survived, MutantOutcome.survived);
    expect(killed, MutantOutcome.killed);
  });

  test('spawns dart test in the project root', () async {
    ({
      String executable,
      List<String> arguments,
      String? workingDirectory
    })? seen;
    await runMutantTests(
      dir.path,
      const Duration(seconds: 5),
      spawn: (executable, arguments, {workingDirectory}) {
        seen = (
          executable: executable,
          arguments: arguments,
          workingDirectory: workingDirectory
        );
        return Future.value(FakeProcess());
      },
    );
    expect(seen!.executable, 'dart');
    expect(seen!.arguments, ['test']);
    expect(seen!.workingDirectory, dir.path);
  });

  test('a hanging suite times out and is killed', () async {
    final process = FakeProcess(hang: true);
    final outcome = await runMutantTests(
      dir.path,
      const Duration(milliseconds: 10),
      spawn: (_, __, {workingDirectory}) => Future.value(process),
    );
    expect(outcome, MutantOutcome.timeout);
    expect(process.killed, isTrue);
  });

  test('a missing executable raises MutationTestUnavailableException',
      () async {
    expect(
      () => runMutantTests(
        dir.path,
        const Duration(seconds: 5),
        spawn: (_, __, {workingDirectory}) =>
            throw ProcessException('dart', const ['test']),
      ),
      throwsA(isA<MutationTestUnavailableException>()),
    );
  });
}
