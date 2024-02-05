# Cross-Chain-Swap

[![Build Status](https://github.com/1inch/cross-chain-swap/workflows/CI/badge.svg)](https://github.com/1inch/cross-chain-swap/actions)
[![Coverage Status](https://codecov.io/gh/1inch/cross-chain-swap/graph/badge.svg?token=gOb8pdfcxg)](https://codecov.io/gh/1inch/cross-chain-swap)

## Installation

This project uses [Foundry](https://github.com/foundry-rs/foundry) for smart contract development in Solidity. Foundry is a fast, portable, and modular toolkit designed to compile, test, and deploy Solidity contracts.

### Prerequisites

- Ensure you have [Rust](https://www.rust-lang.org/tools/install) installed, as it is required for compiling Foundry from source.
- Install Foundry, including the `forge` tool, follow these steps:

  ```
  # install:
  curl -L https://foundry.paradigm.xyz | bash
  
  # add foundry to PATH env
  export PATH="$HOME/.foundry/bin:$PATH"
  source ~/.bashrc
  # source ~/.zshrc
  
  # update foundry
  foundryup
  ```

### Update submodules

To init and update submodules run:

```
git submodule update --init --recursive
```

## Tests

To install dependencies and execute tests run:

```
yarn && yarn test
```
