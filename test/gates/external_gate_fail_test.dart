import 'dart:io';

import 'package:crap4dart/src/gates/external_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  test('reports a failing tool run without a report', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    final failing = File('${project.path}/failing_tool.sh')
      ..writeAsStringSync('#!/bin/sh\nexit 3\n');
    Process.runSync('chmod', ['+x', failing.path]);
    final result = await ExternalGate().run(
      makeContext(
        project,
        const [],
        configYaml: '''
gates:
  external:
    rules:
      - id: broken
        executable: '${failing.path}'
        arguments: ['{report}']
''',
      ),
    );
    expect(result.passed, isFalse);
    expect(
      result.violations.single.message,
      allOf(contains('exited with 3'), contains('no report')),
    );
  });
}
