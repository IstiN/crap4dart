import '../gates/gate_ids.dart';
import '../common/constants.dart';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../config/config.dart';
import '../config/config_loader.dart';
import '../similarity/similarity_analyzer.dart';
import 'exit_codes.dart';

/// Root and directory list of one `similarity` invocation.
typedef _ScanTargets = ({String root, List<String> dirs});

/// The `similarity` command: ad-hoc near-duplicate scanning over any
/// text corpus — the exploration tool for tuning the `similarity`
/// gate's thresholds before enabling it.
///
/// Informational: always exits 0; the gate (in `check`) is the
/// enforcer.
class SimilarityCommand extends Command<int> {
  /// Project root override (default: the current working directory).
  final String? projectRoot;

  @override
  final String name = GateIds.similarity;

  @override
  final String description = 'Scan for near-duplicate files (docs, code) '
      'and print the similarity clusters.';

  /// Creates a [SimilarityCommand].
  SimilarityCommand({this.projectRoot}) {
    argParser
      ..addOption(
        kFormat,
        allowed: [kConsole, kJson],
        defaultsTo: kConsole,
        help: 'Output format.',
      )
      ..addOption(
        kJaccard,
        help: 'Jaccard threshold override (0.0-1.0).',
      )
      ..addOption(
        kContainment,
        help: 'Containment threshold override (0.0-1.0).',
      )
      ..addOption(
        _minShinglesOption,
        help: 'Minimum shingles per file (smaller files are skipped).',
      )
      ..addMultiOption(
        kInclude,
        help: 'Glob of files to analyze (repeatable); default: the '
            'config include list (**/*.md).',
      )
      ..addMultiOption(
        kExclude,
        help: 'Glob of files to skip (repeatable); default: the config '
            'exclude list.',
      )
      ..addOption(kConfig, help: kConfigHelp);
  }

  @override
  Future<int> run() async {
    final root = projectRoot ?? Directory.current.path;
    final config = _loadConfig(root);
    if (config == null) return ExitCodes.usageError;
    final similarity = config.gates.similarity;
    final args = argResults!;
    final (root: scanRoot, dirs: dirs) = _scanTargets(root, similarity.dirs);
    final jaccard = _doubleArg(args, kJaccard) ?? similarity.jaccard;
    final containment =
        _doubleArg(args, kContainment) ?? similarity.containment;
    final minShingles =
        _intArg(args, _minShinglesOption) ?? similarity.minShingles;
    final include = (args[kInclude] as List<String>).cast<String>().isNotEmpty
        ? (args[kInclude] as List<String>).cast<String>()
        : similarity.include;
    final exclude = (args[kExclude] as List<String>).cast<String>().isNotEmpty
        ? (args[kExclude] as List<String>).cast<String>()
        : similarity.exclude;
    final report = const SimilarityAnalyzer().analyze(
      Directory(scanRoot),
      dirs: dirs,
      include: include,
      exclude: exclude,
      jaccardThreshold: jaccard,
      containmentThreshold: containment,
      minShingles: minShingles,
    );
    if (args[kFormat] == kJson) {
      _printJson(report, jaccard, containment, minShingles);
    } else {
      _printConsole(report, jaccard, containment, minShingles);
    }
    return ExitCodes.success;
  }

  /// The scan root and directories for this invocation: a single
  /// directory argument becomes the scan root itself, several
  /// arguments are subdirectories of the project root, none uses the
  /// config's `dirs`.
  _ScanTargets _scanTargets(
    String root,
    List<String> configDirs,
  ) {
    final rest = argResults!.rest;
    if (rest.length == 1 && Directory(rest.single).existsSync()) {
      final target = rest.single;
      return (
        root: p.isAbsolute(target) ? target : p.join(root, target),
        dirs: ['.'],
      );
    }
    if (rest.isNotEmpty) return (root: root, dirs: rest);
    return (root: root, dirs: configDirs);
  }

  /// Loads the config, reporting errors to stderr, `null` on failure.
  Crap4DartConfig? _loadConfig(String root) {
    try {
      return const ConfigLoader().load(
        root,
        configPath: argResults![kConfig] as String?,
      );
    } on ConfigException catch (e) {
      stderr.writeln(e);
      return null;
    }
  }

  /// An optional double option value, `null` when absent or invalid
  /// (invalid values are reported to stderr).
  double? _doubleArg(ArgResults args, String name) {
    final raw = args[name];
    if (raw == null) return null;
    final value = double.tryParse(raw as String);
    if (value == null) {
      stderr.writeln('Invalid --$name value: $raw');
    }
    return value;
  }

  /// An optional int option value, `null` when absent or invalid
  /// (invalid values are reported to stderr).
  int? _intArg(ArgResults args, String name) {
    final raw = args[name];
    if (raw == null) return null;
    final value = int.tryParse(raw as String);
    if (value == null) {
      stderr.writeln('Invalid --$name value: $raw');
    }
    return value;
  }

  /// The console report.
  void _printConsole(
    SimilarityReport report,
    double jaccard,
    double containment,
    int minShingles,
  ) {
    stdout.writeln(
      'similarity: ${report.scanned} files scanned '
      '(${report.skipped} skipped below $minShingles shingles), '
      'thresholds jaccard >= $jaccard / containment >= $containment',
    );
    if (report.clean) {
      stdout.writeln('no similar files');
      return;
    }
    for (var i = 0; i < report.clusters.length; i++) {
      final cluster = report.clusters[i];
      stdout.writeln('');
      stdout.writeln('cluster ${i + 1} — ${cluster.files.length} files:');
      for (final file in cluster.files) {
        final metrics = report.metricsFor(file);
        stdout.writeln(
          '  $file '
          '(jaccard ${metrics?.jaccard.toStringAsFixed(2)}, '
          'containment ${metrics?.containment.toStringAsFixed(2)})',
        );
      }
    }
    stdout.writeln('');
    stdout.writeln(
      '${report.clusteredPaths.length} files in '
      '${report.clusters.length} clusters',
    );
  }

  /// The JSON report (stdout stays JSON-only).
  void _printJson(
    SimilarityReport report,
    double jaccard,
    double containment,
    int minShingles,
  ) {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'scanned': report.scanned,
        'skipped': report.skipped,
        'thresholds': {
          'jaccard': jaccard,
          'containment': containment,
          'min_shingles': minShingles,
        },
        'pairs': [
          for (final pair in report.pairs)
            {
              'a': pair.a,
              'b': pair.b,
              'jaccard': double.parse(pair.jaccard.toStringAsFixed(4)),
              'containment': double.parse(pair.containment.toStringAsFixed(4)),
            },
        ],
        'clusters': [
          for (final cluster in report.clusters) {'files': cluster.files},
        ],
      }),
    );
  }
}

const String _minShinglesOption = 'min-shingles';
