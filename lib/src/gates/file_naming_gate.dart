import 'package:path/path.dart' as p;

import '../config/config.dart';
import 'gate.dart';
import 'gate_context.dart';

/// The `file_naming` gate: flags mechanical file names produced by
/// splitting code without a domain boundary — numeric suffixes
/// (`jira_batch1.dart`, `report2.dart`) and generic dumping-ground
/// names (`utils.dart`, `helpers.dart`).
class FileNamingGate implements Gate {
  /// Creates a [FileNamingGate].
  const FileNamingGate();

  /// Lower-cased generic stems with no domain meaning. Files with these
  /// names accumulate unrelated declarations over time.
  static const Set<String> _genericStems = {
    'common',
    'core',
    'general',
    'helper',
    'helpers',
    'misc',
    'shared',
    'stuff',
    'temp',
    'tmp',
    'types',
    'util',
    'utils',
    'utilities',
    'utility',
    'various',
  };

  @override
  String get id => 'file_naming';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.fileNaming;
    final allowed = {
      ...FileNamingGateConfig.defaultAllowedStems.map((s) => s.toLowerCase()),
      ...config.allow.map((s) => s.toLowerCase()),
    };
    final violations = <GateViolation>[];
    var checked = 0;
    for (final file in context.files) {
      if (p.extension(file) != '.dart') continue;
      if (context.matchesAnyGlob(file, config.exclude)) continue;
      checked++;
      final message = _violationFor(file, allowed);
      if (message != null) {
        violations.add(
          GateViolation(file: context.relativePath(file), message: message),
        );
      }
    }
    final summary = violations.isEmpty
        ? '$checked files have domain-meaningful names'
        : '${violations.length}/$checked files with mechanical names';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }

  /// Returns a violation message for [file], or `null` when the name is
  /// acceptable. [allowed] holds lower-cased stems permitted to end in
  /// digits.
  String? _violationFor(String file, Set<String> allowed) {
    final stem = p.basenameWithoutExtension(file);
    final lower = stem.toLowerCase();
    if (_genericStems.contains(lower)) {
      return 'generic name "$stem.dart" — split by domain instead of '
          'accumulating unrelated declarations';
    }
    if (_hasVersionSuffix(lower) && !allowed.contains(lower)) {
      return 'numeric suffix in "$stem.dart" — split by domain instead of '
          'numbered parts (batch1, part2, v2 ...)';
    }
    return null;
  }

  /// Whether the stem ends in digits preceded by a letter or underscore,
  /// as in `jira_batch1`, `report2`, `day_1` or `configv3`.
  bool _hasVersionSuffix(String lower) {
    final match = RegExp(r'[a-z_][0-9]+$').firstMatch(lower);
    return match != null;
  }
}
