# Changes from Version 1.0.0 to 1.1.0

Based on my analysis of the git history and file changes, here's a comprehensive overview of what's new in the cross-chain swap project since version 1.0.0:

## Major Features and Enhancements

### 1. Settlement Extension with Fee Support (PR #131)

- **Fee Structure Implementation**: Added comprehensive fee support with integrator fees, protocol fees, and resolver fees
- **SimpleSettlement Integration**: Replaced `ResolverValidationExtension` with `SimpleSettlement` from limit-order-settlement
- **Fee Recipients**: Added support for integrator and protocol fee recipients in the extraData structure
- **Whitelist Discount**: Implemented whitelist discount numerator for fee calculations

### 2. Demo Script and Examples

- **Complete Lifecycle Demo**: Added comprehensive demo script showing the full cross-chain swap lifecycle
- **Automated Testing**: Created `create_order.sh` script for automated deployment and testing
- **Configuration Management**: Moved sensitive parameters (private keys, RPC URLs) from config.json to .env file
- **Stage-based Execution**: Supports configurable stages including deployment, withdrawal, and cancellation

### 3. Gas Optimizations

- **Assembly Optimization**: Implemented assembly code for hash computation, improving gas efficiency by ~500 gas (median)
- **Immutables Library Enhancement**: Optimized the ImmutablesLib contract for better performance

### 4. Testing Enhancements

- **Taking Amount Tests**: Added tests to verify orders with taking amount set (PR #133)
- **Fee Calculation Tests**: New test suite for fee calculations
- **Escrow Cancel Tests**: Separated cancel functionality tests into dedicated test file
- **Integration Tests**: Expanded integration tests for getters and rescue funds functionality

## Infrastructure and Development Experience

### 1. Build Automation

- **Makefile Addition**: Added comprehensive Makefile to simplify script execution
- **Common Commands**: Includes targets for testing, coverage, deployment, and more

### 2. Documentation and Templates

- **Pull Request Template**: Added GitHub PR template for better contribution management
- **Disclaimer**: Added disclaimer for ResolverExample mock contract
- **Enhanced README**: Updated with partial fills documentation

### 3. CI/CD Improvements

- **Fixed CI Pipeline**: Resolved issues with the CI workflow
- **Removed zkSync Coverage**: Temporarily removed coverage-zk stage due to unresolved forge issues

## Technical Changes

### 1. Contract Updates

- **BaseEscrowFactory**: Major refactoring to support fees and SimpleSettlement
- **Escrow Contracts**: Updated to handle new fee parameters and immutable structures
- **ImmutablesLib**: Reunified immutable structures and optimized with assembly

### 2. Test Refactoring

- **Unit Test Split**: Separated Escrow.t.sol into focused test files (reduced from 534 to more manageable sizes)
- **New Test Utilities**: Added FeeCalcLib, CustomPostInteraction, and NoReceive mocks

### 3. Dependency Updates

- Updated all git submodules (forge-std, limit-order-protocol, limit-order-settlement, murky, openzeppelin-contracts, solidity-utils)
