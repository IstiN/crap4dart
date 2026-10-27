part of 'tofu_detector.dart';

/// Scans an image for hollow icon boxes: square-ish bordered boxes
/// with continuous walls and an EMPTY interior — what an unloaded icon
/// font actually draws (the glyph is missing, the placeholder box is
/// painted), with no diagonal cross.
class _HollowBoxScanner {
  /// Creates the scanner.
  const _HollowBoxScanner();

  /// Whether [image] contains a hollow icon box.
  bool scan(img.Image image) {
    final background = TofuDetector.dominantBackground(image);
    return TofuDetector.scanRowsForBox(
      image,
      background,
      minIcon: 20, // px — checkboxes are 16-18 px, .notdef boxes
      // 22-24 px (issue #3 pins the placeholder sizes)
      maxIcon: 64,
      firstRow: 2,
      matches: (y, start, width) =>
          _confirmed(image, y, start, width, background),
    );
  }

  /// Whether the box opening at row [y] is a hollow placeholder: solid
  /// top border floating on background, continuous side walls, and an
  /// empty interior (excluding a wall margin).
  bool _confirmed(
    img.Image image,
    int y,
    int runStart,
    int runWidth,
    int background,
  ) {
    if (!TofuDetector.opensOnBackground(
        image, y, runStart, runWidth, background)) {
      return false;
    }
    if (!TofuDetector.ringIsolated(image, y, runStart, runWidth, background)) {
      return false;
    }
    final height = runWidth; // square-ish placeholder
    // A real .notdef placeholder has square corners; a rounded UI
    // square (unchecked checkbox, icon panel) loses its corner pixels.
    if (!TofuDetector.hasSquareCorners(
        image, y, runStart, runWidth, height, background)) {
      return false;
    }
    if (y + height >= image.height) return false;
    final walls = _Walls(image, runStart, runWidth, background);
    if (!walls.continuous(y, height)) return false;
    return _interiorIsEmpty(y, runWidth, walls);
  }

  /// Whether the box interior (excluding a 4px wall margin) is empty.
  bool _interiorIsEmpty(int y, int runWidth, _Walls walls) {
    var ink = 0;
    var total = 0;
    for (var dy = 4; dy < runWidth - 4; dy++) {
      for (var dx = 4; dx < runWidth - 4; dx++) {
        total++;
        if (walls.isInkInside(walls.runStart + dx, y + dy)) ink++;
      }
    }
    if (total == 0) return false;
    return ink / total <= 0.08;
  }
}

/// Scans an image for runs of solid glyph rectangles (Ahem fallback
/// text): at least two DISTINCT solid rectangles of the same vertical
/// extent, side by side with a small gap — what text looks like when
/// the font failed to load in the test environment.
class _SolidGlyphScanner {
  /// Creates the scanner.
  const _SolidGlyphScanner();

  /// Whether [image] contains an aligned pair of solid rectangles.
  bool scan(img.Image image) {
    final background = TofuDetector.dominantBackground(image);
    // (top, bottom) -> distinct rectangles' (x0, x1) extents.
    final groups = <_Vertical, Set<_Span>>{};
    for (var y = 1; y < image.height - 1; y++) {
      TofuDetector.forEachInkRun(image, y, background, (start, width) {
        if (width < 6 || width > 48) return;
        final rect = _SolidRect.at(image, y, start, width, background);
        if (rect == null) return;
        groups
            .putIfAbsent(rect, () => <_Span>{})
            .add((start: start, end: start + width - 1));
      });
    }
    return _hasAlignedPair(groups);
  }

  /// Whether any vertical-extent group holds two distinct rectangles
  /// with a small horizontal gap (a word's letter spacing).
  bool _hasAlignedPair(Map<_Vertical, Set<_Span>> groups) {
    for (final rects in groups.values) {
      final xs = rects.toList()
        ..sort(
            (a, b) => a.start != b.start ? a.start - b.start : a.end - b.end);
      for (var i = 1; i < xs.length; i++) {
        if (xs[i].start - xs[i - 1].end <= 16) return true;
      }
    }
    return false;
  }
}

