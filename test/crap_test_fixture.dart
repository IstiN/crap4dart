import 'dart:io';

import 'package:path/path.dart' as p;

/// Creates a temp directory for CRAP analyzer tests.
Directory createCrapTestProject() =>
    Directory.systemTemp.createTempSync('crap4dart_test_');

/// Writes the shared mini project: lib/sample.dart with an `uncovered`
/// (CC 2, 0% covered) and a `covered` (CC 1, 100% covered) function plus
/// the matching coverage/lcov.info.
void writeSampleProject(Directory root) {
  Directory(p.join(root.path, 'lib')).createSync();
  Directory(p.join(root.path, 'coverage')).createSync();
  File(p.join(root.path, 'lib', 'sample.dart')).writeAsStringSync('''
int uncovered(int x) {
  if (x > 0) {
    return x;
  } else {
    return -x;
  }
}

int covered(int x) {
  return x + 1;
}
''');
  File(p.join(root.path, 'coverage', 'lcov.info')).writeAsStringSync('''
SF:lib/sample.dart
DA:1,0
DA:2,0
DA:3,0
DA:5,0
DA:9,1
DA:10,1
BRDA:2,0,0,1
BRDA:2,0,1,0
end_of_record
''');
}

/// Path of the fixture sample file inside [root].
String sampleFile(Directory root) => p.join(root.path, 'lib', 'sample.dart');

/// Path of the fixture LCOV file inside [root].
String sampleLcov(Directory root) => p.join(root.path, 'coverage', 'lcov.info');
