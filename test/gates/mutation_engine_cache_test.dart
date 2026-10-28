import 'dart:io';

import 'package:crap4dart/src/analysis/dart_parser.dart';
import 'package:crap4dart/src/analysis/method_extractor.dart';
import 'package:crap4dart/src/config/config.dart';
import 'package:crap4dart/src/gates/mutation/mutation_cache.dart';
import 'package:crap4dart/src/gates/mutation/mutation_engine.dart';
import 'package:crap4dart/src/gates/mutation/mutation_operators.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const fileASource = '''
int add(int a, int b) {
  return a + b;
}

int zero() {
  return 0;
}
''';

const fileBSource = '''
int add(int a, int b) {
  return a - b;
}
''';

late Directory dir;

final meta = MutationCacheMeta.current(
  operators: mutationOperatorCategories,
  testArgs: const ['test'],
);

void main() {
  setUp(() => dir = Directory.systemTemp.createTempSync('crap4dart_mcache_'));
  tearDown(() => dir.deleteSync(recursive: true));
  replayTests();
  invalidationTests();
  pruningTests();
  crossFileKeyTests();
  integrityTests();
}

String writeSource(String name, String content) {
  final file = File(p.join(dir.path, name));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
  return file.path;
}

/// Detects the real sites of [content] (parsed as [relative]).
List<MutationSite> detectSites(String relative, String content) =>
    MutationSiteDetector().detect(
      DartParser().parse(content: content, path: p.join(dir.path, relative)),
    );

List<ExtractedMethod> methodsOf(String relative, String content) {
  final parsed =
      DartParser().parse(content: content, path: p.join(dir.path, relative));
  return const MethodExtractor()
      .extractWithNodes(parsed.unit, parsed.lineInfo, filePath: relative);
}

/// Binds every site to its containing method's cache identity,
/// mirroring the gate's digest binding.
Map<MutationSite, MethodRef> bindRefs(
  String relative,
  String content,
  List<MutationSite> sites,
) {
  final refs = <MutationSite, MethodRef>{};
  for (final site in sites) {
    for (final method in methodsOf(relative, content)) {
      final node = method.node;
      if (site.offset < node.offset || site.offset > node.end) continue;
      refs[site] = (
        key: MutationCache.methodsKey(relative, method.info),
        digest: fnv1a64Hex(content.substring(node.offset, node.end)),
        start: node.offset,
      );
    }
  }
  return refs;
}

Set<String> liveKeys(String relative, String content) => {
      for (final method in methodsOf(relative, content))
        MutationCache.methodsKey(relative, method.info),
    };

/// One gate-run-shaped engine invocation: loads the on-disk cache,
/// executes with [runner], merges and persists.
Future<MutationRunResult> runCached({
  required List<MutationSite> sites,
  required Map<MutationSite, MethodRef> refs,
  required Set<String> live,
  required MutantTestRunner runner,
  MutationCacheMeta? withMeta,
}) {
  final cacheFile = p.join(dir.path, mutationCacheFileName);
  final cache = MutationCache.load(path: cacheFile, meta: withMeta ?? meta);
  return MutationEngine(runner: runner).run(
    projectRoot: dir.path,
    sites: sites,
    timeout: const Duration(seconds: 5),
    caching: MutationCacheSession(
      cache: cache,
      cacheFile: cacheFile,
      siteMethods: refs,
      liveKeys: live,
    ),
  );
}

void replayTests() {
  group('cache replay', () {
    test('second run makes zero runner calls for unchanged killed mutants',
        () async {
      writeSource('lib/a.dart', fileASource);
      final sites = detectSites('lib/a.dart', fileASource);
      expect(sites, hasLength(2));
      var calls = 0;
      Future<MutantOutcome> counting(
          String root, Duration timeout, List<String> args) async {
        calls++;
        return MutantOutcome.killed;
      }

      final first = await runCached(
        sites: sites,
        refs: bindRefs('lib/a.dart', fileASource, sites),
        live: liveKeys('lib/a.dart', fileASource),
        runner: counting,
      );
      expect(calls, 2);
      expect(first.killed, 2);
      expect(
          File(p.join(dir.path, mutationCacheFileName)).existsSync(), isTrue);

      calls = 0;
      final second = await runCached(
        sites: sites,
        refs: bindRefs('lib/a.dart', fileASource, sites),
        live: liveKeys('lib/a.dart', fileASource),
        runner: counting,
      );
      expect(calls, 0, reason: 'killed mutants of unchanged methods replay');
      expect(second.killed, 2);
      expect(second.fromCacheCount, 2);
      expect(second.score, first.score);
    });

    test('survivors are always re-executed on the second run', () async {
      writeSource('lib/a.dart', fileASource);
      final sites = detectSites('lib/a.dart', fileASource);
      var call = 0;
      final first = await runCached(
        sites: sites,
        refs: bindRefs('lib/a.dart', fileASource, sites),
        live: liveKeys('lib/a.dart', fileASource),
        runner: (root, timeout, args) async =>
            ++call == 1 ? MutantOutcome.killed : MutantOutcome.survived,
      );
      expect(first.killed, 1);
      expect(first.survived, 1);

      var secondCalls = 0;
      final second = await runCached(
        sites: sites,
        refs: bindRefs('lib/a.dart', fileASource, sites),
        live: liveKeys('lib/a.dart', fileASource),
        runner: (root, timeout, args) async {
          secondCalls++;
          return MutantOutcome.killed;
        },
      );
      expect(secondCalls, 1, reason: 'only the survivor re-executes');
      expect(second.fromCacheCount, 1);
      expect(second.killed, 2);
      expect(second.survived, 0);
    });
  });
}

void invalidationTests() {
  group('cache invalidation', () {
    test('an edit inside a method re-executes only its mutants', () async {
      final path = writeSource('lib/a.dart', fileASource);
      final sites = detectSites('lib/a.dart', fileASource);
      final first = await runCached(
        sites: sites,
        refs: bindRefs('lib/a.dart', fileASource, sites),
        live: liveKeys('lib/a.dart', fileASource),
        runner: (root, timeout, args) async => MutantOutcome.killed,
      );
      expect(first.killed, 2);

      // Add a comment inside `add` only; `zero` stays untouched.
      final edited = fileASource.replaceFirst(
        '  return a + b;\n',
        '  // a clarifying comment\n  return a + b;\n',
      );
      File(path).writeAsStringSync(edited);
      final editedSites = detectSites('lib/a.dart', edited);
      var calls = 0;
      final second = await runCached(
        sites: editedSites,
        refs: bindRefs('lib/a.dart', edited, editedSites),
        live: liveKeys('lib/a.dart', edited),
        runner: (root, timeout, args) async {
          calls++;
          return MutantOutcome.killed;
        },
      );
      expect(calls, 1, reason: 'only add changed; zero replays from cache');
      expect(second.fromCacheCount, 1);
      expect(second.killed, 2);
    });

    test('a meta change (operators) invalidates everything', () async {
      writeSource('lib/a.dart', fileASource);
      final sites = detectSites('lib/a.dart', fileASource);
      await runCached(
        sites: sites,
        refs: bindRefs('lib/a.dart', fileASource, sites),
        live: liveKeys('lib/a.dart', fileASource),
        runner: (root, timeout, args) async => MutantOutcome.killed,
      );
      var calls = 0;
      final second = await runCached(
        sites: sites,
        refs: bindRefs('lib/a.dart', fileASource, sites),
        live: liveKeys('lib/a.dart', fileASource),
        runner: (root, timeout, args) async {
          calls++;
          return MutantOutcome.killed;
        },
        withMeta: MutationCacheMeta.current(
          operators: const ['arithmetic'],
          testArgs: const ['test'],
        ),
      );
      expect(calls, 2);
      expect(second.fromCacheCount, 0);
    });
  });
}

void pruningTests() {
  test('round-trips and prunes vanished methods between runs', () async {
    writeSource('lib/a.dart', fileASource);
    writeSource('lib/b.dart', fileBSource);
    final sitesA = detectSites('lib/a.dart', fileASource);
    final sitesB = detectSites('lib/b.dart', fileBSource);
    await runCached(
      sites: [...sitesA, ...sitesB],
      refs: {
        ...bindRefs('lib/a.dart', fileASource, sitesA),
        ...bindRefs('lib/b.dart', fileBSource, sitesB),
      },
      live: {
        ...liveKeys('lib/a.dart', fileASource),
        ...liveKeys('lib/b.dart', fileBSource),
      },
      runner: (root, timeout, args) async => MutantOutcome.killed,
    );
    final cacheFile = p.join(dir.path, mutationCacheFileName);
    expect(MutationCache.load(path: cacheFile, meta: meta).methods.keys,
        hasLength(3));

    // file b.dart vanishes; a re-run prunes its entries.
    File(p.join(dir.path, 'lib/b.dart')).deleteSync();
    var calls = 0;
    await runCached(
      sites: sitesA,
      refs: bindRefs('lib/a.dart', fileASource, sitesA),
      live: liveKeys('lib/a.dart', fileASource),
      runner: (root, timeout, args) async {
        calls++;
        return MutantOutcome.killed;
      },
    );
    expect(calls, 0);
    expect(MutationCache.load(path: cacheFile, meta: meta).methods.keys,
        {'lib/a.dart#(top-level).add', 'lib/a.dart#(top-level).zero'});
  });
}

void crossFileKeyTests() {
  test('methods sharing a name across files are keyed independently', () async {
    writeSource('lib/a.dart', fileASource);
    writeSource('lib/b.dart', fileBSource);
    final sitesA = detectSites('lib/a.dart', fileASource);
    final sitesB = detectSites('lib/b.dart', fileBSource);
    Map<MutationSite, MethodRef> allRefs() => {
          ...bindRefs('lib/a.dart', fileASource, sitesA),
          ...bindRefs('lib/b.dart', fileBSource, sitesB),
        };
    Set<String> allLive() => {
          ...liveKeys('lib/a.dart', fileASource),
          ...liveKeys('lib/b.dart', fileBSource),
        };
    // Kill everything in a.dart, let all of b.dart survive.
    var call = 0;
    await runCached(
      sites: [...sitesA, ...sitesB],
      refs: allRefs(),
      live: allLive(),
      runner: (root, timeout, args) async => ++call <= sitesA.length
          ? MutantOutcome.killed
          : MutantOutcome.survived,
    );

    var secondCalls = 0;
    final second = await runCached(
      sites: [...sitesA, ...sitesB],
      refs: allRefs(),
      live: allLive(),
      runner: (root, timeout, args) async {
        secondCalls++;
        return MutantOutcome.killed;
      },
    );
    expect(secondCalls, sitesB.length,
        reason: 'only b.dart survivors re-execute; a.dart replays');
    expect(second.fromCacheCount, sitesA.length);
    expect(second.killed, sitesA.length + sitesB.length);
  });
}

void integrityTests() {
  // The fa_llm incident: a real run once ended with a leftover mutant on
  // disk even though the in-process per-site finally-restore is
  // airtight — the defeat must have been out-of-process (external write
  // or a killed VM between apply and restore). The engine therefore
  // snapshots every mutated file before the loop and re-verifies the
  // whole tree in an outer finally. In-process the per-site restore
  // always wins, so the non-empty-violations path cannot be triggered
  // from a unit test; these tests pin the guarantees that can be.
  test('multi-site run leaves every file byte-identical, no violations',
      () async {
    writeSource('lib/a.dart', fileASource);
    writeSource('lib/b.dart', fileBSource);
    final sites = [
      ...detectSites('lib/a.dart', fileASource),
      ...detectSites('lib/b.dart', fileBSource),
    ];
    final result = await MutationEngine(
      runner: (root, timeout, args) async => MutantOutcome.killed,
    ).run(
      projectRoot: dir.path,
      sites: sites,
      timeout: const Duration(seconds: 5),
    );
    expect(
        File(p.join(dir.path, 'lib/a.dart')).readAsStringSync(), fileASource);
    expect(
        File(p.join(dir.path, 'lib/b.dart')).readAsStringSync(), fileBSource);
    expect(result.integrityViolations, isEmpty);
  });

  test('exception mid-loop still leaves every file byte-identical', () async {
    writeSource('lib/a.dart', fileASource);
    final sites = detectSites('lib/a.dart', fileASource);
    var call = 0;
    await expectLater(
      MutationEngine(
        runner: (root, timeout, args) async => ++call == 1
            ? MutantOutcome.killed
            : throw const MutationTestUnavailableException('gone'),
      ).run(
        projectRoot: dir.path,
        sites: sites,
        timeout: const Duration(seconds: 5),
      ),
      throwsA(isA<MutationTestUnavailableException>()),
    );
    expect(
        File(p.join(dir.path, 'lib/a.dart')).readAsStringSync(), fileASource);
  });
}
