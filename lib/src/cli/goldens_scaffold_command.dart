import 'dart:io';

import 'package:path/path.dart' as p;

import '../goldens/golden_scaffold_templates.dart';
import 'exit_codes.dart';

/// The writer behind `crap4dart goldens --scaffold`: generates the
/// visual-regression scene harness into the target Flutter project —
/// an app wrapper that installs scopes at `MaterialApp.builder` (above
/// the Navigator), a phone/desktop × light/dark pump helper, an
/// example scene with a scrolled variant, a scoped `update_goldens.sh`
/// and a montage generator for the pixel-review step.
class GoldenScaffoldWriter {
  /// Project root override (default: the current working directory).
  final String projectRoot;

  /// Creates a [GoldenScaffoldWriter] for [projectRoot].
  const GoldenScaffoldWriter({required this.projectRoot});

  static const Map<String, String> _files = {
    'golden_scaffold_helper.dart': goldenScaffoldHelper,
    'scenes/example_scene_golden_test.dart': goldenScaffoldExampleScene,
    'update_goldens.sh': goldenScaffoldUpdateScript,
    'montage.dart': goldenScaffoldMontage,
    'goldens/README.md': goldenScaffoldReadme,
  };

  /// Generates the harness under [dir] (relative to the project
  /// root). Refuses to overwrite existing files unless [force];
  /// [dryRun] lists what would be written. Returns the exit code.
  Future<int> write({
    required String dir,
    required bool force,
    required bool dryRun,
  }) async {
    final written = <String>[];
    final skipped = <String>[];
    for (final entry in _files.entries) {
      final relative = p.join(dir, entry.key);
      final result = _write(projectRoot, relative, entry.value, force, dryRun);
      (result == null ? skipped : written).add(relative);
    }
    _report(written, skipped, dryRun);
    if (written.isEmpty) {
      return ExitCodes.usageError;
    }
    if (!dryRun) {
      await _finalize(dir);
    }
    return ExitCodes.success;
  }

  /// Prints the per-file outcome lines.
  void _report(List<String> written, List<String> skipped, bool dryRun) {
    for (final path in written) {
      stdout.writeln('${dryRun ? 'would write' : 'written'}: $path');
    }
    for (final path in skipped) {
      stderr.writeln('$path already exists (use --force to overwrite)');
    }
  }

  /// Post-write setup: the update script must be executable for the
  /// documented `sh test/golden/update_goldens.sh` flow, and the
  /// goldens directory must exist so first snapshots land in it.
  Future<void> _finalize(String dir) async {
    final script = p.join(projectRoot, dir, 'update_goldens.sh');
    if (File(script).existsSync()) {
      await Process.run('chmod', ['+x', script]);
    }
    Directory(p.join(projectRoot, dir, 'goldens')).createSync(recursive: true);
    stdout.writeln('\nNext: implement the example scene fixtures '
        '(in-memory, no network), then run');
    stdout.writeln('  sh $dir/update_goldens.sh '
        'example_scene_golden_test.dart');
  }

  String? _write(
    String root,
    String relativePath,
    String content,
    bool force,
    bool dryRun,
  ) {
    final file = File(p.join(root, relativePath));
    if (file.existsSync() && !force) return null;
    if (dryRun) return relativePath;
    file.createSync(recursive: true);
    file.writeAsStringSync(_trimLeadingBlank(content));
    return relativePath;
  }

  /// The raw-string templates start with a newline after `r'''`;
  /// strip it so generated files begin at column one.
  String _trimLeadingBlank(String content) =>
      content.startsWith('\n') ? content.substring(1) : content;
}
