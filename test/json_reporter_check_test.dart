import 'dart:convert';

import 'package:crap4dart/src/gates/gate.dart';
import 'package:crap4dart/src/gates/gate_runner.dart';
import 'package:crap4dart/src/report/json_reporter.dart';
import 'package:test/test.dart';

void main() {
  const reporter = JsonReporter();

  group('renderCheck', () {
    test('serializes gate statuses, reasons and violations', () {
      const result = GateRunResult([
        GateResult(
          gateId: 'loc',
          passed: true,
          summary: '10 files within 800 lines',
        ),
        GateResult(
          gateId: 'golden',
          passed: true,
          skipped: true,
          skipReason: 'not a Flutter project',
        ),
        GateResult(
          gateId: 'complexity',
          passed: false,
          summary: '1 violation',
          violations: [
            GateViolation(
              file: 'lib/x.dart',
              line: 10,
              message: 'A.f CC=14 > max 10',
            ),
          ],
        ),
      ]);
      final json =
          jsonDecode(reporter.renderCheck(result)) as Map<String, dynamic>;
      expect(json['command'], 'check');
      expect(json['passed'], isFalse);
      final gates = json['gates'] as List<dynamic>;
      expect(gates, hasLength(3));
      expect(gates[0], {
        'id': 'loc',
        'status': 'passed',
        'summary': '10 files within 800 lines',
        'violations': [],
      });
      expect(gates[1], {
        'id': 'golden',
        'status': 'skipped',
        'reason': 'not a Flutter project',
      });
      final failed = gates[2] as Map<String, dynamic>;
      expect(failed['status'], 'failed');
      expect(failed['violations'], [
        {'file': 'lib/x.dart', 'line': 10, 'message': 'A.f CC=14 > max 10'},
      ]);
    });
  });
}
