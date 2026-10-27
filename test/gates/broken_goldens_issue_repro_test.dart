import 'dart:io';
import 'dart:math' as math;

import 'package:crap4dart/src/gates/content/broken_goldens_gate.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'broken_goldens_gate_test.dart' show writePng;
import 'gate_test_utils.dart';

/// Pixel repro fixtures pinned by flutter_agent_harness
/// `scripts/check_golden_detector.py` (issues #3 and #4): two blind
/// spots that must now be flagged, two false positives that must pass,
/// and two regression guards that must stay flagged.
void main() {
  const gate = BrokenGoldensGate();
  late Directory project;
  setUp(() => project = createTempProject());
  tearDown(() => project.deleteSync(recursive: true));

  for (final (name, painter, expected) in _cases) {
    test('issue repro: $name', () async {
      final grid = Grid(64, _white);
      painter(grid);
      writePng(project, 'test/goldens/$name.png', 64, 64, (x, y) {
        final c = grid.at(x, y);
        return img.ColorRgb8(c[0], c[1], c[2]);
      });
      final result = await gate.run(makeContext(project, const []));
      final message =
          result.violations.isEmpty ? null : result.violations.first.message;
      expect(message, expected == null ? isNull : contains(expected),
          reason: name);
    });
  }
}

const _white = [255, 255, 255];
const _ink = [10, 10, 10];
const _green = [76, 175, 80];
const _yellow = [255, 193, 7];
const _dark = [30, 30, 30];

/// The six pinned classes: painter + expected message substring
/// (`null` = the gate must pass the golden as clean).
final List<(String, void Function(Grid), String?)> _cases = [
  ('ahem_solid_text_rects', _paintAhemWord, 'solid glyph rectangles'),
  ('hollow_icon_square_no_x', _paintHollowSquare, 'hollow icon box'),
  ('x_boxed_icon_tofu', _paintXTofu, 'box with an X'),
  ('overflow_stripes', _paintOverflowStripes, 'overflow stripes'),
  ('checkmark_tile_light', _paintCheckmarkTile, null),
  ('yellow_digits_on_dark', _paintYellowOnDark, null),
];

/// Three 12x14 solid glyph blocks with 3px gaps — pre-font golden text.
void _paintAhemWord(Grid g) {
  for (var i = 0; i < 3; i++) {
    g.rect(8 + i * 15, 20, 19 + i * 15, 33, _ink);
  }
}

/// 24x24 bordered box with 2px walls and NO diagonal — an unloaded
/// icon font's real placeholder.
void _paintHollowSquare(Grid g) {
  g.rect(20, 20, 43, 21, _ink);
  g.rect(20, 42, 43, 43, _ink);
  g.rect(20, 20, 21, 43, _ink);
  g.rect(42, 20, 43, 43, _ink);
}

/// The true tofu: hollow square plus a corner-to-corner X.
void _paintXTofu(Grid g) {
  _paintHollowSquare(g);
  g.line(21, 21, 42, 42, _ink);
  g.line(42, 21, 21, 42, _ink);
}

/// Flutter's overflow pattern: 45-degree yellow/black checkerboard.
void _paintOverflowStripes(Grid g) {
  for (var y = 0; y < g.height; y++) {
    for (var x = 0; x < g.width; x++) {
      g.set(x, y, ((x + y) ~/ 8) % 2 == 0 ? _yellow : _ink);
    }
  }
}

/// Habit Tracker tile: rounded green square with a white V — the
/// false positive that used to read as an X signature.
void _paintCheckmarkTile(Grid g) {
  const t0 = 18, t1 = 45;
  g.rect(t0, t0, t1, t1, _green);
  const cut = 3;
  for (var c = 0; c < cut; c++) {
    final span = cut - c;
    for (var d = 0; d < span; d++) {
      g.set(t0 + c, t0 + d, _white);
      g.set(t0 + c, t1 - d, _white);
      g.set(t1 - c, t0 + d, _white);
      g.set(t1 - c, t1 - d, _white);
    }
  }
  g.line(t0 + 8, t0 + 15, t0 + 13, t0 + 20, _white);
  g.line(t0 + 13, t0 + 20, t0 + 21, t0 + 8, _white);
}

/// Amber "25:00" digits on a dark card: 5 thick yellow bars whose row
/// signatures used to satisfy the stripe heuristic.
void _paintYellowOnDark(Grid g) {
  g.rect(0, 0, 63, 63, _dark);
  for (var i = 0; i < 5; i++) {
    final x0 = 8 + i * 11;
    g.rect(x0, 22, x0 + 3, 41, _yellow);
  }
}

/// A tiny RGB grid canvas the fixture painters draw on.
class Grid {
  /// Grid width in pixels.
  final int width;

  /// Grid height in pixels.
  final int height;

  final List<List<List<int>>> _px;

  /// Creates a [size]x[size] grid filled with [color].
  Grid(int size, List<int> color)
      : width = size,
        height = size,
        _px = List.generate(size, (_) => List.filled(size, color));

  /// The color at (x, y).
  List<int> at(int x, int y) => _px[y][x];

  /// Sets the pixel at (x, y) (silently ignores out-of-bounds).
  void set(int x, int y, List<int> color) {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    _px[y][x] = color;
  }

  /// Fills the inclusive rectangle.
  void rect(int x0, int y0, int x1, int y1, List<int> color) {
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        set(x, y, color);
      }
    }
  }

  /// Draws a thick line (Bresenham + square brush), like the pinned
  /// python fixtures.
  void line(int x0, int y0, int x1, int y1, List<int> color, [int thick = 2]) {
    final dx = (x1 - x0).abs();
    final dy = (y1 - y0).abs();
    final sx = x1 >= x0 ? 1 : -1;
    final sy = y1 >= y0 ? 1 : -1;
    var err = dx - dy;
    var x = x0;
    var y = y0;
    while (true) {
      for (var oy = 0; oy < thick; oy++) {
        for (var ox = 0; ox < thick; ox++) {
          set(math.min(x + ox, width - 1), math.min(y + oy, height - 1), color);
        }
      }
      if (x == x1 && y == y1) break;
      final e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x += sx;
      }
      if (e2 < dx) {
        err += dx;
        y += sy;
      }
    }
  }
}
