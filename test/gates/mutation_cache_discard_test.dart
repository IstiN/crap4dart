import 'dart:convert';
import 'dart:io';

import 'package:crap4dart/src/gates/mutation/mutation_cache.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final meta = MutationCacheMeta.current(
  operators: ['arithmetic'],
  testArgs: const [],
);

String cachePath(Directory dir) => p.join(dir.path, '.mutation_cache.json');

void writeCache(Directory dir, Object json) {
  File(cachePath(dir)).writeAsStringSync(jsonEncode(json));
}

Map<String, dynamic> validCache({int? version}) => {
      'version': version ?? mutationCacheVersion,
      'meta': meta.toJson(),
      'methods': <String, dynamic>{},
    };

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('crap4dart_cache_discard_');
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  test('missing file loads fresh silently', () {
    final reasons = <String>[];
    final cache = MutationCache.load(
      path: cachePath(dir),
      meta: meta,
      onDiscard: reasons.add,
    );
    expect(reasons, isEmpty);
    expect(cache.methods, isEmpty);
  });

  test('valid cache loads without a discard', () {
    writeCache(dir, validCache());
    final reasons = <String>[];
    final cache = MutationCache.load(
      path: cachePath(dir),
      meta: meta,
      onDiscard: reasons.add,
    );
    expect(reasons, isEmpty);
    expect(cache.methods, isEmpty);
  });

  test('corrupt JSON discards with a reason', () {
    File(cachePath(dir)).writeAsStringSync('{not json');
    final reasons = <String>[];
    MutationCache.load(
        path: cachePath(dir), meta: meta, onDiscard: reasons.add);
    expect(reasons, hasLength(1));
    expect(reasons.single, contains('corrupt JSON'));
  });

  test('non-object JSON discards with a reason', () {
    writeCache(dir, ['not', 'an', 'object']);
    final reasons = <String>[];
    MutationCache.load(
        path: cachePath(dir), meta: meta, onDiscard: reasons.add);
    expect(reasons.single, contains('not a JSON object'));
  });

  test('version mismatch discards with a reason', () {
    writeCache(dir, validCache(version: mutationCacheVersion + 1));
    final reasons = <String>[];
    MutationCache.load(
        path: cachePath(dir), meta: meta, onDiscard: reasons.add);
    expect(reasons.single, contains('version mismatch'));
  });

  test('meta mismatch discards with a reason', () {
    final otherMeta = MutationCacheMeta.current(
      operators: ['arithmetic', 'equality'],
      testArgs: const [],
    );
    writeCache(dir, {
      'version': mutationCacheVersion,
      'meta': otherMeta.toJson(),
      'methods': <String, dynamic>{},
    });
    final reasons = <String>[];
    MutationCache.load(
        path: cachePath(dir), meta: meta, onDiscard: reasons.add);
    expect(reasons.single, contains('meta mismatch'));
  });

  test('without onDiscard a corrupt cache still loads fresh', () {
    File(cachePath(dir)).writeAsStringSync('{not json');
    final cache = MutationCache.load(path: cachePath(dir), meta: meta);
    expect(cache.methods, isEmpty);
  });
}
