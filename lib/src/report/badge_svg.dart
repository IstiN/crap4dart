/// SVG badge colors from the shields.io palette.
abstract final class BadgeColors {
  /// Bright green — at or below the threshold.
  static const String green = '#4c1';

  /// Yellow — above the threshold but at most twice it.
  static const String yellow = '#dfb317';

  /// Red — more than twice the threshold.
  static const String red = '#e05d44';

  /// Light grey — no numeric value (N/A).
  static const String grey = '#9f9f9f';
}

/// Picks the badge color for [maxCrap] against [threshold].
///
/// `null` (all methods N/A) yields grey; at or below [threshold] green;
/// above it but at most `2 * threshold` yellow; beyond that red.
String badgeColorFor(double? maxCrap, double threshold) {
  if (maxCrap == null) return BadgeColors.grey;
  if (maxCrap <= threshold) return BadgeColors.green;
  if (maxCrap <= 2 * threshold) return BadgeColors.yellow;
  return BadgeColors.red;
}

/// Renders a flat shields.io-style SVG badge: a grey label plate on the
/// left and a colored message plate on the right.
///
/// [colorHex] is a CSS hex color (e.g. `#4c1`). The output is a
/// self-contained SVG document without external references.
String renderBadgeSvg({
  required String label,
  required String message,
  required String colorHex,
}) {
  final labelWidth = _plateWidth(label);
  final messageWidth = _plateWidth(message);
  final totalWidth = labelWidth + messageWidth;
  final labelCenter = labelWidth / 2;
  final messageCenter = labelWidth + messageWidth / 2;
  return '<svg xmlns="http://www.w3.org/2000/svg" width="$totalWidth" '
      'height="20" viewBox="0 0 $totalWidth 20" role="img" '
      'aria-label="${_escape(label)}: ${_escape(message)}">\n'
      '  <title>${_escape(label)}: ${_escape(message)}</title>\n'
      '  <rect width="$labelWidth" height="20" rx="3" fill="#555"/>\n'
      '  <rect x="$labelWidth" width="$messageWidth" height="20" rx="3" '
      'fill="$colorHex"/>\n'
      '  <rect width="$totalWidth" height="20" rx="3" fill="none"/>\n'
      '  <g fill="#fff" font-family="Verdana,DejaVu Sans,sans-serif" '
      'font-size="11" text-anchor="middle">\n'
      '    <text x="$labelCenter" y="14">${_escape(label)}</text>\n'
      '    <text x="$messageCenter" y="14">${_escape(message)}</text>\n'
      '  </g>\n'
      '</svg>\n';
}

int _plateWidth(String text) => (text.length * 6.3).round() + 10;

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
