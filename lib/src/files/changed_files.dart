import 'dart:io';

/// Discovers changed Dart files from the git working tree.
class ChangedFilesFinder {
  /// Creates a [ChangedFilesFinder].
  const ChangedFilesFinder();

  /// Returns changed `.dart` files (modified, added, untracked, renamed)
  /// relative to the repository at [rootDir], sorted in path order.
  ///
  /// When [staged] is true, only staged changes are considered
  /// (`git diff --cached`); otherwise `git status --porcelain` is used.
  Future<List<String>> find(String rootDir, {bool staged = false}) async {
    final result = await Process.run(
      'git',
      staged
          ? const ['diff', '--cached', '--name-only', '--diff-filter=ACM']
          : const ['status', '--porcelain'],
      workingDirectory: rootDir,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        'git',
        const ['status'],
        '${result.stderr}'.trim(),
        result.exitCode,
      );
    }
    final paths = staged
        ? _parseNameOnly('${result.stdout}')
        : _parsePorcelain('${result.stdout}');
    final dartFiles = paths.where((p) => p.endsWith('.dart')).toSet().toList()
      ..sort();
    return dartFiles;
  }

  List<String> _parseNameOnly(String output) => [
        for (final line in output.split('\n'))
          if (line.trim().isNotEmpty) line.trim(),
      ];

  List<String> _parsePorcelain(String output) {
    final paths = <String>[];
    for (final line in output.split('\n')) {
      if (line.length < 4) continue;
      var path = line.substring(3).trim();
      // Renames/copies are reported as "old -> new"; keep the new path.
      final arrow = path.indexOf(' -> ');
      if (arrow >= 0) path = path.substring(arrow + 4);
      paths.add(_unquote(path));
    }
    return paths;
  }

  String _unquote(String path) {
    if (path.length >= 2 && path.startsWith('"') && path.endsWith('"')) {
      return path.substring(1, path.length - 1);
    }
    return path;
  }
}
