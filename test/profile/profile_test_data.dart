import 'package:crap4dart/src/analysis/method_extractor.dart';

/// Shared [MethodInfo] fixtures for profile attribution tests.
const testMethods = <MethodInfo>[
  MethodInfo(
    className: 'Foo',
    methodName: 'bar',
    startLine: 10,
    endLine: 20,
    filePath: 'lib/foo.dart',
  ),
  MethodInfo(
    className: 'Foo',
    methodName: 'baz',
    startLine: 25,
    endLine: 40,
    filePath: 'lib/foo.dart',
  ),
  MethodInfo(
    className: '(top-level)',
    methodName: 'helper',
    startLine: 5,
    endLine: 8,
    filePath: 'lib/utils.dart',
  ),
];
