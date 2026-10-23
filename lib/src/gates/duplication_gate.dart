import '../common/constants.dart';
import 'dart:io';
import 'dart:math';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

import '../analysis/dart_parser.dart';
import '../config/config.dart';

import 'gate.dart';
import 'gate_context.dart';

part 'duplication_gate_clones.dart';
part 'duplication_gate_mask.dart';

/// A single token together with its source line, raw lexeme, and
/// normalized value (identical to the lexeme when no masking applies).
class _NormalizedToken {
  /// Creates a [_NormalizedToken].
  _NormalizedToken(this.lexeme, this.value, this.line);

  final String lexeme;
  final String value;
  final int line;
  bool duplicated = false;
}

/// Position of a token window inside a file's token stream.
class _TokenPos {
  /// Creates a [_TokenPos].
  _TokenPos(this.fileIndex, this.tokenIndex);

  final int fileIndex;
  final int tokenIndex;
}

/// Token stream of a single file.
class _FileTokens {
  /// Creates a [_FileTokens].
  _FileTokens(this.file, this.tokens, this.totalLines);

  final String file;
  final List<_NormalizedToken> tokens;
  final int totalLines;
}

/// Inclusive-start, exclusive-end character range inside one file.
typedef _CharRange = ({int start, int end});

/// The `duplication` gate: fails files whose duplicated line percentage
/// exceeds the configured threshold.
///
/// The detection tokenizes the whole Dart file with `package:analyzer`,
/// skips comments, then indexes sliding windows of tokens with a
/// Rabin-Karp hash, similar to jscpd. Any duplicated block of at least
/// `min_tokens` tokens and `min_lines` lines is detected within or across
/// files. Two opt-in normalizations extend detection to renamed clones
/// (Type-2): `ignore_locals` renames function-local identifiers
/// consistently in first-use order — the API surface (called method
/// names, type names, field references) keeps its lexeme, so swapped
/// locals or different calls never match — and `ignore_literals`
/// replaces string and numeric literals with type placeholders.
class DuplicationGate implements Gate {
  /// Creates a [DuplicationGate].
  const DuplicationGate();

  @override
  String get id => 'duplication';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.duplication;
    final files = _collectFiles(context, config);

    if (files.isEmpty) {
      return GateResult.pass(id, summary: 'no files with enough tokens');
    }

    final groups = _detectDuplicates(files, config.matching);
    final result = _buildResult(files, groups, config, context);

