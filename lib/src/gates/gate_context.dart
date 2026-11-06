import '../common/constants.dart';
import 'dart:collection';
import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import '../analysis/dart_parser.dart';
import '../config/config.dart';
import '../coverage/lcov_parser.dart';
import '../files/diff_parser.dart';
import '../files/flutter_project.dart' as files_flutter;

/// Shared input for all quality gates: project root, config, target files,
/// optional coverage data and a bounded LRU cache of parsed units.
class GateContext {
  /// Absolute path of the project root.
  final String projectRoot;

  /// The loaded crap4dart configuration.
  final Crap4DartConfig config;

  /// Dart files targeted by this run (mode: all / changed / staged).
  final List<String> files;

  /// Parsed LCOV coverage, or `null` when no coverage file was found.
  final List<FileCoverage>? lcov;

  /// Whether [files] is a partial selection (`--changed`, `--staged` or
  /// `--diff`) rather than the full source set. Whole-project gates
  /// (unused_code, unused_files) skip themselves in partial runs: their
  /// verdicts need every file's imports and references.
  final bool partialSelection;

  /// Added/changed lines of the current diff run (`--diff` / `--diff-base`),
  /// or `null` in full runs. Gates that can scope their work (the
  /// mutation gate) intersect their candidate set with the diff BEFORE
  /// executing instead of only filtering reported violations afterwards.
  final DiffLineMap? diff;

  /// Per-cache byte budget for [_astCache] and [_linesCache]. AST gates
  /// share parsed units to avoid re-parsing the tree in every gate, but
  /// an unbounded cache retains every touched file's AST for the whole
  /// run — multi-GB on large trees (IstiN/crap4dart#34). The caches are
  /// LRU: once the summed source bytes exceed this budget, the least
  /// recently used entries are dropped and re-parsed on next access.
  final int cacheBudgetBytes;

  static const int _defaultCacheBudgetBytes = 32 * 1024 * 1024;

  final LinkedHashMap<String, _AstCacheEntry> _astCache = LinkedHashMap();

  int _astCacheBytes = 0;

  final LinkedHashMap<String, _LinesCacheEntry> _linesCache = LinkedHashMap();

  int _linesCacheBytes = 0;

  String? _packageName;

  final Map<String, Glob> _globCache = {};

  /// Creates a [GateContext].
  GateContext({
    required this.projectRoot,
    required this.config,
    required this.files,
    this.lcov,
    this.partialSelection = false,
    this.diff,
    this.cacheBudgetBytes = _defaultCacheBudgetBytes,
  });

  /// Whether the pubspec at [root] declares a `flutter` dependency.
  static bool isFlutterProjectAt(String root) =>
      files_flutter.isFlutterProject(root);

  /// The `name:` of the project's pubspec.yaml, or `null` when absent.
  String? get packageName => _packageName ??= _readPackageName(
        p.join(projectRoot, kPubspec),
      );

  /// Whether the project is a Flutter project (its pubspec depends on the
  /// `flutter` package).
  bool get isFlutterProject => isFlutterProjectAt(projectRoot);

  /// 1-based [lineNumber] of the file at [path], or `null` when out of
  /// range or the file is unreadable.
  String? line(String path, int lineNumber) {
    final lines = _lines(path);
    if (lines.isEmpty) return null;
    return lineNumber >= 1 && lineNumber <= lines.length
        ? lines[lineNumber - 1]
        : null;
  }

  /// Whether the file at [path] has at least [lineNumber] lines.
  bool hasLine(String path, int lineNumber) => line(path, lineNumber) != null;

  /// Returns the parsed AST of the Dart file at [path], parsing and caching
  /// it on first access. AST gates share this cache because parsing is
  /// expensive; the cache is LRU-bounded by [cacheBudgetBytes] so large
  /// trees don't retain every AST for the whole run (#34).
  ParsedUnit parsed(String path) {
    final cached = _astCache.remove(path);
    if (cached != null) {
      _astCache[path] = cached;
      return cached.unit;
    }
    final content = File(path).readAsStringSync();
    final unit = DartParser().parse(content: content, path: path);
    _astCache[path] = _AstCacheEntry(unit, content.length);
    _astCacheBytes += content.length;
    _evictAstCache();
    return unit;
  }

