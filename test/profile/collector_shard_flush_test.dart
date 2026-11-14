import 'dart:io';

import 'package:test/test.dart';

import 'collector_driver_harness.dart';

/// Driver bodies, kept top-level so `main` stays under the repo's
/// method-size gate.
const hotNestedLoopDriver = '''
  final c = CrapCollector.instance;
  c.enter('Hot.frame');
  for (var i = 0; i < 50000; i++) {
    c.enter('Hot.skinVertex');
    for (var j = 0; j < 8; j++) {
      c.enter('Hot.transform');
      c.exit('Hot.transform');
    }
    c.exit('Hot.skinVertex');
  }
  c.exit('Hot.frame');
  c.flush();
''';

const shortRunDriver = '''
  final c = CrapCollector.instance;
  for (var i = 0; i < 43; i++) {
    c.enter('A.b');
    c.exit('A.b');
  }
  // No flush() call — the outermost exits must have delivered.
''';

const stuckStackDriver = '''
  final c = CrapCollector.instance;
  c.enter('Leaky.neverExits'); // stack stuck non-empty from here on
  for (var i = 0; i < 150; i++) {
    c.enter('A.b');
    c.exit('A.b');
  }
  // No flush() call; backstop interval is 100 calls via env below.
''';

const throttledOutermostDriver = '''
  final c = CrapCollector.instance;
  for (var i = 0; i < 2000; i++) {
    c.enter('A.b');
    c.exit('A.b');
  }
  c.flush();
''';

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('crap4dart_shards_');
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  test(
    // Regression for the hot-loop observer effect: the old collector
    // flushed (read + decode + merge + encode + write + rename) on every
    // 5th exit — millions of filesystem operations inside a render loop.
    // Nested exits must never touch the filesystem; a long nested loop
    // delivers its data exactly once per checkpoint, with exact counts.
    'hot nested loop flushes at checkpoints only, counts exact',
    () {
      final json = runCollectorIn(hotNestedLoopDriver, dir: dir);
      // 4 deterministic backstops (at 100k/200k/300k/400k nested exits,
      // bounded crash-loss) + the outermost frame exit + the explicit
      // final flush = 6 — vs ~90k writes with the old every-5-exits
      // policy. With the default CRAP_PROFILE_FLUSH_MS=0 the count is
      // deterministic (no interval flushes).
      expect(json['#flushes']['calls'], 6);
      expect(json['Hot.frame']['calls'], 1);
      expect(json['Hot.skinVertex']['calls'], 50000);
      expect(json['Hot.transform']['calls'], 400000);
    },
  );

  test(
    // A short run must not need an explicit flush(): every outermost
    // exit flushes by default, so brief tests never lose their tail.
    'short run delivers tail without an explicit flush',
    () {
      final json = runCollectorIn(shortRunDriver, dir: dir);
      expect(json['A.b']['calls'], 43);
    },
  );

  test(
    // When the stack is stuck non-empty (a leaked frame whose exit never
    // ran), outermost exits never happen; the backstop must still deliver
    // data at the configured interval.
    'backstop flushes while the stack is stuck non-empty',
    () {
      final json = runCollectorIn(
        stuckStackDriver,
        env: const {'CRAP_PROFILE_FLUSH_EVERY': '100'},
        dir: dir,
      );
      // Backstop fired at call 100; the tail (50 calls) stays in memory
      // by design — bounded loss, documented.
      expect(json['A.b']['calls'], 100);
    },
  );

  test(
    // CRAP_PROFILE_FLUSH_MS opts into interval throttling for
    // outermost-heavy loops; the tail after the last throttled exit is
    // then delivered only by an explicit flush() — documented trade.
    'interval throttle bounds outermost-heavy flushes',
    () {
      final json = runCollectorIn(
        throttledOutermostDriver,
        env: const {'CRAP_PROFILE_FLUSH_MS': '60000'},
        dir: dir,
      );
      // The interval never elapses inside the driver (60s), so even the
      // first outermost exit skips its flush; exactly one shard write —
      // the final forced flush — delivers everything.
      expect(json['#flushes']['calls'], 1);
      expect(json['A.b']['calls'], 2000);
    },
  );
}
