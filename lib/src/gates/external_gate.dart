import 'dart:io';

import 'package:xml/xml.dart';

import '../config/config.dart';
import 'gate.dart';
import 'gate_context.dart';

/// The `external` gate: wraps external static-analysis tools (detekt,
/// ktlint, swiftlint, ...) behind one config. Each rule runs an
/// executable, then parses its Checkstyle XML report into standard
/// [GateViolation]s — so severity, baseline, ignore markers and the
/// diff mode all work on top of the wrapped tool.
class ExternalGate implements Gate {
  /// Creates an [ExternalGate].
  const ExternalGate();

  @override
  String get id => 'external';

  @override
  Future<GateResult> run(GateContext context) async {
    final rules = context.config.gates.external.rules;
    if (rules.isEmpty) {
      return GateResult.pass(id, summary: 'no tools configured');
    }
    final violations = <GateViolation>[];
    var checked = 0;
    for (final rule in rules) {
      checked++;
      violations.addAll(await _runRule(rule, context));
    }
    final summary = violations.isEmpty
        ? '$checked tool(s) clean'
        : '${violations.length} finding(s) from $checked tool(s)';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }

  /// Runs [rule] and returns its parsed violations.
  Future<List<GateViolation>> _runRule(
    ExternalToolRule rule,
    GateContext context,
  ) async {
    final report = File(
      rule.reportPath ??
          '${Directory.systemTemp.createTempSync('crap4dart_ext_').path}'
              '/report.xml',
    );
    final args = [
      for (final argument in rule.arguments)
        argument.replaceAll('{report}', report.path),
    ];
    if (rule.reportPath == null && !args.contains(report.path)) {
      args.add(report.path);
    }
    final result = await Process.run(
      rule.executable,
      args,
      workingDirectory: context.projectRoot,
    );
    if (result.exitCode != 0 && !report.existsSync()) {
      return [
        GateViolation(
          file: '(external)',
          message: '${rule.id} exited with ${result.exitCode} and no '
              'report was produced: ${_trim(result.stderr)}',
        ),
      ];
    }
    return _parseCheckstyle(report, rule.id, context);
  }

  /// Parses a Checkstyle XML [report] into violations.
  List<GateViolation> _parseCheckstyle(
    File report,
    String ruleId,
    GateContext context,
  ) {
    if (!report.existsSync()) return const [];
    final violations = <GateViolation>[];
    final document = XmlDocument.parse(report.readAsStringSync());
    for (final file in document.findAllElements('file')) {
      final path = file.getAttribute('name') ?? '';
      for (final child in file.findElements('error')) {
        final line = int.tryParse(child.getAttribute('line') ?? '');
        violations.add(
          GateViolation(
            file: _relative(path, context),
            line: line,
            message: '${child.getAttribute('message') ?? 'finding'} '
                '[${child.getAttribute('source') ?? ruleId}]',
          ),
        );
      }
    }
    return violations;
  }

  /// [path] made relative to the project root when possible.
  String _relative(String path, GateContext context) =>
      path.startsWith('${context.projectRoot}/')
          ? path.substring(context.projectRoot.length + 1)
          : path;

  String _trim(dynamic output) =>
      output == null ? '' : '$output'.trim().split('\n').first;
}
