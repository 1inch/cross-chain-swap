# Changes from Version 1.0.0 to 1.1.0

Based on my analysis of the git history and file changes, here's a comprehensive overview of what's new in the cross-chain swap project since version 1.0.0:

## Major Features and Enhancements

### 1. Settlement Extension with Fee Support (PR #131)

- __Fee Structure Implementation__: Added comprehensive fee support with integrator fees, protocol fees, and resolver fees
- __SimpleSettlement Integration__: Replaced `ResolverValidationExtension` with `SimpleSettlement` from limit-order-settlement
- __Fee Recipients__: Added support for integrator and protocol fee recipients in the extraData structure
- __Whitelist Discount__: Implemented whitelist discount numerator for fee calculations

### 2. Demo Script and Examples

- __Complete Lifecycle Demo__: Added comprehensive demo script showing the full cross-chain swap lifecycle
- __Automated Testing__: Created `create_order.sh` script for automated deployment and testing
- __Configuration Management__: Moved sensitive parameters (private keys, RPC URLs) from config.json to .env file
- __Stage-based Execution__: Supports configurable stages including deployment, withdrawal, and cancellation

### 3. Gas Optimizations

- __Assembly Optimization__: Implemented assembly code for hash computation, improving gas efficiency by ~500 gas (median)
- __Immutables Library Enhancement__: Optimized the ImmutablesLib contract for better performance

### 4. Testing Enhancements

- __Taking Amount Tests__: Added tests to verify orders with taking amount set (PR #133)
- __Fee Calculation Tests__: New test suite for fee calculations
- __Escrow Cancel Tests__: Separated cancel functionality tests into dedicated test file
- __Integration Tests__: Expanded integration tests for getters and rescue funds functionality

## Infrastructure and Development Experience

### 1. Build Automation

- __Makefile Addition__: Added comprehensive Makefile to simplify script execution
- __Common Commands__: Includes targets for testing, coverage, deployment, and more

### 2. Documentation and Templates

- __Pull Request Template__: Added GitHub PR template for better contribution management
- __Disclaimer__: Added disclaimer for ResolverExample mock contract
- __Enhanced README__: Updated with partial fills documentation

### 3. CI/CD Improvements

- __Fixed CI Pipeline__: Resolved issues with the CI workflow
- __Removed zkSync Coverage__: Temporarily removed coverage-zk stage due to unresolved forge issues

## Technical Changes

### 1. Contract Updates

- __BaseEscrowFactory__: Major refactoring to support fees and SimpleSettlement
- __Escrow Contracts__: Updated to handle new fee parameters and immutable structures
- __ImmutablesLib__: Reunified immutable structures and optimized with assembly

### 2. Test Refactoring

- __Unit Test Split__: Separated Escrow.t.sol into focused test files (reduced from 534 to more manageable sizes)
- __New Test Utilities__: Added FeeCalcLib, CustomPostInteraction, and NoReceive mocks

### 3. Dependency Updates

- Updated all git submodules (forge-std, limit-order-protocol, limit-order-settlement, murky, openzeppelin-contracts, solidity-utils)