    return result.violations.isEmpty
        ? GateResult.pass(id, summary: result.summary)
        : GateResult.fail(id, result.violations, summary: result.summary);
  }

  /// Detects duplicated windows, marks the involved tokens and returns
  /// the accepted clone groups. The machinery lives in
  /// `duplication_gate_clones.dart`.
  List<_CloneGroup> _detectDuplicates(
    List<_FileTokens> files,
    DuplicationMatching matching,
  ) =>
      _CloneDetector().detect(files, matching);

  /// Loads and tokenizes the files that participate in duplicate detection.
  ///
  /// Beyond the analyzed source set, the gate's [DuplicationGateConfig.sources]
  /// paths are unioned in — that is what makes cross-module duplication
  /// visible without widening the CRAP analysis scope.
  List<_FileTokens> _collectFiles(
    GateContext context,
    DuplicationGateConfig config,
  ) {
    final files = <String>[...context.files];
    for (final source in _expandSources(context, config.sources)) {
      if (!files.contains(source)) files.add(source);
    }
    files.sort();
    final tokens = <_FileTokens>[];
    for (final file in files) {
      if (context.matchesAnyGlob(file, config.exclude)) continue;
      final parsed = context.parsed(file);
      final fileTokens = _extractFileTokens(parsed, config);
      if (fileTokens.length < config.matching.minTokens) continue;
      // CPD --skip-duplicate-files: a file whose token stream equals an
      // earlier file's is analyzed once — a copied file is reported as
      // one clone group, not as N x N pairs.
      if (config.matching.skipDuplicateFiles &&
          tokens.any((t) => _sameTokens(t.tokens, fileTokens))) {
        continue;
      }
      final totalLines = _lineCount(File(file).readAsStringSync());
      tokens.add(_FileTokens(file, fileTokens, totalLines));
    }
    return tokens;
  }

  /// Whether two token streams are identical by masked value.
  bool _sameTokens(
    List<_NormalizedToken> a,
    List<_NormalizedToken> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].value != b[i].value) return false;
    }
    return true;
  }

  /// Resolves the gate's additional [sources] against the project root:
  /// directories are scanned recursively for `.dart` files, files are
  /// taken directly, missing paths are skipped silently.
  List<String> _expandSources(GateContext context, List<String> sources) {
    final result = <String>[];
    for (final source in sources) {
      final absolute = p.join(context.projectRoot, source);
      final type = FileSystemEntity.typeSync(absolute);
      if (type == FileSystemEntityType.file) {
        if (absolute.endsWith(kDartExtension)) {
          result.add(absolute);
        }
      } else if (type == FileSystemEntityType.directory) {
        for (final entity in Directory(absolute).listSync(recursive: true)) {
          if (entity is File && entity.path.endsWith(kDartExtension)) {
            result.add(entity.path);
          }
        }
      }
    }
    return result;
  }

  /// Builds the gate result from marked token streams and clone groups.
  _Result _buildResult(
    List<_FileTokens> files,
    List<_CloneGroup> groups,
    DuplicationGateConfig config,
    GateContext context,
  ) {
    if (config.report == DuplicationReport.clones) {
      return _clonesResult(files, groups, config, context);
    }
    final violations = <GateViolation>[];
    var checkedLines = 0;
    var duplicatedLines = 0;
    for (final file in files) {
      final dupLineSet = _duplicatedLineSet(file);
      checkedLines += file.totalLines;
      duplicatedLines += dupLineSet.length;
      final violation = _violationFor(file, dupLineSet, config, context);
      if (violation != null) violations.add(violation);
    }

    final totalPercent = checkedLines == 0
        ? 0.0
        : (duplicatedLines / checkedLines) * _percentScale;
    final summary = violations.isEmpty
        ? '${files.length} files, ${totalPercent.toStringAsFixed(2)}% duplicated lines'
        : '${violations.length}/${files.length} files over ${config.threshold}% duplication';
    return _Result(violations, summary);
  }

  /// One violation per clone group, with every occurrence location in
  /// the message (PMD CPD style).
  _Result _clonesResult(
    List<_FileTokens> files,
    List<_CloneGroup> groups,
    DuplicationGateConfig config,
    GateContext context,
  ) {
    final violations = <GateViolation>[];
    for (final group in groups) {
      final occs = group.occurrences;
      final first = files[occs.first.fileIndex];
      final locations = [
        for (final o in occs)
          '${context.relativePath(files[o.fileIndex].file)}:'
              '${files[o.fileIndex].tokens[o.startToken].line}'
              '-'
              '${files[o.fileIndex].tokens[o.endToken - 1].line}',
      ];
      final shown = locations.take(3).join('; ');
      final more =
          locations.length > 3 ? ' (+${locations.length - 3} more)' : '';
      final tokenCount = group.tokenCount;
      final lineSpan = first.tokens[occs.first.endToken - 1].line -
          first.tokens[occs.first.startToken].line +
          1;
      violations.add(
        GateViolation(
          file: context.relativePath(first.file),
          line: first.tokens[occs.first.startToken].line,
          message: 'clone: $tokenCount tokens / $lineSpan lines, '
              '${locations.length} occurrences: $shown$more',
        ),
      );
    }
    final summary = violations.isEmpty
        ? 'no clones >= ${config.matching.minLines} lines across '
            '${files.length} files, '
            '${_totalPercent(files)}% duplicated lines'
        : '${violations.length} clone groups '
            '(>= ${config.matching.minTokens} tokens, '
            '>= ${config.matching.minLines} lines), '
            '${_totalPercent(files)}% duplicated lines';
    return _Result(violations, summary);
  }

  /// The project-wide duplicated-line percentage over [files] (marked
  /// tokens vs total lines) — so a clones-mode summary always carries
  /// a number too.
  String _totalPercent(List<_FileTokens> files) {
    var checkedLines = 0;
    var duplicatedLines = 0;
    for (final file in files) {
      checkedLines += file.totalLines;
      duplicatedLines += _duplicatedLineSet(file).length;
    }
    if (checkedLines == 0) return '0.00';
    return ((duplicatedLines / checkedLines) * _percentScale)
        .toStringAsFixed(2);
  }

  /// The set of [file] lines carrying at least one marked token.
  static Set<int> _duplicatedLineSet(_FileTokens file) {
    final dupLineSet = <int>{};
    for (final token in file.tokens) {
      if (token.duplicated) dupLineSet.add(token.line);
    }
    return dupLineSet;
  }

  /// Percent scale: fraction to percent.
  static const double _percentScale = 100.0;

  /// Returns a violation when the file exceeds the duplication threshold.
  GateViolation? _violationFor(
    _FileTokens file,
    Set<int> dupLineSet,
    DuplicationGateConfig config,
    GateContext context,
  ) {
    if (file.totalLines == 0) return null;
    final percent = (dupLineSet.length / file.totalLines) * _percentScale;
    if (percent <= config.threshold) return null;
    final firstLine = dupLineSet.isEmpty ? null : dupLineSet.reduce(min);
    return GateViolation(
      file: context.relativePath(file.file),
      line: firstLine,
      message: '${percent.toStringAsFixed(2)}% duplicated lines > '
          '${config.threshold}%',
    );
  }

  /// Extracts normalized tokens from the whole parsed file.
  List<_NormalizedToken> _extractFileTokens(
    ParsedUnit parsed,
    DuplicationGateConfig config,
  ) {
    final tokens = <_NormalizedToken>[];
    final mask = _TokenMask.build(parsed, config);
    final skippedRanges = config.matching.ignoreImports
        ? _directiveRanges(parsed.unit)
        : const <_CharRange>[];
    Token? token = parsed.unit.beginToken;
    final end = parsed.unit.endToken;
    while (token != null) {
      if (token.offset > end.offset) break;
      if (_inRanges(skippedRanges, token.offset)) {
        if (token == end) break;
        token = token.next;
        continue;
      }
      final normalized = _normalize(token, mask);
      if (normalized != null) {
        final line = parsed.lineInfo.getLocation(token.offset).lineNumber;
        tokens.add(_NormalizedToken(token.lexeme, normalized, line));
      }
      if (token == end) break;
      token = token.next;
    }
    return tokens;
  }

  /// Char ranges of the compilation unit's import/export/part
  /// directives, for `ignore_imports` skipping.
  List<_CharRange> _directiveRanges(CompilationUnit unit) => [
        for (final directive in unit.directives)
          (start: directive.offset, end: directive.end),
      ];

  /// Whether [offset] falls inside any of [ranges].
  bool _inRanges(List<_CharRange> ranges, int offset) =>
      ranges.any((r) => offset >= r.start && offset < r.end);

  /// Normalizes a token for duplicate detection.
  ///
  /// Comments and synthetic tokens are skipped; string and numeric
  /// literals are masked when [DuplicationGateConfig.ignoreLiterals] is
  /// set, and function-local identifiers are consistently renamed when
  /// [DuplicationGateConfig.ignoreLocals] is set. Everything else keeps
  /// its lexeme. Whitespace is already absent from the analyzer token
  /// stream.
  String? _normalize(Token token, _TokenMask mask) {
    if (token.isSynthetic || token is CommentToken) return null;
    if (token.type.name == 'EOF') return null;
    return mask.of(token) ?? token.lexeme;
  }

  /// Counts lines in [content].
  int _lineCount(String content) {
    if (content.isEmpty) return 0;
    final newlines = '\n'.allMatches(content).length;
    return content.endsWith('\n') ? newlines : newlines + 1;
  }
}

/// One accepted clone group: non-overlapping occurrences of the same
/// token block, each as a [startToken, endToken) range of its file.
class _CloneGroup {
  /// Creates a [_CloneGroup].
  _CloneGroup(this.occurrences);

  /// The occurrences of the block.
  final List<_CloneOccurrence> occurrences;

  /// Token count shared by every occurrence.
  int get tokenCount =>
      occurrences.first.endToken - occurrences.first.startToken;
}

/// A single occurrence of a [_CloneGroup].
class _CloneOccurrence {
  /// Creates a [_CloneOccurrence].
  _CloneOccurrence(this.fileIndex, this.startToken, this.endToken);

  /// Index into the file list of this run.
  final int fileIndex;

  /// First token of the occurrence (inclusive).
  final int startToken;

  /// End token of the occurrence (exclusive).
  final int endToken;
}

/// Intermediate result of [_buildResult].
class _Result {
  /// Creates a [_Result].
  _Result(this.violations, this.summary);

  final List<GateViolation> violations;
  final String summary;
}
