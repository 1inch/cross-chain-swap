## What this changes

<!-- Link the issue that describes the bug or feature, or write a detailed description of what changes and why — enough for a reviewer who has not followed the work. -->

## Static Code Analysis (readability, compactness)

<!-- How the change reads in the diff: naming, structure, duplication removed or introduced, whether the new surface is as small as the problem allows. -->

## Dynamic Code Analysis (external APIs, interaction flows)

<!-- Call paths that changed: which contracts, tokens or off-chain APIs are touched, who calls whom, and what happens on revert or partial failure. -->

## Efficiency (gas costs, computational complexity, memory requirements)

<!-- Hot paths, loops, storage reads/writes, and anything that moves cost on-chain or off. Call out measured gas deltas when you have them{{GAS_HINT}}. -->

## Opinion, trade-offs and other thoughts (optional)

<!-- Alternatives you rejected and why, known limitations you are accepting, or anything a reviewer should not have to discover alone. -->

## Checklist

- [ ] Linked issue, or a detailed description above that stands on its own
- [ ] Tests added or updated for this change, including revert paths
- [ ] Documentation updated where it describes the changed behaviour (README, `docs/`, NatSpec)
- [ ] Gas impact assessed{{GAS_HINT}}
- [ ] No new compiler warnings
{{STORAGE_LAYOUT_ITEM}}

## AI assistance

<!-- If you used AI tools: purpose of the usage, model name, and model settings (effort and context size). Write "None" if you did not. -->
