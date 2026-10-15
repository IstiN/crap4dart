part of 'tofu_detector.dart';

/// Scans an image for the icon-tofu signature: a bordered square whose
/// diagonals run the full X life cycle — converge, merge into one
/// narrow central band (the crossing), then diverge again. A
/// checkmark V converges to its vertex and never re-diverges.
class _XCrossScanner {
  /// Creates the scanner.
  const _XCrossScanner();

  /// Whether [image] contains a tofu cross (icon-sized boxes only;
  /// text rows fail the box checks).
  bool scan(img.Image image) {
    final background = TofuDetector.dominantBackground(image);
    return TofuDetector.scanRowsForBox(
      image,
      background,
      minIcon: 20, // px — icon-sized
      maxIcon: 400,
      matches: (y, start, width) =>
          _crossConfirmed(image, y, start, width, background),
    );
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
    // The box floats on the background and its top border is solid
    // ink (a text glyph's top is patchy; a filled button's ink
    // continues above the border).
    if (!TofuDetector.opensOnBackground(
        image, y, runStart, runWidth, background)) {
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
    if (!_Walls(image, runStart, runWidth, background)
        .continuous(y, (runWidth * 0.9).round())) {
      return false;
    }
    return _diagonalsCross(image, y, runStart, runWidth, background);
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
      if (_isInkAt(image, runStart + i, row, background)) left = true;
      final fromRight = runStart + runWidth - 1 - i;
      if (_isInkAt(image, fromRight, row, background)) right = true;
    }
    return left && right;
  }

  /// Whether the X diagonals under the box's top border run the FULL
  /// X life cycle (see [_XPhaseTracker]).
  bool _diagonalsCross(
    img.Image image,
    int y,
    int runStart,
    int runWidth,
    int background,
  ) {
    final tracker = _XPhaseTracker(runStart, runStart + runWidth);
    for (var dy = 3; dy <= 24; dy++) {
      final row = y + dy;
      if (row >= image.height) break;
      final bands =
          TofuDetector.inkBands(image, row, runStart, runWidth, background);
      // 2-band rows are digit/letter walls (a single stroke outline);
      // the tofu cross always adds its diagonals (>= 3 bands, more
      // when anti-aliasing splits strokes).
      if (bands.length < 3) continue;
      if (!_wallsAtEdges(bands, runStart, runWidth)) continue;
      if (tracker.step(bands, runStart, runWidth)) return true;
    }
    return false;
  }

  /// Whether the first band hugs the run's left edge and the last its
  /// right edge — the tofu box's side walls.
  bool _wallsAtEdges(List<(int, int)> bands, int runStart, int runWidth) =>
      bands.first.$1 - runStart <= 2 &&
      runStart + runWidth - bands.last.$2 <= 2;

  static bool _isInkAt(img.Image image, int x, int y, int background) =>
      TofuDetector._isInk(image.getPixel(x, y), background);
}

/// The X phase machine: tracks the converge phase (inner bands
/// shrinking with real movement between the walls), detects the
/// crossing (the two diagonals fuse into one narrow central band) and
/// then requires the DIVERGE phase (the fused band splits and widens
/// apart again) — the proof the strokes CROSS rather than meet at a
/// vertex. A checkmark V converges and keeps a single stroke, so it
/// never completes the cycle.
class _XPhaseTracker {
  /// Anchors the tracker on the run's full extent.
  _XPhaseTracker(int runStart, int runWidth)
      : _prevStart = runStart,
        _prevEnd = runStart + runWidth;

  int _prevStart;
  int _prevEnd;
  int _goodRows = 0;
  bool _merged = false;
  int _divStart = -1;
  int _divEnd = -1;
  int _divergeRows = 0;

  /// Feeds one wall row's [bands]; `true` once the X cycle is proven.
  bool step(List<(int, int)> bands, int runStart, int runWidth) {
    final inner = bands.sublist(1, bands.length - 1);
    if (inner.isEmpty) return false;
    return _merged
        ? _stepDiverge(inner)
        : _stepConverge(inner, runStart, runWidth);
  }

  /// Converge phase: inner bands shrink inside the walls with real
  /// movement every row; when a single narrow central band remains,
  /// the crossing is reached (but not yet proven).
  bool _stepConverge(List<(int, int)> inner, int runStart, int runWidth) {
    final extent = _shrinkExtent(inner, runStart, runWidth);
    if (extent == null) return false;
    _anchor(extent);
    if (inner.length != 1) return false;
    if (extent.$2 - extent.$1 > runWidth * 0.35) return false;
    _merged = true;
    _divStart = extent.$1;
    _divEnd = extent.$2;
    return false;
  }

  /// The shrinking inner extent at this row, or `null` when the bands
  /// stopped converging (grew, stalled, or slid into a wall).
  (int, int)? _shrinkExtent(
      List<(int, int)> inner, int runStart, int runWidth) {
    final start = inner.first.$1;
    final end = inner.last.$2;
    if (start < _prevStart || end > _prevEnd) return null;
    final wall = (runWidth * 0.15).round();
    if (start - runStart <= wall || runStart + runWidth - end <= wall) {
      return null;
    }
    if (end - start >= _prevEnd - _prevStart) return null; // stalled
    return (start, end);
  }

  /// Records the accepted row: the first one only anchors the baseline
  /// (the initialization gap would otherwise fake a huge first move).
  void _anchor((int, int) extent) {
    _goodRows = _goodRows == 0 ? 1 : _goodRows + 1;
    _prevStart = extent.$1;
    _prevEnd = extent.$2;
  }

  /// Diverge phase: the fused band splits and widens — a V never does.
  bool _stepDiverge(List<(int, int)> inner) {
    final start = inner.first.$1;
    final end = inner.last.$2;
    if (inner.length >= 2 && (start < _divStart || end > _divEnd)) {
      _divergeRows++;
      _divStart = math.min(_divStart, start);
      _divEnd = math.max(_divEnd, end);
      return _divergeRows >= 2;
    }
    // Still fused (anti-aliasing keeps one band a few rows).
    _divStart = math.min(_divStart, start);
    _divEnd = math.max(_divEnd, end);
    return false;
  }
}
