part of 'config.dart';

// The quality-gate config classes: post-0.25 gates that flag
// suspicious logic shapes rather than size or resource budgets.
// Split from gate_configs.dart to stay under the `loc` cap.
// ignore_for_file: annotate_overrides

/// Identical branch conditions gate settings (`identical_branches`).
class IdenticalBranchesGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  /// Defaults to `warning`: reordered operands compare equal only when
  /// they are side-effect free, which pure syntax cannot prove.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Creates an [IdenticalBranchesGateConfig].
  const IdenticalBranchesGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.warning,
    this.ignorable = false,
  });
}

/// Enum name contract gate settings (`enum_name_contract`).
class EnumNameContractGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Creates an [EnumNameContractGateConfig].
  const EnumNameContractGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.warning,
    this.ignorable = false,
  });
}

/// Collapsible flow gate settings (`collapsible_flow`).
class CollapsibleFlowGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Creates a [CollapsibleFlowGateConfig].
  const CollapsibleFlowGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.warning,
    this.ignorable = false,
  });
}

/// Non-null assertion gate settings (`non_null_assertion`).
class NonNullAssertionGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  /// Defaults to `warning`: on an existing codebase every removed `!`
  /// needs a per-site nullability audit.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Creates a [NonNullAssertionGateConfig].
  const NonNullAssertionGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.warning,
    this.ignorable = false,
  });
}

/// The quality-gate subgroup of [GatesConfig]: the post-0.25 gates
/// that flag suspicious logic shapes rather than size or resource
/// budgets. Grouping keeps the [GatesConfig] constructor under the
/// `method_size` parameter cap; the YAML keys stay top-level
/// (`gates.string_hazards`, not `gates.quality.string_hazards`).
class QualityGatesConfig {
  /// String literal hazards gate (`string_hazards`).
  final StringHazardsGateConfig stringHazards;

  /// Identical branch conditions gate (`identical_branches`).
  final IdenticalBranchesGateConfig identicalBranches;

  /// Enum name contract gate (`enum_name_contract`).
  final EnumNameContractGateConfig enumNameContract;

  /// Collapsible flow gate (`collapsible_flow`).
  final CollapsibleFlowGateConfig collapsibleFlow;

  /// Non-null assertion gate (`non_null_assertion`).
  final NonNullAssertionGateConfig nonNullAssertion;

  /// Creates a [QualityGatesConfig].
  const QualityGatesConfig({
    this.stringHazards = const StringHazardsGateConfig(),
    this.identicalBranches = const IdenticalBranchesGateConfig(),
    this.enumNameContract = const EnumNameContractGateConfig(),
    this.collapsibleFlow = const CollapsibleFlowGateConfig(),
    this.nonNullAssertion = const NonNullAssertionGateConfig(),
  });
}

/// String literal hazard gate settings (`string_hazards`).
class StringHazardsGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Creates a [StringHazardsGateConfig].
  const StringHazardsGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.warning,
    this.ignorable = false,
  });
}
