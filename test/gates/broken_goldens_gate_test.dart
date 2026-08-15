import 'dart:io';

import 'package:crap4dart/src/gates/broken_goldens_gate.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'gate_test_utils.dart';

/// Writes a PNG of [width]x[height], filling pixels via [colorAt].
File writePng(
  Directory root,
  String relative,
  int width,
  int height,
  img.Color Function(int x, int y) colorAt,
) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixel(x, y, colorAt(x, y));
    }
  }
  final file = File('${root.path}/$relative')..createSync(recursive: true);
  file.writeAsBytesSync(img.encodePng(image));
  return file;
}

final img.Color _yellow = img.ColorRgb8(245, 216, 0);
final img.Color _black = img.ColorRgb8(0, 0, 0);
final img.Color _white = img.ColorRgb8(255, 255, 255);
final img.Color _errorRed = img.ColorRgb8(144, 0, 0);

void main() {
  const gate = BrokenGoldensGate();

  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('flags a golden with overflow stripes', () async {
    // Checkerboard yellow/black stripe band across the middle.
    writePng(project, 'test/goldens/overflow.png', 100, 60, (x, y) {
      if (y >= 25 && y < 35) {
        return (x ~/ 4) % 2 == 0 ? _yellow : _black;
      }
      return _white;
    });
    final result = await gate.run(makeContext(project, const []));
    expect(result.passed, isFalse);
    expect(result.violations.single.file, 'test/goldens/overflow.png');
    expect(result.violations.single.message, contains('overflow stripes'));
  });

  test('flags a golden with the red error screen', () async {
    // Dark red fill (ErrorWidget background).
    writePng(project, 'test/goldens/error.png', 100, 100, (x, y) => _errorRed);
    final result = await gate.run(makeContext(project, const []));
    expect(result.passed, isFalse);
    expect(result.violations.single.message, contains('build-error screen'));
  });

  test('passes clean goldens and ignores non-PNG files', () async {
    writePng(project, 'test/goldens/clean.png', 100, 100, (x, y) => _white);
    File('${project.path}/test/goldens/notes.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('not a golden');
    final result = await gate.run(makeContext(project, const []));
    expect(result.passed, isTrue, reason: '${result.violations}');
    expect(result.summary, contains('1 golden images clean'));
  });

  test('honors the exclude globs', () async {
    writePng(project, 'test/goldens/reference.png', 100, 60, (x, y) {
      if (y >= 25 && y < 35) {
        return (x ~/ 4) % 2 == 0 ? _yellow : _black;
      }
      return _white;
    });
    final result = await gate.run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n  broken_goldens:\n    exclude:\n'
            "      - 'test/goldens/reference.png'\n",
      ),
    );
    expect(result.passed, isTrue);
  });
}
