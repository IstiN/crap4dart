import 'dart:math' as math;

import 'package:image/image.dart' as img;

part 'tofu_detector_cross.dart';

part 'tofu_detector_boxes.dart';

/// A horizontal ink span inside one row: inclusive start, exclusive
/// end column.
typedef _Span = ({int start, int end});

/// Clamped pixel scan bounds of a ring: inclusive (x0, y0) to
/// (x1, y1).
typedef _RingBounds = ({int x0, int y0, int x1, int y1});

/// A rectangle's vertical extent: first and last row.
typedef _Vertical = ({int top, int bottom});

/// Detects broken text/icon placeholders in golden images, by shape:
///
/// - icon tofu: a bordered square whose diagonals converge, MERGE and
///   diverge again (Flutter's default render for a failed image/icon
///   load). A checkmark V converges to its vertex and never
///   re-diverges, so tiles with checkmarks pass.
/// - hollow icon boxes: a bordered square with continuous walls and
///   an empty interior (what an unloaded icon font really draws).
/// - solid glyph runs: same-height solid rectangles side by side with
///   small gaps (Ahem fallback text — a font that failed to load).
///
/// Ink is relative to the image's dominant background color, so both
/// light-on-dark and dark-on-light UIs work.
class TofuDetector {
  /// Creates a [TofuDetector].
  const TofuDetector();

  /// Whether the image contains tofu icon placeholders: a bordered
  /// square with a diagonal cross (Flutter's default render for a
  /// failed image/icon load).
  bool hasTofuIcons(img.Image image) => const _XCrossScanner().scan(image);

  /// Whether the image contains hollow icon boxes: square-ish bordered
  /// boxes with continuous walls and an empty interior — the glyph is
  /// missing but the placeholder box is painted, with no diagonal.
  bool hasHollowIconBoxes(img.Image image) =>
      const _HollowBoxScanner().scan(image);

  /// Whether the image contains runs of solid glyph rectangles (Ahem
  /// fallback text): at least two DISTINCT solid rectangles of the
  /// same vertical extent, side by side with a small gap.
  bool hasSolidGlyphRuns(img.Image image) =>
      const _SolidGlyphScanner().scan(image);

  /// Whether the box opening at row [y] floats on the background and
  /// its top border row is solid ink: the row above the border is
  /// background (a filled button's ink continues) and the border run
  /// itself is (nearly) fully ink (a text glyph's top is patchy).
  static bool opensOnBackground(
    img.Image image,
    int y,
    int runStart,
    int runWidth,
    int background,
  ) {
    if (y < 2) return false;
    if (inkRatio(image, y - 2, runStart, runWidth, background) > 0.2) {
      return false;
    }
    if (inkRatio(image, y, runStart, runWidth, background) < 0.85) {
      return false;
    }
    return true;
  }

  /// Whether the 2px ring just OUTSIDE the [runWidth] box opening at
  /// row [y] is (nearly) pure background. A real placeholder floats
  /// alone; a legitimate icon's inner panel (the copy icon's front
  /// rectangle) has the rest of the glyph crossing its ring.
  static bool ringIsolated(
    img.Image image,
    int y,
    int runStart,
    int runWidth,
    int background,
  ) {
    final ring = _ringBounds(image, y, runStart, runWidth);
    if (ring == null) return false;
    var ink = 0;
    var total = 0;
    for (var ry = ring.y0; ry <= ring.y1; ry++) {
      for (var rx = ring.x0; rx <= ring.x1; rx++) {
        if (_inBox(rx, ry, y, runStart, runWidth)) continue;
        total++;
        if (_isInk(image.getPixel(rx, ry), background)) ink++;
      }
    }
    if (total == 0) return false;
    return ink / total <= 0.08;
  }

  /// The ring's clamped scan bounds: (x0, y0, x1, y1), or `null` when
  /// the ring is fully outside the image.
  static _RingBounds? _ringBounds(
    img.Image image,
    int y,
    int runStart,
    int runWidth,
  ) {
    const ring = 2;
    final x0 = (runStart - ring).clamp(0, image.width - 1);
    final x1 = (runStart + runWidth + ring).clamp(0, image.width - 1);
    final y0 = (y - ring).clamp(0, image.height - 1);
    final y1 = (y + runWidth + ring).clamp(0, image.height - 1);
    if (y1 < y0 || x1 < x0) return null;
    return (x0: x0, y0: y0, x1: x1, y1: y1);
  }

  /// Whether (x, y) lies inside the box body (ring scan skips these).
  static bool _inBox(int x, int y, int boxY, int runStart, int runWidth) =>
      y >= boxY &&
      y < boxY + runWidth &&
      x >= runStart &&
      x < runStart + runWidth;

