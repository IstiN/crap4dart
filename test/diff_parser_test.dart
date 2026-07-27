import 'package:crap4dart/src/files/diff_parser.dart';
import 'package:test/test.dart';

void main() {
  const parser = GitDiffParser();

  group('GitDiffParser.parse', () {
    final map = parser.parse('/repo', '''
diff --git a/lib/a.dart b/lib/a.dart
index 1111111..2222222 100644
--- a/lib/a.dart
+++ b/lib/a.dart
@@ -5,0 +6,2 @@
+new line
+another new line
@@ -10 +12 @@
-changed
+changed too
diff --git a/lib/deleted.dart b/lib/deleted.dart
deleted file mode 100644
index 3333333..0000000
--- a/lib/deleted.dart
+++ /dev/null
@@ -1,2 +0,0 @@
-gone
-gone too
diff --git a/lib/new.dart b/lib/new.dart
new file mode 100644
index 0000000..4444444
--- /dev/null
+++ b/lib/new.dart
@@ -0,0 +1,3 @@
+a
+b
+c
diff --git a/lib/old.dart b/lib/renamed.dart
similarity index 90%
rename from lib/old.dart
rename to lib/renamed.dart
--- a/lib/old.dart
+++ b/lib/renamed.dart
@@ -2,0 +3 @@
+added
diff --git a/lib/onlydel.dart b/lib/onlydel.dart
index 5555555..6666666 100644
--- a/lib/onlydel.dart
+++ b/lib/onlydel.dart
@@ -4 +4,0 @@
-removed
''');

    test('collects added lines per file', () {
      expect(map.addedLines['lib/a.dart'], {6, 7, 12});
    });

    test('new files have all their lines added', () {
      expect(map.addedLines['lib/new.dart'], {1, 2, 3});
    });

    test('renames are keyed by the new path', () {
      expect(map.addedLines.containsKey('lib/old.dart'), isFalse);
      expect(map.addedLines['lib/renamed.dart'], {3});
    });

    test('deleted files are absent', () {
      expect(map.addedLines.containsKey('lib/deleted.dart'), isFalse);
    });

    test('deletion-only files are present with an empty set', () {
      expect(map.addedLines['lib/onlydel.dart'], isEmpty);
      expect(map.hasRealChanges('lib/onlydel.dart'), isFalse);
    });

    test('intersects matches methods overlapping changed lines', () {
      expect(map.intersects('lib/a.dart', 1, 5), isFalse);
      expect(map.intersects('lib/a.dart', 5, 7), isTrue);
      expect(map.intersects('/repo/lib/a.dart', 10, 12), isTrue);
      expect(map.intersects('lib/new.dart', 1, 3), isTrue);
      expect(map.intersects('lib/onlydel.dart', 1, 100), isFalse);
    });
  });
}
