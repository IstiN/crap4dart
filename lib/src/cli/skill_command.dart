import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'exit_codes.dart';

/// The `skill` command: prints the crap4dart profiling skill content for
/// agents, or shows installation instructions.
class SkillCommand extends Command<int> {
  /// Creates a [SkillCommand].
  SkillCommand({this.projectRoot}) {
    argParser.addOption(
      'format',
      allowed: ['text', 'install'],
      defaultsTo: 'text',
      help: 'text: print skill content; install: show install instructions.',
    );
  }

  /// Project root override.
  final String? projectRoot;

  @override
  final String name = 'skill';

  @override
  final description =
      'Print the crap4dart profiling skill for AI agents, or show '
      'installation instructions.';

  @override
  String get invocation => 'crap4dart skill [--format text|install]';

  @override
  int run() {
    final format = argResults!['format'] as String;
    if (format == 'install') {
      _printInstallInstructions();
    } else {
      _printSkillContent();
    }
    return ExitCodes.success;
  }

  void _printSkillContent() {
    final skillFile = _findSkillFile();
    if (skillFile == null) {
      stderr.writeln('Skill file not found.');
      return;
    }
    stdout.writeln(skillFile.readAsStringSync());
  }

  void _printInstallInstructions() {
    stdout.writeln('''
# Installing the crap4dart profiling skill

## Option 1: Install to user-level skills (recommended)

```bash
mkdir -p ~/.agents/skills/crap4dart-profiling
crap4dart skill --format text > ~/.agents/skills/crap4dart-profiling/SKILL.md
```

The skill will be automatically available to all AI agents running in any
project on this machine.

## Option 2: Install to a specific project

```bash
mkdir -p .agents/skills/crap4dart-profiling
crap4dart skill --format text > .agents/skills/crap4dart-profiling/SKILL.md
```

Add `.agents/` to git if you want to share it with your team.

## Option 3: Install via npx skills CLI

```bash
npx skills add github:IstiN/crap4dart
```

## Verify installation

```bash
cat ~/.agents/skills/crap4dart-profiling/SKILL.md
```
''');
  }

  /// Finds the SKILL.md file relative to this package's source.
  File? _findSkillFile() {
    // Check several locations: source tree, installed package, compiled.
    final candidates = <String>[
      p.join(Directory.current.path, '.agents', 'skills', 'crap4dart-profiling',
          'SKILL.md'),
      p.join(
          Directory.current.path, 'skills', 'crap4dart-profiling', 'SKILL.md'),
    ];

    // Also look relative to the crap4dart package itself.
    final scriptPath = Platform.script.toFilePath();
    if (scriptPath.isNotEmpty) {
      candidates.add(p.join(
        p.dirname(p.dirname(p.dirname(scriptPath))),
        '.agents',
        'skills',
        'crap4dart-profiling',
        'SKILL.md',
      ));
    }

    for (final path in candidates) {
      final file = File(path);
      if (file.existsSync()) return file;
    }
    return null;
  }
}