  /// The share of ink in the [d]x[d] block at (x, y).
  static double blockInkRatio(
    img.Image image,
    int x,
    int y,
    int d,
    int background,
  ) {
    var ink = 0;
    for (var dy = 0; dy < d; dy++) {
      for (var dx = 0; dx < d; dx++) {
        if (_isInk(image.getPixel(x + dx, y + dy), background)) ink++;
      }
    }
    return ink / (d * d);
  }

  /// Whether the box/rectangle opening at row [y] has SQUARE corners:
  /// all four [d]x[d] corner blocks carry at least [minRatio] ink.
  /// Real placeholder glyphs (.notdef boxes, Ahem text blocks) are
  /// square-cornered; legitimate UI squares (checkboxes, pagination
  /// dots, icon panels) are rounded and lose their corner pixels.
  static bool hasSquareCorners(
    img.Image image,
    int y,
    int runStart,
    int runWidth,
    int height,
    int background, {
    int d = 3,
    double minRatio = 0.5,
  }) {
    final x1 = runStart + runWidth - d;
    final y1 = y + height - d;
    if (x1 < runStart || y1 < y) return false;
    if (y1 + d > image.height || x1 + d > image.width) return false;
    return blockInkRatio(image, runStart, y, d, background) >= minRatio &&
        blockInkRatio(image, x1, y, d, background) >= minRatio &&
        blockInkRatio(image, runStart, y1, d, background) >= minRatio &&
        blockInkRatio(image, x1, y1, d, background) >= minRatio;
  }

  /// Scans rows top-to-bottom over icon-sized ink runs; `true` on the
  /// first row whose run satisfies [matches] (the per-shape check).
  static bool scanRowsForBox(
    img.Image image,
    int background, {
    int minIcon = 0,
    int maxIcon = 1 << 30,
    int firstRow = 0,
    required bool Function(int y, int runStart, int runWidth) matches,
  }) {
    for (var y = firstRow; y < image.height; y++) {
      var hit = false;
      forEachInkRun(image, y, background, (start, width) {
        if (hit || width < minIcon || width > maxIcon) return;
        if (matches(y, start, width)) hit = true;
      });
      if (hit) return true;
    }
    return false;
  }

  /// Visits every maximal ink run of row [y].
  static void forEachInkRun(
    img.Image image,
    int y,
    int background,
    void Function(int runStart, int runWidth) visit,
  ) {
    var x = 0;
    while (x < image.width) {
      if (!_isInk(image.getPixel(x, y), background)) {
        x++;
        continue;
      }
      final runStart = x;
      while (x < image.width && _isInk(image.getPixel(x, y), background)) {
        x++;
      }
      visit(runStart, x - runStart);
    }
  }

  /// The share of ink pixels in row [row] within the horizontal range.
  static double inkRatio(
    img.Image image,
    int row,
    int runStart,
    int runWidth,
    int background,
  ) {
    var ink = 0;
    for (var x = runStart; x < runStart + runWidth; x++) {
      if (_isInk(image.getPixel(x, row), background)) ink++;
    }
    return ink / runWidth;
  }

  /// The ink bands inside [runStart, runStart+runWidth) at row [row]:
  /// contiguous ink segments separated by background.
  static List<_Span> _inkBands(
    img.Image image,
    int row,
    int runStart,
    int runWidth,
    int background,
  ) {
    final bands = <_Span>[];
    var x = runStart;
    while (x < runStart + runWidth) {
      if (!_isInk(image.getPixel(x, row), background)) {
        x++;
        continue;
      }
      final start = x;
      while (x < runStart + runWidth &&
          _isInk(image.getPixel(x, row), background)) {
        x++;
      }
      bands.add((start: start, end: x));
    }
    return bands;
  }

  /// The dominant background luma of the image (histogram mode over a
  /// strided sample).
  static int dominantBackground(img.Image image) {
    final histogram = List<int>.filled(256, 0);
    var sampled = 0;
    for (final pixel in image) {
      if (sampled++ % 7 != 0) continue;
      final v = _luma(pixel);
      histogram[v]++;
    }
    var best = 0;
    var bestCount = -1;
    for (var i = 0; i < 256; i++) {
      if (histogram[i] > bestCount) {
        bestCount = histogram[i];
        best = i;
      }
    }
    return best;
  }

  /// The pixel's luma.
  static int _luma(img.Pixel pixel) =>
      ((pixel.r + pixel.g + pixel.b) / 3).round();

  /// Whether the pixel is "ink" — far from the dominant background
  /// luma (the tofu strokes differ sharply from their surroundings).
  static bool _isInk(img.Pixel pixel, int background) {
    // Tofu strokes are high-contrast outlines (light gray on dark
    // themes, near-black on light ones); filled buttons and muted UI
    // grays sit far closer to the background and must not match.
    return (_luma(pixel) - background).abs() > 100;
  }
}
