import 'dart:io';

import 'package:image/image.dart' as img;

import 'broken_goldens_gate_test.dart' show writePng;

/// Tofu stroke color (light gray, like Flutter's broken-image glyph).
final img.Color tofuStroke = img.ColorRgb8(230, 224, 233);

/// Page background color of the synthetic fixtures.
final img.Color pageBg = img.ColorRgb8(15, 23, 42);

/// Writes a golden with a tofu placeholder at the center: a bordered
/// square whose two diagonals cross in the middle.
void writeTofuGolden(Directory project, String relative) {
  // Precompute the tofu bitmap once; the pixel callback stays trivial
  // (the geometry predicate is complex enough to trip our own gates
  // were it inlined).
  const left = 40, top = 40, right = 80, bottom = 80;
  final grid = List.generate(
    bottom + 1,
    (y) => List.generate(
      right + 1,
      (x) => _tofuPixel(x, y, left, top, right, bottom),
    ),
  );
  writePng(project, relative, 120, 120, (x, y) {
    if (y >= grid.length || x >= grid[y].length) return pageBg;
    return grid[y][x] ? tofuStroke : pageBg;
  });
}

/// Whether pixel (x, y) is part of the tofu shape (border or X).
bool _tofuPixel(int x, int y, int left, int top, int right, int bottom) {
  if (_onTofuBorder(x, y, left, top, right, bottom)) return true;
  final inside = x > left + 2 && x < right - 2 && y > top + 2 && y < bottom - 2;
  if (!inside) return false;
  return _onTofuDiagonal(x - left, y - top, right - left);
}

/// Whether (x, y) lies on the box's border strokes.
bool _onTofuBorder(int x, int y, int left, int top, int right, int bottom) {
  final onTop = x >= left && x < right && (y == top || y == top + 1);
  final onSide = y > top &&
      y < bottom &&
      (x == left || x == left + 1 || x == right - 1 || x == right - 2);
  return onTop || onSide;
}

/// Whether box-relative (dx, dy) lies on one of the X diagonals.
bool _onTofuDiagonal(int dx, int dy, int width) =>
    (dx - dy).abs() <= 1 || (dx + dy - width).abs() <= 1;

/// Writes a golden with a large outlined "0" glyph: walls and a hole,
/// no crossing diagonals — the classic tofu false-positive bait.
void writeOutlinedDigitGolden(Directory project, String relative) {
  writePng(project, relative, 120, 120, (x, y) {
    const left = 40, top = 40, right = 80, bottom = 110;
    final onShape = x >= left &&
        x < right &&
        y >= top &&
        y < bottom &&
        (x < left + 6 || x >= right - 6 || y < top + 6 || y >= bottom - 6);
    return onShape ? tofuStroke : pageBg;
  });
}
