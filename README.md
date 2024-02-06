# Cross-Chain-Swap

[![Build Status](https://github.com/1inch/cross-chain-swap/workflows/CI/badge.svg)](https://github.com/1inch/cross-chain-swap/actions)
[![Coverage Status](https://codecov.io/gh/1inch/cross-chain-swap/graph/badge.svg?token=gOb8pdfcxg)](https://codecov.io/gh/1inch/cross-chain-swap)

## Installation

This project uses [Foundry](https://github.com/foundry-rs/foundry) for smart contract development in Solidity. Foundry is a fast, portable, and modular toolkit designed to compile, test, and deploy Solidity contracts.

### Prerequisites

- Ensure you have [Rust](https://www.rust-lang.org/tools/install) installed.
- To [install Foundry](https://book.getfoundry.sh/getting-started/installation), including the `forge` tool, follow these steps:

  ``` shell
  # Install Foundryup:
  curl -L https://foundry.paradigm.xyz | bash
  
  # Apply updated config to current terminal session
  source ~/.zshenv
  
  # Install forge, cast, anvil, and chisel
  foundryup
  ```

### Update submodules

To init and update submodules run:

``` shell
git submodule update --init --recursive
```

## Tests

To execute tests run:

``` shell
yarn test
```
