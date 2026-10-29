/// The canonical gate identifiers.
///
/// Every place that names a gate — the gate's own [id getter], the
/// runner's dispatch table, the config loader's `gates.*` key map —
/// references these constants, so renaming a gate is a one-line change
/// and the `scattered_constants` gate keeps the spellings linked.
library;

/// The gate identifiers, keyed by gate.
abstract final class GateIds {
  /// File size gate (`loc`).
  static const String loc = 'loc';

  /// Test coverage gate.
  static const String testCoverage = 'test_coverage';

  /// Golden test coverage gate.
  static const String golden = 'golden';

  /// Hardcoded strings gate.
  static const String hardcodedStrings = 'hardcoded_strings';

  /// Accessibility gate.
  static const String accessibility = 'accessibility';

  /// Cyclomatic complexity gate.
  static const String complexity = 'complexity';

  /// Method size gate.
  static const String methodSize = 'method_size';

  /// Nesting gate.
  static const String nesting = 'nesting';

  /// Record named fields gate.
  static const String recordNamedFields = 'record_named_fields';

  /// Inline record types gate.
  static const String inlineRecordTypes = 'inline_record_types';

  /// Record size gate.
  static const String recordSize = 'record_size';

  /// Class size gate.
  static const String classSize = 'class_size';

  /// Weight of class gate.
  static const String weightOfClass = 'weight_of_class';

  /// Unused private code gate.
  static const String unusedCode = 'unused_code';

  /// Unused files gate.
  static const String unusedFiles = 'unused_files';

  /// Banned imports gate.
  static const String bannedImports = 'banned_imports';

  /// Public API documentation gate.
  static const String publicDocs = 'public_docs';

  /// Duplication gate.
  static const String duplication = 'duplication';

  /// File naming gate.
  static const String fileNaming = 'file_naming';

  /// Magic constants gate.
  static const String magicConstants = 'magic_constants';

  /// Scattered constants gate.
  static const String scatteredConstants = 'scattered_constants';

  /// Scattered fragments gate.

  /// Broken goldens gate.
  static const String brokenGoldens = 'broken_goldens';

  /// Test assertions gate.
  static const String testAssertions = 'test_assertions';

  /// Folder structure gate.
  static const String folderStructure = 'folder_structure';

  /// External tools gate.
  static const String external = 'external';

  /// Mutation testing gate.
  static const String mutation = 'mutation';

  /// Similarity gate.
  static const String similarity = 'similarity';

  /// String literal hazards gate.
  static const String stringHazards = 'string_hazards';

  /// Identical branch conditions gate (`identical_branches`).
  static const String identicalBranches = 'identical_branches';

  /// Enum name contract gate (`enum_name_contract`).
  static const String enumNameContract = 'enum_name_contract';

  /// Every gate id in runner order.
  static const List<String> all = [
    loc,
    testCoverage,
    complexity,
    methodSize,
    nesting,
    recordNamedFields,
    inlineRecordTypes,
    recordSize,
    classSize,
    duplication,
    fileNaming,
    magicConstants,
    scatteredConstants,
    brokenGoldens,
    testAssertions,
    folderStructure,
    external,
    unusedCode,
    unusedFiles,
    bannedImports,
    publicDocs,
    hardcodedStrings,
    accessibility,
    golden,
    weightOfClass,
    mutation,
    similarity,
    stringHazards,
    identicalBranches,
    enumNameContract,
  ];
}
