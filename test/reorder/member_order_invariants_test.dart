import 'package:crap4dart/src/analysis/dart_parser.dart';
import 'package:crap4dart/src/reorder/member_order.dart';
import 'package:test/test.dart';

import 'reorder_invariants.dart';

/// The consistency battery: for every fixture below the reorder must
/// (1) be idempotent, (2) preserve the token multiset (it moves code,
/// never adds or drops it), and (3) produce a file that parses.
final fixtures = <String, String>{
  'kitchen-sink': '''
/// A documented class.
@Deprecated('eventually')
class Kitchen {
/// The answer.
static const int answer = 42;

// note on state
static int counter = 0;

late final String label;

int width = 0, height = 0;

Kitchen();

Kitchen.named(this.width);

factory Kitchen.square(int side) => Kitchen.named(side);

static Kitchen build() => Kitchen.square(1);

int get area => width * height;

set area(int value) => width = value;

@override
String toString() => 'Kitchen';

void draw() {}

void _drawQuietly() {}
}
''',
  'real-gate-shape': '''
class Gates {
final List<int> limits;

Gates(this.limits);

bool passes(int value) => limits.every((limit) => value <= limit);

static Gates of(List<int> limits) => Gates(limits);

int get worst => limits.isEmpty ? 0 : limits.first;
}
''',
  'single-member': 'class A { int x = 0; }\n',
  'one-line-multi': 'class A { void m() {} int x = 0; }\n',
  'comments-everywhere': '''
// leading file comment
class A {
// one
/// two
int a = 0;

/* block */
void b() {}

void c() {}

// before d
void d() {}
}

// between classes

class B {
void x() {}

int y = 0;
}
''',
  'mixed-order-repeat': '''
class C {
void later() {}

int middle = 0;

static const first = 1;

void _last() {}

String middle2 = 'two';

static int firstStatic = 1;
}
''',
};

void main() {
  for (final entry in fixtures.entries) {
    test('${entry.key}: idempotent, token-preserving, parseable', () {
      final once = reorderSource(entry.value, path: '${entry.key}.dart');
      final twice = reorderSource(once, path: '${entry.key}.dart');
      expect(twice, once, reason: 'idempotence');
      expect(sortedTokens(once).join(' '), sortedTokens(entry.value).join(' '),
          reason: 'token multiset preserved');
      // The output must parse (reorderSource already parsed it, but a
      // direct parse makes the guarantee explicit).
      DartParser().parse(content: once, path: '${entry.key}.dart');
    });
  }
}
