# Changelog

Notable changes to this repository, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [semantic versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-01-26

From the [v1.1.0 GitHub Release](https://github.com/1inch/cross-chain-swap/releases/tag/1.1.0). Full diff: [1.0.0...1.1.0](https://github.com/1inch/cross-chain-swap/compare/1.0.0...1.1.0).

### Added

- Settlement extension with fee support: integrator, protocol and resolver fees; fee recipients in `extraData`; whitelist discount numerator ([#131](https://github.com/1inch/cross-chain-swap/pull/131))
- Demo script for the full cross-chain lifecycle, plus `create_order.sh` with stage-based deploy / withdraw / cancel ([#134](https://github.com/1inch/cross-chain-swap/pull/134))
- Tests for orders with taking amount set ([#133](https://github.com/1inch/cross-chain-swap/pull/133)); fee-calculation suite; dedicated escrow cancel tests; expanded integration coverage for getters and rescue funds
- Pull request template; `ResolverExample` disclaimer; README partial-fills documentation



### Changed

- Replaced `ResolverValidationExtension` with `SimpleSettlement` from limit-order-settlement ([#131](https://github.com/1inch/cross-chain-swap/pull/131))
- `BaseEscrowFactory` and escrow contracts updated for fee parameters and immutable structures; `ImmutablesLib` reunified and optimized with assembly (~500 gas median on hash paths)
- Sensitive demo parameters moved from `config.json` to `.env`
- Escrow unit tests split into focused files; added `FeeCalcLib`, `CustomPostInteraction`, and `NoReceive` test utilities
- Deployment scripts updated ([#141](https://github.com/1inch/cross-chain-swap/pull/141))
- Git submodules updated (forge-std, limit-order-protocol, limit-order-settlement, murky, openzeppelin-contracts, solidity-utils)



### Fixed

- Fixes after OpenZeppelin audit review ([#138](https://github.com/1inch/cross-chain-swap/pull/138))
- Removed explicit cast for receivers ([#139](https://github.com/1inch/cross-chain-swap/pull/139))
- CI pipeline fixes; zkSync coverage stage temporarily removed due to forge issues



## [1.0.0] - 2024-09-04

Initial release.