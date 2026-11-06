import 'dart:io';

import 'package:crap4dart/src/gates/content/broken_goldens_gate.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'broken_goldens_gate_test.dart' show writePng;
import 'gate_test_utils.dart';

final img.Color _white = img.ColorRgb8(255, 255, 255);
final img.Color _blue = img.ColorRgb8(40, 100, 220);
final img.Color _gray = img.ColorRgb8(120, 120, 120);

/// Config enabling the opt-in blank-scene detector.
const String _detectBlank = 'gates:\n'
    '  broken_goldens:\n'
    '    detect_blank: true\n';

void main() {
  const gate = BrokenGoldensGate();

  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('blank scenes pass while the detector is opted out', () async {
    writePng(project, 'test/goldens/blank.png', 100, 60, (x, y) => _white);
    final result = await gate.run(makeContext(project, const []));
    expect(result.passed, isTrue);
  });

  test('flags a fully blank golden when detect_blank is on', () async {
    writePng(project, 'test/goldens/blank.png', 100, 60, (x, y) => _white);
    final result = await gate.run(
      makeContext(project, const [], configYaml: _detectBlank),
    );
    expect(result.passed, isFalse);
    expect(result.violations.single.message, contains('blank scene'));
  });

  test('passes a golden with real content', () async {
    // Two distinct surface regions plus detail — dominant bucket stays
    // well below the 0.92 blank threshold.
    writePng(project, 'test/goldens/content.png', 100, 60, (x, y) {
      if (x < 30) return _blue;
      if ((x + y) % 7 == 0) return _gray;
      return _white;
    });
    final result = await gate.run(
      makeContext(project, const [], configYaml: _detectBlank),
    );
    expect(result.passed, isTrue);
    expect(result.violations, isEmpty);
  });

  test('respects a custom blank_ratio', () async {
    // 50/50 split: dominant fraction 0.5. Default 0.92 passes it...
    writePng(project, 'test/goldens/half.png', 100, 60, (x, y) {
      return x < 50 ? _white : _blue;
    });
    final relaxed = await gate.run(
      makeContext(project, const [], configYaml: _detectBlank),
    );
    expect(relaxed.passed, isTrue);
    // ...but a 0.5 threshold flags it as blank.
    final strict = await gate.run(makeContext(
      project,
      const [],
      configYaml: '$_detectBlank'
          '    blank_ratio: 0.5\n',
    ));
    expect(strict.passed, isFalse);
    expect(strict.violations.single.message, contains('blank scene'));
  });

  test('antialiased shades of one surface still count as blank', () async {
    // Near-white gradient: distinct raw colors, one quantized bucket.
    writePng(project, 'test/goldens/shades.png', 100, 60, (x, y) {
      final v = 240 + (x % 10);
      return img.ColorRgb8(v, v, v);
    });
    final result = await gate.run(
      makeContext(project, const [], configYaml: _detectBlank),
    );
    expect(result.passed, isFalse);
    expect(result.violations.single.message, contains('blank scene'));
  });
}
