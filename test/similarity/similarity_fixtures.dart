/// Shared prose fixtures for similarity tests (>> 50 shingles each).
library;

/// Baseline prose.
const String proseA =
    'alpha bravo charlie delta echo foxtrot golf hotel india juliet '
    'kilo lima mike november oscar papa quebec romeo sierra tango uniform '
    'victor whiskey xray yankee zulu alpha bravo charlie delta echo '
    'foxtrot golf hotel india juliet kilo lima mike november oscar papa';

/// Near-duplicate of [proseA]: two scattered words differ.
const String proseB =
    'alpha bravo charlie delta echo foxtrot golf hotel india juliet '
    'kilo lima mike november oscar papa quebec SIERRA tango uniform '
    'victor whiskey xray yankee zulu alpha bravo charlie delta echo '
    'foxtrot golf hotel india juliet kilo lima mike november delta papa';

/// Unrelated prose sharing almost nothing with [proseA].
const String proseC =
    'the quick brown fox jumps over the lazy dog while the sleepy cat '
    'naps under the warm sun dreaming about fish and mice and cream '
    'the dog barks loudly at nothing in particular every single night';
