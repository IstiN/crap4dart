import 'dart:math' as math;

import 'package:image/image.dart' as img;

part 'tofu_detector_cross.dart';
part 'tofu_detector_boxes.dart';

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
  static List<(int, int)> inkBands(
    img.Image image,
    int row,
    int runStart,
    int runWidth,
    int background,
  ) {
    final bands = <(int, int)>[];
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
      bands.add((start, x));
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
