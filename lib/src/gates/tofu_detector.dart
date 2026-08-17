import 'package:image/image.dart' as img;

/// Detects tofu icon placeholders in golden images: a bordered square
/// with a diagonal cross (Flutter's default render for a failed
/// image/icon load), found by shape — solid top border, continuous
/// side walls, and diagonals converging over several rows with real
/// movement (letter glyph arcs collapse once and freeze).
class TofuDetector {
  /// Creates a [TofuDetector].
  const TofuDetector();

  /// Whether the image contains tofu icon placeholders: a bordered
  /// square with a diagonal cross (Flutter's default render for a
  /// failed image/icon load).
  ///
  /// Detection scans rows for the X signature: within a run of
  /// background pixels, a band of "ink" pixels grows from the left
  /// while an identical band shrinks from the right (the two diagonals
  /// of the cross). Ink is relative to the image's dominant background
  /// color, so both light-on-dark and dark-on-light UIs work.
  bool hasTofuIcons(img.Image image) {
    const minIcon = 20; // px — icon-sized; text rows fail the box check
    const maxIcon = 400;
    final background = _dominantBackground(image);
    for (var y = 0; y < image.height; y++) {
      if (_rowHasTofuX(image, y, minIcon, maxIcon, background)) {
        return true;
      }
    }
    return false;
  }

  /// Whether row [y] shows the X signature of a tofu cross between
  /// [minIcon] and [maxIcon] pixels wide.
  bool _rowHasTofuX(
    img.Image image,
    int y,
    int minIcon,
    int maxIcon,
    int background,
  ) {
    final width = image.width;
    var x = 0;
    while (x < width) {
      if (!_isInk(image.getPixel(x, y), background)) {
        x++;
        continue;
      }
      // A run of ink pixels.
      final runStart = x;
      while (x < width && _isInk(image.getPixel(x, y), background)) {
        x++;
      }
      final runLen = x - runStart;
      if (runLen < minIcon || runLen > maxIcon) continue;
      if (_crossConfirmed(image, y, runStart, runLen, background)) {
        return true;
      }
    }
    return false;
  }

  /// Confirms the ink run at row [y] is a tofu cross. The run is the
  /// TOP BORDER of the tofu box: above it is background, below are the
  /// left/right walls with the two X diagonals between them,
  /// converging row over row. Filled buttons and text rows fail either
  /// the clear-above or the walls check.
  bool _crossConfirmed(
    img.Image image,
    int y,
    int runStart,
    int runWidth,
    int background,
  ) {
    // The tofu box floats on the background: the row above the top
    // border must be background (a filled button's ink continues).
    if (y < 2) return false;
    if (_inkRatio(image, y - 2, runStart, runWidth, background) > 0.2) {
      return false;
    }
    // The top border itself is SOLID ink across the whole run; a text
    // glyph's top (arc starts, neighboring letters) is patchy.
    if (_inkRatio(image, y, runStart, runWidth, background) < 0.85) {
      return false;
    }
    // Tofu boxes are square-ish: the side walls span a height close to
    // the top run's width (glyphs like "m" are much wider than tall).
    if (!_boxIsSquareish(image, y, runStart, runWidth, background)) {
      return false;
    }
    // The side walls are continuous from just under the top border
    // down most of the box height; neighbouring text glyphs break the
    // run (their "walls" fade with the letter's baseline).
    if (!_wallsAreContinuous(image, y, runStart, runWidth, background)) {
      return false;
    }
    return _diagonalsCross(image, y, runStart, runWidth, background);
  }

  /// Whether both side walls carry ink at (nearly) every row of the
  /// box's expected height.
  bool _wallsAreContinuous(
    img.Image image,
    int y,
    int runStart,
    int runWidth,
    int background,
  ) {
    final height = (runWidth * 0.9).round();
    if (y + height >= image.height) return false;
    final leftEdge = runStart;
    final rightEdge = runStart + runWidth - 1;
    var misses = 0;
    for (var dy = 2; dy < height; dy++) {
      final row = y + dy;
      final left = _isInk(image.getPixel(leftEdge, row), background) ||
          _isInk(image.getPixel(leftEdge + 1, row), background);
      final right = _isInk(image.getPixel(rightEdge, row), background) ||
          _isInk(image.getPixel(rightEdge - 1, row), background);
      if (!left || !right) misses++;
    }
    // Anti-aliased small icons miss rows; text glyph "walls" (letter
    // stems) break far more often across the full height.
    return misses <= height * 0.45;
  }

  /// Whether the ink shape under row [y] spans about [runWidth] rows —
  /// tofu placeholders are square; text glyphs are wide and short.
  /// A row counts when its side walls carry ink (the thin X diagonals
  /// alone cover little of the run's width).
  bool _boxIsSquareish(
    img.Image image,
    int y,
    int runStart,
    int runWidth,
    int background,
  ) {
    var rows = 0;
    for (var dy = 0; dy <= runWidth * 2; dy++) {
      final row = y + dy;
      if (row >= image.height) break;
      if (_rowHasWalls(image, row, runStart, runWidth, background)) {
        rows++;
      } else if (dy > 4) {
        break; // the shape ended — stop counting
      }
    }
    return rows >= runWidth * 0.5;
  }

