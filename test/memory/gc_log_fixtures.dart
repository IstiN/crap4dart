// Raw fixture streams for [MemoryProfiler] attribution tests: a JSON
// reporter stream and matching `--verbose_gc` stderr, hand-built so
// the tests need no real suite run.
//
// Clock model: GC rows count SECONDS SINCE ISOLATE START; the suite
// event's `time` (ms since run start) marks the same zero point. A
// test's window in isolate-clock ms is (testMs − suiteEventMs).
// Suite 0 spawns at reporter t=100ms (heavy test 120–1000ms → window
// 20–900ms); suite 1 at t=1100ms (light test 1200–1300ms → window
// 100–200ms).

const kTwoSuiteJson = '''
{"type":"suite","suite":{"id":0,"path":"test/heavy_test.dart"},"time":100}
{"type":"testStart","test":{"id":1,"name":"heavy allocates a lot","suiteID":0},"time":120}
{"type":"testDone","testID":1,"result":"success","time":1000}
{"type":"suite","suite":{"id":1,"path":"test/light_test.dart"},"time":1100}
{"type":"testStart","test":{"id":2,"name":"light test stays quiet","suiteID":1},"time":1200}
{"type":"testDone","testID":2,"result":"success","time":1300}
{"type":"done","success":true,"time":1400}
''';

// GC rows: reclaimed new-gen volume per row is (before − after).
// Suite 0: a 3.8 MB reclaim at isolate t=0.5 s (inside the window).
// Suite 1: a 1.0 MB reclaim during LOADING (t=0.05, before its window
// starts at 0.1) plus a 1.8 MB reclaim inside the test (t=0.15).
const kTwoSuiteGcLog = '''
test_suite:file:///tmp/dart_test.kernel.x/test.dart_1.dill: hard_threshold=8796093022208MB
[ test_suite:fi,  Scavenge( new space),    1,  0.50,  0.1,  4.2,  0.4,  1.5,  1.5, 0.0, 0.0,  36.5,  36.5,  38.0,  38.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ]
test_suite:file:///tmp/dart_test.kernel.x/test.dart_2.dill: hard_threshold=8796093022208MB
[ test_suite:fi,  Scavenge( new space),    1,  0.05,  0.1,  2.2,  1.2,  1.5,  1.5, 0.0, 0.0,  36.5,  36.5,  38.0,  38.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ]
[ test_suite:fi,  Scavenge( new space),    2,  0.15,  0.1,  2.4,  0.6,  1.5,  1.5, 0.0, 0.0,  36.5,  36.5,  38.0,  38.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ]
''';

// Same suite layout, but suite 0's seq-2 row (2.0 MB) flushes AFTER
// suite 1's spawn announcement — a straggler that must return to
// suite 0 (GC numbers continue per isolate; a fresh isolate restarts
// at 1).
const kStragglerGcLog = '''
test_suite:file:///tmp/dart_test.kernel.x/test.dart_1.dill: hard_threshold=8796093022208MB
[ test_suite:fi,  Scavenge( new space),    1,  0.50,  0.1,  4.2,  0.4,  1.5,  1.5, 0.0, 0.0,  36.5,  36.5,  38.0,  38.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ]
test_suite:file:///tmp/dart_test.kernel.x/test.dart_2.dill: hard_threshold=8796093022208MB
[ test_suite:fi,  Scavenge( new space),    2,  0.85,  0.1,  2.6,  0.6,  1.5,  1.5, 0.0, 0.0,  36.5,  36.5,  38.0,  38.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ]
[ test_suite:fi,  Scavenge( new space),    1,  0.15,  0.1,  1.6,  0.6,  1.5,  1.5, 0.0, 0.0,  36.5,  36.5,  38.0,  38.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ]
''';

// One suite, two NESTED test windows: the outer test runs reporter
// 100–500ms (isolate clock 0.1–0.5 s), the inner 200–300ms (0.2–0.3
// s). A GC at isolate t=0.25 falls in BOTH windows and must land on
// the SHORTER span.
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
[ test_suite:fi,  Scavenge( new space),    1,  0.25,  0.1,  4.2,  0.4,  1.5,  1.5, 0.0, 0.0,  36.5,  36.5,  38.0,  38.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ]
''';
