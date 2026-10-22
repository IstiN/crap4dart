// Raw fixture streams for [MemoryProfiler] attribution tests: a JSON
// reporter stream and matching `--verbose_gc` stderr, hand-built so
// the tests need no real suite run.
//
// Clock layout (seconds): suite 1 spawns at 1.0, its test runs
// 1.1–2.0; suite 2 spawns at 2.1, its test runs 2.2–2.3. GC times are
// VM-monotonic; JSON times are ms since run start. The two clocks
// differ by a constant offset (here: GC = json/1000 + 1.0).

const kTwoSuiteJson = '''
{"type":"start","protocolVersion":"1.0","time":0}
{"type":"suite","suite":{"id":0,"path":"test/heavy_test.dart"},"time":100}
{"type":"testStart","test":{"id":1,"name":"heavy allocates a lot","suiteID":0},"time":100}
{"type":"testDone","testID":1,"result":"success","time":1000}
{"type":"suite","suite":{"id":1,"path":"test/light_test.dart"},"time":1100}
{"type":"testStart","test":{"id":2,"name":"light test stays quiet","suiteID":1},"time":1200}
{"type":"testDone","testID":2,"result":"success","time":1300}
{"type":"done","success":true,"time":1400}
''';

// GC rows: reclaimed new-gen volume per row is (before − after).
// Suite 1: a 3.8 MB reclaim inside its test window (t=1.5).
// Suite 2: a 1.0 MB reclaim during LOADING (t=2.05, before its first
// testStart at 2.2) plus a 1.8 MB reclaim inside the test (t=2.25).
const kTwoSuiteGcLog = '''
test_suite:file:///tmp/dart_test.kernel.x/test.dart_1.dill: hard_threshold=8796093022208MB
[ test_suite:fi,  Scavenge( new space),    1,  1.50,  0.1,  4.2,  0.4,  1.5,  1.5, 0.0, 0.0,  36.5,  36.5,  38.0,  38.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ]
test_suite:file:///tmp/dart_test.kernel.x/test.dart_2.dill: hard_threshold=8796093022208MB
[ test_suite:fi,  Scavenge( new space),    1,  2.05,  0.1,  2.2,  1.2,  1.5,  1.5, 0.0, 0.0,  36.5,  36.5,  38.0,  38.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ]
[ test_suite:fi,  Scavenge( new space),    2,  2.25,  0.1,  2.4,  0.6,  1.5,  1.5, 0.0, 0.0,  36.5,  36.5,  38.0,  38.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ]
''';

// One suite, two NESTED test windows: the long outer test runs
// 1.1–1.5 s, the short inner test 1.2–1.3 s. A GC at 1.25 falls in
// BOTH windows and must land on the SHORTER span.
const kNestedSpansJson = '''
{"type":"suite","suite":{"id":0,"path":"test/nested_test.dart"},"time":0}
{"type":"testStart","test":{"id":1,"name":"outer long test","suiteID":0},"time":100}
{"type":"testStart","test":{"id":2,"name":"inner short test","suiteID":0},"time":200}
{"type":"testDone","testID":2,"result":"success","time":300}
{"type":"testDone","testID":1,"result":"success","time":500}
{"type":"done","success":true,"time":600}
''';

const kNestedSpansGcLog = '''
test_suite:file:///tmp/dart_test.kernel.x/test.dart_1.dill: hard_threshold=8796093022208MB
[ test_suite:fi,  Scavenge( new space),    1,  1.25,  0.1,  4.2,  0.4,  1.5,  1.5, 0.0, 0.0,  36.5,  36.5,  38.0,  38.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ]
''';

// Same suite layout, but suite 1's seq-2 row (2.0 MB) flushes AFTER
// suite 2's spawn announcement — a straggler that must return to
// suite 1.
const kStragglerGcLog = '''
test_suite:file:///tmp/dart_test.kernel.x/test.dart_1.dill: hard_threshold=8796093022208MB
[ test_suite:fi,  Scavenge( new space),    1,  1.50,  0.1,  4.2,  0.4,  1.5,  1.5, 0.0, 0.0,  36.5,  36.5,  38.0,  38.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ]
test_suite:file:///tmp/dart_test.kernel.x/test.dart_2.dill: hard_threshold=8796093022208MB
[ test_suite:fi,  Scavenge( new space),    2,  1.95,  0.1,  2.6,  0.6,  1.5,  1.5, 0.0, 0.0,  36.5,  36.5,  38.0,  38.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ]
[ test_suite:fi,  Scavenge( new space),    1,  2.25,  0.1,  1.6,  0.6,  1.5,  1.5, 0.0, 0.0,  36.5,  36.5,  38.0,  38.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ]
''';