/// A solid, bounded, glyph-sized rectangle found by its row runs.
class _SolidRect {
  /// First and last row of the rectangle.
  final int top, bottom;

  /// Creates the extent record.
  const _SolidRect(this.top, this.bottom);

  /// The rectangle covering row [y]'s ink run, or `null` when the run
  /// is not a bounded solid rectangle with vertical glyph-size edges.
  static _Vertical? at(
    img.Image image,
    int y,
    int runStart,
    int runWidth,
    int background,
  ) {
    final top = _edgeWalk(image, y, runStart, runWidth, background, -1);
    final bottom = _edgeWalk(image, y, runStart, runWidth, background, 1);
    final height = bottom - top + 1;
    if (height < 8 || height > 40) return null;
    if (height > runWidth * 3 || runWidth > height * 3) return null;
    if (!_bounded(image, top, bottom, runStart, runWidth, background)) {
      return null;
    }
    if (!_walled(image, top, bottom, runStart, runWidth, background)) {
      return null;
    }
    // Ahem glyphs are square-cornered solid blocks; rounded UI squares
    // (pagination dots, white icon chips) lose their corner pixels.
    if (!TofuDetector.hasSquareCorners(
        image, top, runStart, runWidth, height, background)) {
      return null;
    }
    return (top: top, bottom: bottom);
  }

  /// Walks up (step -1) or down (step 1) from [y] while the row is
  /// fully ink; returns the last solid row.
  static int _edgeWalk(
    img.Image image,
    int y,
    int runStart,
    int runWidth,
    int background,
    int step,
  ) {
    var edge = y;
    while (true) {
      final next = edge + step;
      if (next < 0 || next >= image.height) break;
      if (TofuDetector.inkRatio(image, next, runStart, runWidth, background) <
          0.95) {
        break;
      }
      edge = next;
    }
    return edge;
  }

  /// Whether background (nearly) sits directly above and below.
  static bool _bounded(
    img.Image image,
    int top,
    int bottom,
    int runStart,
    int runWidth,
    int background,
  ) =>
      _mostlyBackground(image, top - 1, runStart, runWidth, background) &&
      _mostlyBackground(image, bottom + 1, runStart, runWidth, background);

  static bool _mostlyBackground(
    img.Image image,
    int row,
    int runStart,
    int runWidth,
    int background,
  ) =>
      row < 0 ||
      row >= image.height ||
      TofuDetector.inkRatio(image, row, runStart, runWidth, background) <= 0.2;

  /// Whether both edge columns carry ink for the full height.
  static bool _walled(
    img.Image image,
    int top,
    int bottom,
    int runStart,
    int runWidth,
    int background,
  ) {
    final right = runStart + runWidth - 1;
    for (var row = top; row <= bottom; row++) {
      if (!TofuDetector._isInk(image.getPixel(runStart, row), background) ||
          !TofuDetector._isInk(image.getPixel(right, row), background)) {
        return false;
      }
    }
    return true;
  }
}

/// The side walls of one candidate box, for continuity and interior
/// checks.
class _Walls {
  final img.Image image;

  final int runStart;

  final int runWidth;

  final int background;

  /// Creates the wall helper for a box.
  const _Walls(this.image, this.runStart, this.runWidth, this.background);

  /// Whether the pixel is inside the box walls (ink test).
  bool isInkInside(int x, int y) =>
      TofuDetector._isInk(image.getPixel(x, y), background);

  /// Whether both side walls carry ink at (nearly) every row of the
  /// box's expected [height].
  bool continuous(int y, int height) {
    if (y + height >= image.height) return false;
    final leftEdge = runStart;
    final rightEdge = runStart + runWidth - 1;
    var misses = 0;
    for (var dy = 2; dy < height; dy++) {
      final row = y + dy;
      final left = isInkInside(leftEdge, row) || isInkInside(leftEdge + 1, row);
      final right =
          isInkInside(rightEdge, row) || isInkInside(rightEdge - 1, row);
      if (!left || !right) misses++;
    }
    // Anti-aliased small icons miss rows; text glyph "walls" (letter
    // stems) break far more often across the full height.
    return misses <= height * 0.45;
  }
}
