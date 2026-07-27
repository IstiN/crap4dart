import 'dart:io';

import 'package:crap4dart/src/files/source_finder.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  const finder = SourceFinder();

  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('crap4dart_finder_test_');
    for (final dir in ['lib', 'bin', 'tool']) {
      File(p.join(project.path, dir, 'a.dart')).createSync(recursive: true);
    }
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('defaults to lib and bin', () {
    final files = finder.findDefaultSources(project.path);
    expect(files, hasLength(2));
    expect(files.any((f) => f.contains('tool')), isFalse);
  });

  test('honors the roots parameter and skips missing directories', () {
    final files = finder.findDefaultSources(
      project.path,
      roots: ['lib', 'tool', 'does_not_exist'],
    );
    expect(files, hasLength(2));
    expect(files.any((f) => f.contains(p.join('tool', 'a.dart'))), isTrue);
  });

  test('expandPaths takes files directly and expands directories', () {
    final files = finder.expandPaths([
      p.join(project.path, 'lib', 'a.dart'),
      p.join(project.path, 'tool'),
    ]);
    expect(files, hasLength(2));
    expect(files, contains(p.join(project.path, 'lib', 'a.dart')));
    expect(files, contains(p.join(project.path, 'tool', 'a.dart')));
  });

  test('expandPaths skips non-Dart and excluded files', () {
    File(p.join(project.path, 'lib', 'notes.txt')).createSync();
    File(p.join(project.path, 'lib', 'gen.g.dart')).createSync();
    final files = finder.expandPaths([p.join(project.path, 'lib')]);
    expect(files, [p.join(project.path, 'lib', 'a.dart')]);
  });

  test('expandPaths throws for missing paths', () {
    expect(
      () => finder.expandPaths([p.join(project.path, 'nope')]),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('filterByGlobs drops files matching the exclude globs', () {
    final files = [
      p.join(project.path, 'lib', 'a.dart'),
      p.join(project.path, 'bin', 'a.dart'),
      p.join(project.path, 'tool', 'a.dart'),
    ];
    expect(
      finder.filterByGlobs(project.path, files, ['tool/**', 'bin/*.dart']),
      [p.join(project.path, 'lib', 'a.dart')],
    );
    expect(finder.filterByGlobs(project.path, files, const []), files);
  });
}
