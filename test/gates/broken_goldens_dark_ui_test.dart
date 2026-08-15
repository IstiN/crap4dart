import 'dart:io';

import 'package:crap4dart/src/gates/broken_goldens_gate.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'broken_goldens_gate_test.dart' show writePng;
import 'gate_test_utils.dart';

void main() {
  const gate = BrokenGoldensGate();

  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('dark TUI with yellow text is NOT overflow stripes', () async {
    // A terminal UI: black background, sparse short yellow words
    // (4-5 px each) separated by wide black gaps — matches the real
    // FAH CLI screenshots that false-positived before.
    writePng(project, 'test/screenshots/tui.png', 400, 200, (x, y) {
      bool inWord(int base, int len) => x >= base && x < base + len;
      if (y == 20 && (inWord(30, 5) || inWord(90, 4) || inWord(200, 5))) {
        return _tuiYellow;
      }
      if (y == 21 && (inWord(35, 3) || inWord(150, 4))) {
        return _tuiYellow;
      }
      return _tuiBlack;
    });
    final result = await gate.run(makeContext(project, const []));
    expect(result.passed, isTrue,
        reason: 'sparse yellow-on-black text must not be flagged: '
            '${result.violations}');
  });

  test('a dense diagonal stripe band IS overflow', () async {
    // Continuous checkerboard band across 10 rows — every row crossing
    // it alternates yellow/black pixel by pixel.
    writePng(project, 'test/goldens/overflow.png', 120, 40, (x, y) {
      if (y >= 15 && y < 25) {
        return (x ~/ 4) % 2 == 0 ? _tuiYellow : _tuiBlack;
      }
      return _white;
    });
    final result = await gate.run(makeContext(project, const []));
    expect(result.passed, isFalse);
    expect(result.violations.single.message, contains('overflow stripes'));
  });
}

final img.Color _tuiYellow = img.ColorRgb8(245, 216, 0);
final img.Color _tuiBlack = img.ColorRgb8(0, 0, 0);
final img.Color _white = img.ColorRgb8(255, 255, 255);
