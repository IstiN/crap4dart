# Changelog

All notable changes to this project will be documented in this file.

## 0.10.0 - 2026-09-28

### Added

- `duplication` gate: new `sources` key — additional file/directory paths
  (resolved against the project root) unioned into the duplication scan,
  enabling cross-module duplicate detection in monorepos without widening
  the CRAP analysis scope.

### Changed

- Dependencies refreshed: `analyzer` 7.3 -> 14.4 (new "parts" AST —
  `ClassDeclaration.namePart.typeName`, `NamedType.name`,
  `NamedArgument`/`Argument` model, `body.members`, `isComplete`),
  `xml` 7.1, `test` 1.32, `lints` 6.1.

