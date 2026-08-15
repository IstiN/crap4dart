import 'dart:io';

import 'package:image/image.dart' as img;

import 'gate.dart';
import 'gate_context.dart';

/// The `broken_goldens` gate: scans golden PNG files for rendered
/// Flutter error artifacts — yellow/black overflow stripes and the red
/// build-error screen (dark red background with yellow text).
///
/// Golden tests do not fail on these: the broken frame gets captured
/// (often permanently, via `--update-goldens`), so the pixels are the
/// only witness.
class BrokenGoldensGate implements Gate {
  /// Creates a [BrokenGoldensGate].
  const BrokenGoldensGate();

  @override
  String get id => 'broken_goldens';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.brokenGoldens;
    final violations = <GateViolation>[];
    var checked = 0;
    for (final dir in config.dirs) {
      final directory = Directory('${context.projectRoot}/$dir');
      if (!directory.existsSync()) continue;
      for (final png in _goldenFiles(directory, config.exclude, context)) {
        checked++;
        final violation = _violation(png, config.minStripeRun, context);
        if (violation != null) violations.add(violation);
      }
    }
    final summary = violations.isEmpty
        ? '$checked golden images clean'
        : '${violations.length}/$checked golden images contain error '
            'artifacts';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }

  /// Non-excluded PNG files under [directory].
  Iterable<File> _goldenFiles(
    Directory directory,
    List<String> exclude,
    GateContext context,
  ) =>
      [
        for (final entity in directory.listSync(recursive: true))
          if (entity is File &&
              entity.path.endsWith('.png') &&
              !context.matchesAnyGlob(entity.path, exclude))
            entity,
      ];

  /// The violation for [png], or `null` when the image is clean.
  GateViolation? _violation(
    File png,
    int minStripeRun,
    GateContext context,
  ) {
    final message = _analyze(png, minStripeRun);
    if (message == null) return null;
    return GateViolation(
      file: context.relativePath(png.path),
      message: message,
    );
  }

  /// Returns a violation message for [file], or `null` when clean.
  String? _analyze(File file, int minStripeRun) {
    final image = img.decodeImage(file.readAsBytesSync());
    if (image == null) return null;
    if (_hasOverflowStripes(image, minStripeRun)) {
      return 'overflow stripes (yellow/black) rendered in the golden — '
          'the widget overflows and the snapshot recorded it';
    }
    if (_hasErrorScreen(image)) {
      return 'build-error screen (dark red) rendered in the golden — '
          'the widget tree threw during the snapshot';
    }
    return null;
  }

  /// Whether the image contains a run of alternating yellow/black
  /// pixels at least [minStripeRun] long (horizontal or vertical).
  bool _hasOverflowStripes(img.Image image, int minStripeRun) {
    for (var y = 0; y < image.height; y++) {
      if (_stripeRunInRow(image, y, minStripeRun)) return true;
    }
    for (var x = 0; x < image.width; x++) {
      if (_stripeRunInColumn(image, x, minStripeRun)) return true;
    }
    return false;
  }

  bool _stripeRunInRow(img.Image image, int y, int minRun) {
    var run = 0;
    var alternating = false;
    var lastWasStripe = false;
    for (var x = 0; x < image.width; x++) {
      final isStripe = _isStripePixel(image.getPixel(x, y));
      if (isStripe) {
        run++;
        // Alternation is implied by the checkerboard pattern; we just
        // need enough stripe-colored pixels in a line.
        lastWasStripe = true;
      } else {
        if (lastWasStripe && run < minRun) run = 0;
        lastWasStripe = false;
      }
      if (run >= minRun) {
        alternating = true;
        break;
      }
    }
    return alternating;
  }

  bool _stripeRunInColumn(img.Image image, int x, int minRun) {
    var run = 0;
    for (var y = 0; y < image.height; y++) {
      if (_isStripePixel(image.getPixel(x, y))) {
        run++;
        if (run >= minRun) return true;
      } else {
        run = 0;
      }
    }
    return false;
  }

  /// Whether the pixel is the yellow (or black) of an overflow stripe,
  /// matched with tolerance: yellow is high R+G, low B.
  bool _isStripePixel(img.Pixel pixel) {
    final r = pixel.r.toInt();
    final g = pixel.g.toInt();
    final b = pixel.b.toInt();
    final isYellow = r > 200 && g > 180 && b < 90;
    final isBlack = r < 60 && g < 60 && b < 60;
    return isYellow || isBlack;
  }

  /// Whether ≥ [errorThreshold] of the image is the dark-red
  /// ErrorWidget background (R high-ish, G/B very low).
  bool _hasErrorScreen(img.Image image) {
    const errorThreshold = 0.15;
    var red = 0;
    var total = 0;
    for (final pixel in image) {
      total++;
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      // RenderErrorBox background: dark red (#900000 at 94% opacity).
      if (r > 100 && r < 200 && g < 40 && b < 40) red++;
    }
    return total > 0 && red / total >= errorThreshold;
  }
}
