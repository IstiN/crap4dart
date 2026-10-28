import 'dart:convert';
import 'dart:io';

import '../../analysis/method_extractor.dart';
import '../../cli/runner.dart';
import 'mutation_operators.dart';

/// Cache file name, written under the project root.
const String mutationCacheFileName = '.crap-mutation-cache.json';

/// Current cache envelope version; a mismatch discards the file.
const int mutationCacheVersion = 1;

/// Cache identity of one method: the lookup key, the digest of the
/// method's exact source span, and the method's start offset (site
/// offsets are stored relative to it, so an edit in an earlier method
/// never shifts the identity of later methods' sites).
typedef MethodRef = ({String key, String digest, int start});

/// FNV-1a over a 64-bit state, output-masked to 63 bits (the Dart VM
/// interprets hex literals >= 2^63 as negative), as 16 hex chars —
/// zero dependencies, stable across platforms/runs.
String fnv1a64Hex(String text) {
  var hash = 0xcbf29ce484222325;
  const prime = 0x1000001b3;
  for (final byte in utf8.encode(text)) {
    hash = ((hash ^ byte) * prime) & 0x7FFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

/// Fresh per-method outcomes of one mutation run: the method digest
/// the outcomes belong to, plus each mutant's cached verdict.
typedef FreshOutcomes = ({String digest, List<CachedOutcome> outcomes});

/// Mutation-relevant configuration fingerprint. Stored in the cache
/// envelope; any mismatch wipes the cache (full re-execution) because
/// cached outcomes were produced under different semantics.
class MutationCacheMeta {
  /// Tool and version that wrote the cache.
  final String tool;

  /// Enabled operator categories (sorted, comma-joined).
  final String operators;

  /// Per-mutant test invocation args (comma-joined).
  final String testArgs;

  /// Creates a [MutationCacheMeta].
  const MutationCacheMeta({
    required this.tool,
    required this.operators,
    required this.testArgs,
  });

  /// The meta of this tool version and [operators]/[testArgs] combo.
  factory MutationCacheMeta.current({
    required List<String> operators,
    required List<String> testArgs,
  }) {
    final sorted = [...operators]..sort();
    return MutationCacheMeta(
      tool: 'crap4dart $crap4dartVersion',
      operators: sorted.join(','),
      testArgs: testArgs.join(','),
    );
  }

  /// Parses [json]; `null` fields become empty strings (never matches).
  factory MutationCacheMeta.fromJson(Map<String, dynamic> json) =>
      MutationCacheMeta(
        tool: json['tool'] as String? ?? '',
        operators: json['operators'] as String? ?? '',
        testArgs: json['test_args'] as String? ?? '',
      );

  /// Whether [other] was produced under identical semantics.
  bool matches(MutationCacheMeta other) =>
      tool == other.tool &&
      operators == other.operators &&
      testArgs == other.testArgs;

  /// JSON form: `{'tool': ..., 'operators': ..., 'test_args': ...}`.
  Map<String, dynamic> toJson() =>
      {'tool': tool, 'operators': operators, 'test_args': testArgs};
}

/// One cached per-site outcome (`killed`, `survived` or `timeout`).
class CachedOutcome {
  /// Offset of the replaced span relative to the containing method's
  /// start (stable across edits elsewhere in the file).
  final int offset;

  /// 1-based source line of the replaced token.
  final int line;

  /// Operator category.
  final String category;

  /// Original lexeme at the site.
  final String original;

  /// Lexeme replacing [original] in the mutant.
  final String mutant;

  /// Outcome of the run that produced this entry (`killed`, ...).
  final String status;

  /// Creates a [CachedOutcome].
  const CachedOutcome({
    required this.offset,
    required this.line,
    required this.category,
    required this.original,
    required this.mutant,
    required this.status,
  });

  /// Parses one outcome entry; malformed fields fall back to values
  /// that can never replay (offset `-1`).
  factory CachedOutcome.fromJson(Map<String, dynamic> json) => CachedOutcome(
        offset: json['offset'] as int? ?? -1,
        line: json['line'] as int? ?? 0,
        category: json['category'] as String? ?? '',
        original: json['original'] as String? ?? '',
        mutant: json['mutant'] as String? ?? '',
        status: json['status'] as String? ?? '',
      );

  /// JSON form of this outcome.
  Map<String, dynamic> toJson() => {
        'offset': offset,
        'line': line,
        'category': category,
        'original': original,
        'mutant': mutant,
        'status': status,
      };
}

/// Cached outcomes of one method, keyed by [MutationCache.methodsKey].
class CachedMethod {
  /// FNV-1a hex digest of the method's exact source span.
  final String digest;

  /// Per-site outcomes of the last run that executed this method.
  final List<CachedOutcome> outcomes;

  /// Creates a [CachedMethod].
  const CachedMethod({required this.digest, required this.outcomes});

  /// Parses one method entry.
  factory CachedMethod.fromJson(Map<String, dynamic> json) => CachedMethod(
        digest: json['digest'] as String? ?? '',
        outcomes: [
          if (json['outcomes'] is List)
            for (final entry in json['outcomes'] as List)
              if (entry is Map<String, dynamic>) CachedOutcome.fromJson(entry),
        ],
      );

  /// JSON form of this method entry.
  Map<String, dynamic> toJson() => {
        'digest': digest,
        'outcomes': [for (final outcome in outcomes) outcome.toJson()],
      };
}

/// The digest-incremental killed-stays-killed cache: per-method
/// outcomes keyed by source-text digest. Only `killed` outcomes are
/// replayable; survivors are always re-executed.
class MutationCache {
  /// Config fingerprint this cache was built under.
  final MutationCacheMeta meta;

  /// Method entries, keyed by [methodsKey].
  final Map<String, CachedMethod> methods;

  /// Creates a [MutationCache] holding [methods] under [meta].
  MutationCache({required this.meta, Map<String, CachedMethod>? methods})
      : methods = methods ?? {};

  /// Stable cache key of a method: relative file path plus
  /// `className.methodName` (two methods may share a name across
  /// files — the file path keeps them distinct).
  static String methodsKey(String relativePath, MethodInfo method) =>
      '$relativePath#${method.className}.${method.methodName}';

  /// Loads the cache at [path] under [meta]. A missing, corrupt,
  /// outdated or meta-mismatched file yields an empty cache — a full
  /// re-execution under the current semantics.
  static MutationCache load(
      {required String path, required MutationCacheMeta meta}) {
    final file = File(path);
    if (!file.existsSync()) return MutationCache(meta: meta);
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) {
        return MutationCache(meta: meta);
      }
      if (decoded['version'] != mutationCacheVersion) {
        return MutationCache(meta: meta);
      }
      final stored = MutationCacheMeta.fromJson(
          (decoded['meta'] as Map?)?.cast<String, dynamic>() ?? const {});
      if (!stored.matches(meta)) return MutationCache(meta: meta);
      return MutationCache(meta: meta, methods: _readMethods(decoded));
    } on FormatException {
      return MutationCache(meta: meta);
    }
  }

  static Map<String, CachedMethod> _readMethods(Map<String, dynamic> decoded) {
    final raw = decoded['methods'];
    if (raw is! Map) return {};
    final methods = <String, CachedMethod>{};
    raw.forEach((key, value) {
      if (key is String && value is Map<String, dynamic>) {
        methods[key] = CachedMethod.fromJson(value);
      }
    });
    return methods;
  }

  /// Returns the cached `killed` outcome matching [site] when the
  /// stored digest equals [ref.digest]; `null` means the mutant must be
  /// executed (changed method, unknown site, or a survivor). Stored
  /// offsets are relative to the method start, so [ref] supplies it.
  CachedOutcome? replayKill(MethodRef ref, MutationSite site) {
    final method = methods[ref.key];
    if (method == null || method.digest != ref.digest) return null;
    return _killedMatch(method, site, ref.start);
  }

  /// Merges one run's [fresh] outcomes into the cache: methods seen
  /// this run get their current digest plus the union of fresh and
  /// still-valid old outcomes; methods absent from [liveMethodKeys]
  /// (deleted or excluded files) are pruned.
  void mergeRun(
    Map<String, FreshOutcomes> fresh,
    Set<String> liveMethodKeys,
  ) {
    methods.removeWhere((key, _) => !liveMethodKeys.contains(key));
    fresh.forEach((key, entry) {
      final old = methods[key];
      final kept = old == null
          ? const <CachedOutcome>[]
          : old.outcomes.where((o) => !_superseded(o, entry.outcomes));
      methods[key] = CachedMethod(
        digest: entry.digest,
        outcomes: [...entry.outcomes, ...kept],
      );
    });
  }

  /// JSON envelope: `{version, meta, methods}`.
  Map<String, dynamic> toJson() => {
        'version': mutationCacheVersion,
        'meta': meta.toJson(),
        'methods': {
          for (final entry in methods.entries) entry.key: entry.value.toJson(),
        },
      };

  /// Writes the cache to [path] (pretty-printed, parent must exist).
  void save(String path) {
    File(path).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(toJson()));
  }

  CachedOutcome? _killedMatch(
    CachedMethod method,
    MutationSite site,
    int start,
  ) {
    for (final outcome in method.outcomes) {
      if (outcome.status != 'killed') continue;
      if (_matchesSite(outcome, site, start)) return outcome;
    }
    return null;
  }

  bool _matchesSite(CachedOutcome outcome, MutationSite site, int start) =>
      outcome.offset == site.offset - start &&
      outcome.category == site.category &&
      outcome.original == site.original &&
      outcome.mutant == site.mutant;

  bool _superseded(CachedOutcome old, List<CachedOutcome> fresh) =>
      fresh.any((o) => _sameSite(o, old));

  bool _sameSite(CachedOutcome a, CachedOutcome b) =>
      a.offset == b.offset &&
      a.category == b.category &&
      a.original == b.original &&
      a.mutant == b.mutant;
}

/// Everything the engine needs to consult and update the on-disk
/// cache during one gate run.
class MutationCacheSession {
  /// The loaded (or fresh) cache for this run.
  final MutationCache cache;

  /// Absolute path of the cache file to persist after the run.
  final String cacheFile;

  /// Cache identity (key + digest) of every site that lives inside an
  /// extracted method; sites outside methods are never cached.
  final Map<MutationSite, MethodRef> siteMethods;

  /// Keys of every method in the scanned scope — used for pruning.
  final Set<String> liveKeys;

  /// Creates a [MutationCacheSession].
  const MutationCacheSession({
    required this.cache,
    required this.cacheFile,
    required this.siteMethods,
    required this.liveKeys,
  });
}
