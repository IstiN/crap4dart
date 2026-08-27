import 'package:crap4dart/src/analysis/method_extractor.dart';
import 'package:crap4dart/src/profile/profile_reporter.dart';
import 'package:crap4dart/src/profile/profile_runner.dart';

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

/// 25 billion calls, 5e7 ms of total work — a realistic hot inner loop
/// (e.g. markdown parsing) that used to overflow the TOTAL column with a
/// plain `50000000.00`.
const hugeHotLoopTiming = MethodTiming(
  className: 'Foo',
  methodName: 'bar',
  calls: 25000000000,
  totalMicros: 50000000000,
  minMicros: 1,
  maxMicros: 90000,
);

/// 2.5s of total work — exercises the seconds tier of adaptive units.
const secondsTierTiming = MethodTiming(
  className: 'Foo',
  methodName: 'baz',
  calls: 100,
  totalMicros: 2500000,
  minMicros: 1000,
  maxMicros: 50000,
);

/// Extreme-magnitude timings paired with [testMethods] in order.
const hugeTimingFixtures = [hugeHotLoopTiming, secondsTierTiming];

/// Builds a timing for reporter tests, keyed to the matching
/// [testMethods] entry by [name].
MethodTiming timing(
  String name, {
  int calls = 1,
  int totalMicros = 0,
  int totalSelfMicros = 0,
  int minMicros = 0,
  int maxMicros = 0,
}) =>
    MethodTiming(
      className: 'Foo',
      methodName: name,
      calls: calls,
      totalMicros: totalMicros,
      totalSelfMicros: totalSelfMicros,
      minMicros: minMicros,
      maxMicros: maxMicros,
    );

/// Builds a report rendering [timings] against the first [timings.length]
/// entries of [testMethods].
ProfileReport reportFor(List<MethodTiming> timings) => ProfileReport(
      profiles: [
        for (var i = 0; i < timings.length; i++)
          MethodProfile(method: testMethods[i], timing: timings[i]),
      ],
    );
