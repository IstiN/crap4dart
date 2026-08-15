import 'dart:io';

import 'gate_test_utils.dart';

/// A Checkstyle XML report with one Kotlin finding.
const String ktlintFindingReport = '''
<checkstyle version="8.0">
  <file name="android/app/src/main/MainActivity.kt">
    <error line="14" column="3" severity="warning"
        message="Function is too long" source="detekt.LongMethod" />
  </file>
</checkstyle>
''';

/// An empty Checkstyle XML report.
const String emptyReport = '<checkstyle version="8.0"></checkstyle>';

/// Writes a fake "tool" script that emits [reportBody] as a
/// Checkstyle XML report to its first argument.
String writeFakeTool(Directory root, String reportBody) {
  final script = File('${root.path}/fake_tool.sh')..createSync(recursive: true);
  script.writeAsStringSync('''
#!/bin/sh
cat > "\$1" <<'EOF'
$reportBody
EOF
''');
  Process.runSync('chmod', ['+x', script.path]);
  return script.path;
}

/// A gate context config running [tool] as the `external` rule `fake`.
externalContext(Directory project, String tool) => makeContext(
      project,
      const [],
      configYaml: '''
gates:
  external:
    rules:
      - id: fake
        executable: '$tool'
        arguments: ['{report}']
''',
    );
