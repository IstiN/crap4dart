import 'dart:io';

import 'package:path/path.dart' as p;

/// Added/changed lines of the new file versions in a git diff.
///
/// Keys are project-relative paths of new file versions; values are the
/// 1-based line numbers added or changed in the diff. A file present with
/// an empty set had only deletions (no line of it counts as changed).
/// Deleted files are absent.
class DiffLineMap {
  /// Creates a [DiffLineMap].
  DiffLineMap({required this.projectRoot, required this.addedLines});

  /// Project root the diff paths are relative to.
  final String projectRoot;

  /// Project-relative new path → set of added/changed line numbers.
  final Map<String, Set<int>> addedLines;

  /// Added/changed lines of [file] (absolute or project-relative), or an
  /// empty set when the file is not in the diff.
  Set<int> linesFor(String file) =>
      addedLines[_relative(file)] ?? const <int>{};

  /// Whether [file] has at least one added/changed line.
  bool hasRealChanges(String file) => linesFor(file).isNotEmpty;

  /// Whether the [start]–[end] line range of [file] intersects the
  /// added/changed lines (used to select methods touched by the diff).
  bool intersects(String file, int start, int end) {
    final lines = linesFor(file);
    if (lines.isEmpty) return false;
    for (final line in lines) {
      if (line >= start && line <= end) return true;
    }
    return false;
  }

  /// Project-relative paths of files in the diff that exist on disk.
  List<String> existingFiles() => [
        for (final file in addedLines.keys)
          if (File(p.join(projectRoot, file)).existsSync()) file,
      ];

  String _relative(String file) =>
      p.isAbsolute(file) ? p.relative(file, from: projectRoot) : file;
}

/// Runs and parses `git diff --unified=0` for Dart files.
class GitDiffParser {
  /// Creates a [GitDiffParser].
  const GitDiffParser();

  /// Runs `git diff --unified=0 <base> -- '*.dart'` in [projectRoot] and
  /// parses the result. Throws a [ProcessException] when git fails (e.g.
  /// not a git repository or an unknown ref).
  Future<DiffLineMap> diff(String projectRoot, {String base = 'HEAD'}) async {
    final result = await Process.run(
      'git',
      ['diff', '--unified=0', base, '--', '*.dart'],
      workingDirectory: projectRoot,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        'git',
        ['diff', base],
        '${result.stderr}'.trim(),
        result.exitCode,
      );
    }
    return parse(projectRoot, '${result.stdout}');
  }

  /// Parses unified diff [output] (with `--unified=0` hunks) into a
  /// [DiffLineMap].
  DiffLineMap parse(String projectRoot, String output) {
    final added = <String, Set<int>>{};
    String? current;
    for (final line in output.split('\n')) {
      if (line.startsWith('+++ ')) {
        current = _parseNewPath(line.substring(4).trim());
      } else if (line.startsWith('@@ ')) {
        _parseHunk(line, current, added);
      }
    }
    return DiffLineMap(projectRoot: projectRoot, addedLines: added);
  }

  String? _parseNewPath(String header) {
    if (header == '/dev/null') return null; // deleted file
    return header.startsWith('b/') ? header.substring(2) : header;
  }

  void _parseHunk(String line, String? current, Map<String, Set<int>> added) {
    if (current == null) return;
    final match =
        RegExp(r'@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@').firstMatch(line);
    if (match == null) return;
    final start = int.parse(match.group(1)!);
    final count = match.group(2) == null ? 1 : int.parse(match.group(2)!);
    final lines = added.putIfAbsent(current, () => <int>{});
    for (var i = 0; i < count; i++) {
      lines.add(start + i);
    }
  }
}
