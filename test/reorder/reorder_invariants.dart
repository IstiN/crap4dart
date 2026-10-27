import 'package:analyzer/dart/ast/token.dart';
import 'package:crap4dart/src/analysis/dart_parser.dart';
import 'package:crap4dart/src/reorder/member_order.dart';
import 'package:test/test.dart';

/// Sorted token stream of [code] — the reorder transform must preserve
/// it exactly (it moves tokens, never adds or drops them).
List<String> sortedTokens(String code) {
  final unit = DartParser().parse(content: code, path: 'b.dart').unit;
  final out = <String>[];
  Token? t = unit.beginToken;
  while (t != null) {
    Token? c = t.precedingComments;
    while (c != null) {
      out.add(c.lexeme);
      c = c.next;
    }
    out.add(t.lexeme);
    if (t == unit.endToken) break;
    t = t.next;
  }
  out.sort();
  return out;
}

/// Asserts the full consistency contract for [src].
void expectConsistent(String src) {
  final once = reorderSource(src, path: 'fixture.dart');
  final twice = reorderSource(once, path: 'fixture.dart');
  expect(twice, once, reason: 'must be idempotent');
  expect(sortedTokens(once).join(' '), sortedTokens(src).join(' '),
      reason: 'token multiset must be preserved');
}