  /// Drops least recently used AST entries until the cache fits the
  /// budget.
  void _evictAstCache() {
    while (_astCacheBytes > cacheBudgetBytes && _astCache.isNotEmpty) {
      final evicted = _astCache.remove(_astCache.keys.first)!;
      _astCacheBytes -= evicted.sourceBytes;
    }
  }

  /// [path] made relative to [projectRoot] when possible.
  String relativePath(String path) =>
      p.isAbsolute(path) ? p.relative(path, from: projectRoot) : path;

  /// Whether any of [patterns] (globs) matches [path], which is first made
  /// relative to [projectRoot]. Compiled globs are cached per pattern —
  /// this runs for every file in every gate.
  bool matchesAnyGlob(String path, List<String> patterns) {
    final relative = relativePath(path);
    return patterns.any((pattern) => _glob(pattern).matches(relative));
  }

  String? _readPackageName(String pubspecPath) {
    try {
      final content = File(pubspecPath).readAsStringSync();
      final match = RegExp(
        kPubspecNamePattern,
        multiLine: true,
      ).firstMatch(content);
      return match?.group(1)?.trim();
    } on FileSystemException {
      return null;
    }
  }

  /// The lines of the file at [path], read and cached on first access;
  /// empty for unreadable files.
  List<String> _lines(String path) {
    final cached = _linesCache.remove(path);
    if (cached != null) {
      _linesCache[path] = cached;
      return cached.lines;
    }
    final lines = _readLines(path);
    final sourceBytes = lines.join().length;
    _linesCache[path] = _LinesCacheEntry(lines, sourceBytes);
    _linesCacheBytes += sourceBytes;
    _evictLinesCache();
    return lines;
  }

  static List<String> _readLines(String path) {
    try {
      return File(path).readAsStringSync().split('\n');
    } on FileSystemException {
      return const [];
    }
  }

  /// Drops least recently used line entries until the cache fits the
  /// budget.
  void _evictLinesCache() {
    while (_linesCacheBytes > cacheBudgetBytes && _linesCache.isNotEmpty) {
      final evicted = _linesCache.remove(_linesCache.keys.first)!;
      _linesCacheBytes -= evicted.sourceBytes;
    }
  }

  /// The compiled glob for [pattern], parsed at most once.
  Glob _glob(String pattern) =>
      _globCache.putIfAbsent(pattern, () => Glob(pattern));
}

/// One entry of [GateContext._astCache]: the parsed unit and the source
/// byte size it accounts for.
class _AstCacheEntry {
  final ParsedUnit unit;

  /// Length of the source the [unit] was parsed from.
  final int sourceBytes;

  const _AstCacheEntry(this.unit, this.sourceBytes);
}

/// One entry of [GateContext._linesCache]: the split lines and the byte
/// size they account for.
class _LinesCacheEntry {
  final List<String> lines;

  /// Joined length of [lines] — a close proxy of the source size.
  final int sourceBytes;

  const _LinesCacheEntry(this.lines, this.sourceBytes);
}

/// One scanned corpus file: the parsed unit and its project-relative
/// path.
typedef ParsedCorpusFile = ({dynamic parsed, String relativePath});

/// One scanned corpus file: absolute and project-relative paths.
typedef ScannedFile = ({String file, String relativePath});

/// Corpus iteration shared by the corpus-wide gates.
extension GateContextScan on GateContext {
  /// Yields (absolute file, project-relative path) pairs minus
  /// [exclude] and [ignorePaths] files — excluded and ignored paths
  /// contribute nothing.
  Iterable<ScannedFile> scanCorpus(
    List<String> exclude,
    List<String> ignorePaths,
  ) sync* {
    for (final file in files) {
      if (matchesAnyGlob(file, exclude) || matchesAnyGlob(file, ignorePaths)) {
        continue;
      }
      yield (file: file, relativePath: relativePath(file));
    }
  }

  /// Parsed units of [scanCorpus], yielding each unit with its
  /// project-relative path.
  Iterable<ParsedCorpusFile> parsedCorpus(
    List<String> exclude,
    List<String> ignorePaths,
  ) sync* {
    for (final scanned in scanCorpus(exclude, ignorePaths)) {
      yield (
        parsed: parsed(scanned.file),
        relativePath: scanned.relativePath,
      );
    }
  }
}
