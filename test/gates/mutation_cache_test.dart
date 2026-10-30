import 'dart:convert';
import 'dart:io';

import 'package:crap4dart/src/gates/mutation/mutation_cache.dart';
import 'package:crap4dart/src/gates/mutation/mutation_operators.dart';
import 'package:test/test.dart';

MutationSite site({int offset = 10, String mutant = '-'}) => MutationSite(
      file: '/p/lib/a.dart',
      line: 3,
      method: '(top-level).add',
      category: 'arithmetic',
      original: '+',
      mutant: mutant,
      offset: offset,
      length: 1,
    );

void main() {
  fnvTests();
  replayTests();
  persistenceTests();
}

void fnvTests() {
  group('fnv1a64Hex', () {
    test('is deterministic and 16 hex chars', () {
      final first = fnv1a64Hex('int add(int a, int b) => a + b;');
      expect(first, fnv1a64Hex('int add(int a, int b) => a + b;'));
      expect(first, hasLength(16));
      expect(int.parse(first, radix: 16), isNonNegative);
    });

    test('changes on any edit, however small', () {
      final base = fnv1a64Hex('return a + b;');
      expect(fnv1a64Hex('return a + b; '), isNot(base));
      expect(fnv1a64Hex('return a - b;'), isNot(base));
    });
  });
}

MethodRef refFor(String digest, {int start = 0}) => (
      key: 'lib/a.dart#(top-level).add',
      digest: digest,
      start: start,
    );

MutationCache cacheWith(String status) => MutationCache(
      meta: MutationCacheMeta.current(
        operators: const ['arithmetic'],
        testArgs: const ['test'],
      ),
      methods: {
        'lib/a.dart#(top-level).add': CachedMethod(
          digest: 'd1',
          outcomes: [
            CachedOutcome(
              offset: 10,
              line: 3,
              category: 'arithmetic',
              original: '+',
              mutant: '-',
              status: status,
            ),
          ],
        ),
      },
    );

void replayTests() {
  group('MutationCache.replayKill', () {
    test('replays a killed outcome on digest and site match', () {
      final replay = cacheWith('killed').replayKill(refFor('d1'), site());
      expect(replay, isNotNull);
      expect(replay!.status, 'killed');
    });

    test('never replays survivors or timeouts', () {
      for (final status in ['survived', 'timeout']) {
        final replay = cacheWith(status).replayKill(refFor('d1'), site());
        expect(replay, isNull, reason: status);
      }
    });

    test('does not replay on digest, key or site identity mismatch', () {
      final cache = cacheWith('killed');
      expect(cache.replayKill(refFor('other'), site()), isNull);
      final otherKey = (
        key: 'lib/b.dart#(top-level).add',
        digest: 'd1',
        start: 0,
      );
      expect(cache.replayKill(otherKey, site()), isNull);
      expect(cache.replayKill(refFor('d1'), site(offset: 99)), isNull);
      expect(cache.replayKill(refFor('d1'), site(mutant: '*')), isNull);
    });

    test('matches offsets relative to the method start', () {
      // The site sits at absolute offset 20; the method starts at 10,
      // so the stored relative offset 10 matches only with start: 10.
      final cache = cacheWith('killed');
      final shifted = site(offset: 20);
      expect(cache.replayKill(refFor('d1', start: 10), shifted), isNotNull);
      expect(cache.replayKill(refFor('d1', start: 0), shifted), isNull);
    });
  });
}

void persistenceTests() {
  roundTripTests();
  mergeTests();
}

final meta = MutationCacheMeta.current(
  operators: const ['arithmetic'],
  testArgs: const ['test'],
);

MutationCache populated() => MutationCache(
      meta: meta,
      methods: {
        'lib/a.dart#C.add': const CachedMethod(digest: 'd1', outcomes: [
          CachedOutcome(
            offset: 5,
            line: 2,
            category: 'arithmetic',
            original: '+',
            mutant: '-',
            status: 'killed',
          ),
        ]),
        'lib/b.dart#C.add': const CachedMethod(digest: 'd2', outcomes: [
          CachedOutcome(
            offset: 7,
            line: 4,
            category: 'boundary',
            original: '>',
            mutant: '>=',
            status: 'survived',
          ),
        ]),
      },
    );

void roundTripTests() {
  group('MutationCache persistence', () {
    late Directory dir;
    late String path;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('crap4dart_cache_test_');
      path = '${dir.path}/.crap-mutation-cache.json';
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('round-trips through the JSON envelope', () {
      populated().save(path);
      final decoded = jsonDecode(File(path).readAsStringSync());
      expect(decoded, isA<Map<String, dynamic>>());
      expect((decoded as Map)['version'], mutationCacheVersion);
      expect(decoded['meta'], isA<Map>());
      expect(decoded['methods'], isA<Map>());
      final loaded = MutationCache.load(path: path, meta: meta);
      expect(loaded.methods.keys, {'lib/a.dart#C.add', 'lib/b.dart#C.add'});
      final method = loaded.methods['lib/a.dart#C.add']!;
      expect(method.digest, 'd1');
      expect(method.outcomes.single.status, 'killed');
      expect(method.outcomes.single.offset, 5);
    });

    test('same method name in different files stays distinct', () {
      populated().save(path);
      final loaded = MutationCache.load(path: path, meta: meta);
      expect(loaded.methods['lib/a.dart#C.add']!.digest, 'd1');
      expect(loaded.methods['lib/b.dart#C.add']!.digest, 'd2');
    });

    test('missing, corrupt or version-mismatched file yields a fresh cache',
        () {
      expect(MutationCache.load(path: path, meta: meta).methods, isEmpty);
      File(path).writeAsStringSync('not json {{{');
      expect(MutationCache.load(path: path, meta: meta).methods, isEmpty);
      File(path).writeAsStringSync('{"version": 999, "meta": {}, '
          '"methods": {}}');
      expect(MutationCache.load(path: path, meta: meta).methods, isEmpty);
    });

    test('meta mismatch (operators or test_args) wipes the cache', () {
      populated().save(path);
      final otherOperators = MutationCache.load(
        path: path,
        meta: MutationCacheMeta.current(
          operators: const ['boundary'],
          testArgs: const ['test'],
        ),
      );
      expect(otherOperators.methods, isEmpty);
      final otherArgs = MutationCache.load(
        path: path,
        meta: MutationCacheMeta.current(
          operators: const ['arithmetic'],
          testArgs: const ['test', 'test/copilot'],
        ),
      );
      expect(otherArgs.methods, isEmpty);
    });
  });
}

void mergeTests() {
  group('MutationCache.mergeRun', () {
    test('prunes vanished methods and supersedes old outcomes', () {
      final cache = populated();
      cache.mergeRun({
        'lib/a.dart#C.add': (
          digest: 'd1b',
          outcomes: const [
            CachedOutcome(
              offset: 5,
              line: 2,
              category: 'arithmetic',
              original: '+',
              mutant: '-',
              status: 'killed',
            ),
          ],
        ),
      }, {
        'lib/a.dart#C.add',
      });
      expect(cache.methods.keys, {'lib/a.dart#C.add'});
      expect(cache.methods['lib/a.dart#C.add']!.digest, 'd1b');
    });
  });
}
