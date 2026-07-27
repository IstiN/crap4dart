import 'package:crap4dart/src/report/badge_svg.dart';
import 'package:test/test.dart';

void main() {
  group('badgeColorFor', () {
    test('null max yields grey (N/A)', () {
      expect(badgeColorFor(null, 8.0), BadgeColors.grey);
    });

    test('at or below the threshold yields green', () {
      expect(badgeColorFor(7.99, 8.0), BadgeColors.green);
      expect(badgeColorFor(8.0, 8.0), BadgeColors.green);
      expect(badgeColorFor(0.0, 8.0), BadgeColors.green);
    });

    test('above the threshold up to twice it yields yellow', () {
      expect(badgeColorFor(8.01, 8.0), BadgeColors.yellow);
      expect(badgeColorFor(16.0, 8.0), BadgeColors.yellow);
    });

    test('above twice the threshold yields red', () {
      expect(badgeColorFor(16.01, 8.0), BadgeColors.red);
      expect(badgeColorFor(156.0, 8.0), BadgeColors.red);
    });
  });

  group('renderBadgeSvg', () {
    test('contains label, message and color', () {
      final svg = renderBadgeSvg(
        label: 'CRAP',
        message: '8.00',
        colorHex: BadgeColors.green,
      );
      expect(svg, startsWith('<svg '));
      expect(svg, endsWith('</svg>\n'));
      expect(svg, contains('>CRAP</text>'));
      expect(svg, contains('>8.00</text>'));
      expect(svg, contains('fill="${BadgeColors.green}"'));
      expect(svg, contains('fill="#555"'));
      expect(svg, isNot(contains('http://shields.io')));
    });

    test('escapes XML special characters', () {
      final svg = renderBadgeSvg(
        label: 'a<b',
        message: 'x&y',
        colorHex: BadgeColors.grey,
      );
      expect(svg, contains('a&lt;b'));
      expect(svg, contains('x&amp;y'));
    });

    test('width grows with the text length', () {
      final short = renderBadgeSvg(
        label: 'C',
        message: '1',
        colorHex: BadgeColors.green,
      );
      final long = renderBadgeSvg(
        label: 'CRAP',
        message: '123.45',
        colorHex: BadgeColors.green,
      );
      int widthOf(String svg) =>
          int.parse(RegExp('width="(\\d+)"').firstMatch(svg)!.group(1)!);
      expect(widthOf(long), greaterThan(widthOf(short)));
    });
  });
}
