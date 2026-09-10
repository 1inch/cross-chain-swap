# Documentation

| Document | Contents |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| [protocol.md](protocol.md) | Protocol design: entities, swap lifecycle, timelocks, partial fills, and the functions a resolver calls |
| [fusion-plus-v1.pdf](fusion-plus-v1.pdf) | Fusion+ whitepaper |
| [timelocks.png](timelocks.png) | Diagram of the swap stages, referenced from `protocol.md` |

Two things are documented outside this directory. Per-function behaviour lives in the NatSpec next to the code — `yarn doc` renders it with `forge doc`, into the gitignored `documentation/` directory. Deployed addresses live in [deployments.md](../deployments.md), and the disclosure channel, bug bounty, audits and accepted risks in [SECURITY.md](../SECURITY.md).
