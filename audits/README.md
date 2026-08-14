# Audits

Copies of the audit reports for these contracts. The reports are also published in [1inch/1inch-audits](https://github.com/1inch/1inch-audits), which is the source of truth — these files were copied from commit [`7fa99dd`](https://github.com/1inch/1inch-audits/tree/7fa99dd6996fa189d10e925fc54ae2a59b62bc51) with their original names, so each one can be checked against the original.

Accepted risks and the limitations these reviews did not change are recorded in [SECURITY.md](../SECURITY.md#accepted-risks-and-known-limitations).

## [cross-chain-protocol/](cross-chain-protocol) — release 1.0.0

From [`Cross-chain Protocol`](https://github.com/1inch/1inch-audits/tree/master/Cross-chain%20Protocol). Two rounds of review, distinguished by the `v1` and `v2` in the file names.

| Auditor | Round 1 | Round 2 |
| ------------ | -------------------------------------------- | ----------------------------------- |
| AstraSec | `1inch-cross-chain-swap-v1-AstraSec.pdf` | `1inch-cross-chain-v2-Astrasec.pdf` |
| Consensys | `1inch-cross-chain-swap-v1-Consensys.pdf` | `1inch-cross-chain-v2-Consensys.pdf` |
| Decurity | `1inch-cross-chain-swap-v1-Decurity.pdf` | `1inch-cross-chain-v2-Decurity.pdf` |
| Igor Gulamov | `1inch-cross-chain-swap-v1-Igor Gulamov.pdf` | `1inch-cross-chain-v2-Igor Gulamov.pdf` |
| OpenZeppelin | `1inch-cross-chain-swap-v1-Open Zeppelin.pdf` | `1inch-cross-chain-v2-Open Zeppelin.pdf` |
| Pessimistic | `1inch-cross-chain-swap-v1-Pessimistic.pdf` | `1inch-cross-chain-v2-Pessimistic.pdf` |

TODO(repository-review): confirm what the `v1` and `v2` file-name groups refer to — audit rounds on the same codebase, or two different revisions of it — and record the commit each round reviewed. Only the protocol team knows this; the file names alone do not settle it.

## [crosschain-fees-v1.1/](crosschain-fees-v1.1) — release 1.1.0

From [`Crosschain fees v1.1`](https://github.com/1inch/1inch-audits/tree/master/Crosschain%20fees%20v1.1), covering the settlement extension with fee support added in 1.1.0.

| Auditor | Report |
| ------------ | ------------------------------------------- |
| Certora | `1inch Crosschain Fee v1.1_Certora.pdf` |
| Decurity | `1inch Crosschain Fee v1.1_Decurity.pdf` |
| Hexens | `1inch Crosschain Fee v1.1_Hexens.pdf` |
| OpenZeppelin | `1inch Crosschain Fee v1.1_Open Zeppelin.pdf` |
| Sherlock | `1inch Crosschain Fee v1.1_Sherlock.pdf` |

## Keeping these current

A new audit lands in [1inch/1inch-audits](https://github.com/1inch/1inch-audits) first. When copying one here, keep the original file name, add it to the table above, and update the commit reference at the top of this file so the copies stay traceable to a single upstream revision.
