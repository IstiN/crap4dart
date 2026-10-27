import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../analysis/dart_parser.dart';
import '../common/constants.dart';
import '../reorder/member_order.dart';
import 'exit_codes.dart';

/// The `reorder` command: rewrites Dart files so class members follow
/// the canonical Dart/Flutter order (constants, static fields, fields,
/// constructors, static methods, getters/setters, public methods,
/// private methods — same-kind members keep their relative order).
///
/// Deterministic: the same input always produces the same output, and
/// already-canonical files are left byte-identical. With `--dry-run`
/// nothing is written; the command lists the files that would change
/// and exits 2 (0 when everything is already canonical).
class ReorderCommand extends Command<int> {
  /// Creates a [ReorderCommand].
  ReorderCommand({this.projectRoot}) {
    argParser.addFlag(
      _dryRun,
      abbr: 'n',
      negatable: false,
      help: 'Show which files would change without writing them. '
          'Exits 2 when any file would change.',
    );
  }

  static const String _dryRun = 'dry-run';

  /// Project root override (default: the current working directory).
  final String? projectRoot;

  @override
  final String name = 'reorder';

  @override
  final String description = 'Reorder class members into the canonical '
      'Dart/Flutter order (deterministic; same-kind order is kept).';

  @override
  Future<int> run() async {
    final root = projectRoot ?? Directory.current.path;
    final dryRun = argResults![_dryRun] as bool;
    final targets = argResults!.rest.isEmpty ? ['lib'] : argResults!.rest;
    final files = _collect(root, targets);
    if (files.isEmpty) {
      stdout.writeln('No Dart files found under: ${targets.join(', ')}');
      return ExitCodes.success;
    }
    final changed = [for (final file in files) _process(file, root, dryRun)]
        .where((c) => c)
        .length;
    if (changed == 0) {
      stdout.writeln('All ${files.length} files already canonical.');
      return ExitCodes.success;
    }
    stdout.writeln(dryRun
        ? '$changed of ${files.length} files would be reordered.'
        : '$changed of ${files.length} files reordered.');
    return dryRun ? ExitCodes.thresholdExceeded : ExitCodes.success;
  }

  List<String> _collect(String root, List<String> targets) {
    final files = <String>[];
    for (final target in targets) {
      final absolute = p.isAbsolute(target) ? target : p.join(root, target);
      final entity = File(absolute);
      if (entity.existsSync()) {
        files.add(absolute);
        continue;
      }
      final dir = Directory(absolute);
      if (!dir.existsSync()) {
        stdout.writeln('skipped (not found): $target');
        continue;
      }
      files.addAll(
        dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith(kDartExtension))
            .map((f) => f.path),
      );
    }
    files.sort();
    return files;
  }

  /// Reorders one file, reporting the outcome; returns whether it
  /// changed.
  bool _process(String file, String root, bool dryRun) {
    final outcome = _reorderFile(file, dryRun);
    switch (outcome) {
      case _ReorderOutcome.changed:
        stdout.writeln('${dryRun ? 'would reorder' : 'reordered'} '
            '${_relative(root, file)}');
      case _ReorderOutcome.parseError:
        stdout.writeln('skipped (parse error): ${_relative(root, file)}');
      case _ReorderOutcome.unchanged:
        break;
    }
    return outcome == _ReorderOutcome.changed;
  }

  _ReorderOutcome _reorderFile(String file, bool dryRun) {
    final original = File(file).readAsStringSync();
    final String reordered;
    try {
      reordered = reorderSource(original, path: file);
    } on DartParseException {
      return _ReorderOutcome.parseError;
    }
    if (reordered == original) return _ReorderOutcome.unchanged;
    if (!dryRun) File(file).writeAsStringSync(reordered);
    return _ReorderOutcome.changed;
  }

  String _relative(String root, String file) {
    final rel = p.relative(file, from: root);
    return rel.startsWith('..') ? file : rel;
  }
}

enum _ReorderOutcome { changed, unchanged, parseError }
