import 'package:crap4dart/src/coverage/lcov_parser.dart';
import 'package:test/test.dart';

void main() {
  group('LcovParser', () {
    const fixture = '''
TN:
SF:lib/src/foo.dart
DA:1,1
DA:2,0
DA:4,3
BRDA:2,0,0,1
BRDA:2,0,1,-
BRDA:4,1,0,0
FN:1,foo
FNDA:1,foo
LH:2
LF:3
end_of_record
SF:lib/src/bar.dart
DA:10,5
end_of_record
''';

    test('parses SF/DA/BRDA and ignores other records', () {
      final files = const LcovParser().parse(fixture);
      expect(files, hasLength(2));

      final foo = files[0];
      expect(foo.path, 'lib/src/foo.dart');
      expect(foo.lineHits, {1: 1, 2: 0, 4: 3});
      expect(foo.branches, hasLength(3));
      expect(foo.branches[0].line, 2);
      expect(foo.branches[0].isCovered, isTrue);
      expect(foo.branches[1].taken, isNull);
      expect(foo.branches[1].isCovered, isFalse);
      expect(foo.branches[2].isCovered, isFalse);

      final bar = files[1];
      expect(bar.path, 'lib/src/bar.dart');
      expect(bar.lineHits, {10: 5});
      expect(bar.branches, isEmpty);
    });

    test('returns empty list for empty content', () {
      expect(const LcovParser().parse(''), isEmpty);
    });

    test('tolerates malformed records', () {
      final files = const LcovParser().parse('''
SF:lib/a.dart
DA:1
DA:x,y
BRDA:1,0
BRDA:2,0,0,7
end_of_record
''');
      expect(files.single.lineHits, isEmpty);
      expect(files.single.branches, hasLength(1));
      expect(files.single.branches.single.taken, 7);
    });

    test('relativizes absolute paths against the project root', () {
      final files = const LcovParser(projectRoot: '/repo')
          .parse('SF:/repo/lib/a.dart\nDA:1,1\nend_of_record\n');
      expect(files.single.path, 'lib/a.dart');
    });
  });
}