  /// Whether row [row] has ink near both run edges (the box walls).
  bool _rowHasWalls(
    img.Image image,
    int row,
    int runStart,
    int runWidth,
    int background,
  ) {
    final edge = (runWidth * 0.15).round();
    var left = false;
    var right = false;
    for (var i = 0; i <= edge; i++) {
      if (_isInk(image.getPixel(runStart + i, row), background)) left = true;
      final fromRight = runStart + runWidth - 1 - i;
      if (_isInk(image.getPixel(fromRight, row), background)) right = true;
    }
    return left && right;
  }

  /// Whether the X diagonals under the box's top border converge and
  /// cross (merge into one central band).
  bool _diagonalsCross(
    img.Image image,
    int y,
    int runStart,
    int runWidth,
    int background,
  ) {
    var prevStart = runStart;
    var prevEnd = runStart + runWidth;
    var goodRows = 0;
    for (var dy = 3; dy <= 24; dy++) {
      final row = y + dy;
      if (row >= image.height) break;
      final bands = _inkBands(image, row, runStart, runWidth, background);
      // 2-band rows are digit/letter walls (a single stroke outline);
      // the tofu cross always adds its two diagonals (>= 3 bands, more
      // when anti-aliasing splits strokes).
      if (bands.length < 3) continue;
      if (!_wallsAtEdges(bands, runStart, runWidth)) continue;
      final step = _diagonalStep(bands, prevStart, prevEnd, runStart, runWidth);
      if (step == null) continue;
      // The first accepted row only anchors the baseline; the
      // initialization gap (full run width vs the thin diagonals)
      // would otherwise fake a huge first "move".
      if (goodRows == 0) {
        prevStart = step.start;
        prevEnd = step.end;
        goodRows = 1;
        continue;
      }
      prevStart = step.start;
      prevEnd = step.end;
      goodRows++;
      // Require a SUSTAINED convergence: glyph arc tops (letters like
      // "m") collapse once around dy=1-2 and then freeze; a real X
      // keeps converging for many rows.
      if (_crossedAt(goodRows, bands.length, step.moved)) return true;
    }
    return false;
  }

  /// Whether a wall row's inner bands are converging with movement —
  /// the X signature. The first accepted row anchors the baseline;
  /// [goodRows] counts anchored + moved rows (>= 3 = at least two
  /// real moves after the anchor).
  bool _crossedAt(int goodRows, int bandCount, int moved) =>
      moved > 0 && goodRows >= 3 && (bandCount == 3 || bandCount == 4);

  /// Whether the first band hugs the run's left edge and the last its
  /// right edge — the tofu box's side walls.
  bool _wallsAtEdges(List<(int, int)> bands, int runStart, int runWidth) =>
      bands.first.$1 - runStart <= 2 &&
      runStart + runWidth - bands.last.$2 <= 2;

  /// The inner diagonal band extent of a wall-rows [bands], when it
  /// keeps converging inside the walls; `null` otherwise. Rows whose
  /// inner bands do not MOVE (static stems of letters like "m") are
  /// rejected — X diagonals shift every row.
  ({int start, int end, int moved})? _diagonalStep(
    List<(int, int)> bands,
    int prevStart,
    int prevEnd,
    int runStart,
    int runWidth,
  ) {
    final inner = bands.sublist(1, bands.length - 1);
    if (inner.isEmpty) return null;
    final start = inner.first.$1;
    final end = inner.last.$2;
    if (start < prevStart || end > prevEnd) return null;
    final wall = (runWidth * 0.15).round();
    if (start - runStart <= wall || runStart + runWidth - end <= wall) {
      return null;
    }
    final moved = prevEnd - prevStart - (end - start);
    if (moved <= 0) return null;
    return (start: start, end: end, moved: moved);
  }

  /// The share of ink pixels in row [row] within the horizontal range.
  double _inkRatio(
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
  List<(int, int)> _inkBands(
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
  int _dominantBackground(img.Image image) {
    final histogram = List<int>.filled(256, 0);
    var sampled = 0;
    for (final pixel in image) {
      if (sampled++ % 7 != 0) continue;
      final v = ((pixel.r + pixel.g + pixel.b) / 3).round();
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

  /// Whether the pixel is "ink" — far from the dominant background
  /// luma (the tofu strokes differ sharply from their surroundings).
  static bool _isInk(img.Pixel pixel, int background) {
    final v = ((pixel.r + pixel.g + pixel.b) / 3).round();
    // Tofu strokes are high-contrast outlines (light gray on dark
    // themes, near-black on light ones); filled buttons and muted UI
    // grays sit far closer to the background and must not match.
    return (v - background).abs() > 100;
  }
}
