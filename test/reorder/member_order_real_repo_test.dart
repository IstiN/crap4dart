import 'dart:io';

import 'package:crap4dart/src/analysis/dart_parser.dart';
import 'package:crap4dart/src/reorder/member_order.dart';
import 'package:test/test.dart';

import 'reorder_invariants.dart';

void main() {
  test('reordering real repository files is safe', () {
    final realFiles = [
      'lib/src/gates/gate.dart',
      'lib/src/cli/exit_codes.dart',
      'lib/src/common/constants.dart',
    ];
    for (final path in realFiles) {
      final src = File(path).readAsStringSync();
      final once = reorderSource(src, path: path);
      expect(reorderSource(once, path: path), once,
          reason: '$path: idempotence');
      expect(sortedTokens(once).join(' '), sortedTokens(src).join(' '),
          reason: '$path: token multiset preserved');
      DartParser().parse(content: once, path: path);
    }
  });
}
