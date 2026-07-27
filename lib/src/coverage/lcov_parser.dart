import 'package:path/path.dart' as p;

/// A single branch coverage data point from a `BRDA` record.
class BranchHit {
  /// Creates a [BranchHit].
  const BranchHit({
    required this.line,
    required this.block,
    required this.branch,
    required this.taken,
  });

  /// Line number of the branch (1-based).
  final int line;

  /// Block identifier from the LCOV record.
  final int block;

  /// Branch identifier from the LCOV record.
  final int branch;

  /// Number of times the branch was taken, or `null` when the LCOV record
  /// reports `-` (not executed instrument).
  final int? taken;

  /// Whether the branch was taken at least once.
  bool get isCovered => taken != null && taken! > 0;
}

/// Coverage data for a single source file.
class FileCoverage {
  /// Creates a [FileCoverage] for [path].
  FileCoverage({required this.path});

  /// Source file path, normalized relative to the project root.
  final String path;

  /// Line hits: line number (1-based) → execution count.
  final Map<int, int> lineHits = {};

  /// Branch hits from `BRDA` records.
  final List<BranchHit> branches = [];
}

/// Parser for LCOV trace files (`lcov.info`).
class LcovParser {
  /// Creates an [LcovParser].
  ///
  /// [projectRoot], when given, is used to strip absolute path prefixes so
  /// that [FileCoverage.path] is relative to the project root.
  const LcovParser({this.projectRoot});

  /// Project root used to relativize absolute `SF` paths.
  final String? projectRoot;

  /// Parses LCOV [content] into a list of [FileCoverage].
  ///
  /// Only `SF`, `DA` and `BRDA` records are interpreted; everything else is
  /// ignored.
  List<FileCoverage> parse(String content) {
    final files = <FileCoverage>[];
    FileCoverage? current;
    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.startsWith('SF:')) {
        current = FileCoverage(path: _normalizePath(line.substring(3)));
        files.add(current);
      } else if (line.startsWith('DA:')) {
        _parseLineHits(line.substring(3), current);
      } else if (line.startsWith('BRDA:')) {
        _parseBranch(line.substring(5), current);
      } else if (line == 'end_of_record') {
        current = null;
      }
    }
    return files;
  }

  void _parseLineHits(String data, FileCoverage? current) {
    if (current == null) return;
    final parts = data.split(',');
    if (parts.length < 2) return;
    final line = int.tryParse(parts[0]);
    final hits = int.tryParse(parts[1]);
    if (line == null || hits == null) return;
    current.lineHits[line] = hits;
  }

  void _parseBranch(String data, FileCoverage? current) {
    if (current == null) return;
    final parts = data.split(',');
    if (parts.length < 4) return;
    final line = int.tryParse(parts[0]);
    final block = int.tryParse(parts[1]);
    final branch = int.tryParse(parts[2]);
    if (line == null || block == null || branch == null) return;
    final taken = parts[3] == '-' ? null : int.tryParse(parts[3]);
    current.branches.add(
      BranchHit(line: line, block: block, branch: branch, taken: taken),
    );
  }

  String _normalizePath(String rawPath) {
    final root = projectRoot;
    var normalized = p.normalize(rawPath);
    if (p.isAbsolute(normalized) && root != null) {
      normalized = p.relative(normalized, from: root);
    }
    return normalized;
  }
}
