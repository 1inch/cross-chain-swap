-include .env

CURRENT_DIR := $(shell pwd)

update:; forge update

build:; forge build

build-zk :; FOUNDRY_PROFILE=zksync forge build --zksync -vvvvv --zk-compile=true --build-info --via-ir

tests :; forge test -vvv --gas-report

tests-zk :; FOUNDRY_PROFILE=zksync forge test -vvv --zksync --force

coverage :; mkdir -p coverage && FOUNDRY_PROFILE=default forge coverage --report lcov --ir-minimum --report-file coverage/lcov.info

coverage-zk :; mkdir -p coverage && RUST_BACKTRACE=full FOUNDRY_PROFILE=zksync forge coverage --zksync --report lcov --ir-minimum --via-ir --report-file coverage/lcov.info

snapshot :; forge snapshot --no-match-test "testFuzz_*"

snapshot-check :; forge snapshot --check --no-match-test "testFuzz_*"

format :; forge fmt

clean :; forge clean

lint :; yarn lint

anvil :;  anvil --fork-url $(FORK_URL) --steps-tracing --chain-id $(CHAIN_ID) --host 127.0.0.1 --port 8545 -vvvvv

withdraw-src :; forge script $(CURRENT_DIR)/script/txn_example/WithdrawSrc.s.sol:WithdrawSrc --rpc-url $(RPC_URL) --broadcast --slow

withdraw-dst :; forge script $(CURRENT_DIR)/script/txn_example/WithdrawDst.s.sol:WithdrawDst --rpc-url $(RPC_URL) --broadcast --slow

deploy-escrow-dst :; forge script $(CURRENT_DIR)/script/txn_example/DeployEscrowDst.s.sol:DeployEscrowDst --rpc-url $(RPC_URL) --broadcast --slow

deploy-escrow-src :; forge script $(CURRENT_DIR)/script/txn_example/DeployEscrowSrc.s.sol:DeployEscrowSrc --rpc-url $(RPC_URL) --broadcast --slow

# deploy-resolver-example :; forge script $(CURRENT_DIR)/script/DeployResolverExample.s.sol:DeployResolverExample --rpc-url $(RPC_URL) --broadcast --interactives 1 --slow

deploy-escrow-factory :; forge script $(CURRENT_DIR)/script/DeployEscrowFactory.s.sol:DeployEscrowFactory --rpc-url $(RPC_URL) --broadcast --interactives 1 --slow

cancel-src :; forge script $(CURRENT_DIR)/script/txn_example/CancelSrc.s.sol:CancelSrc --rpc-url $(RPC_URL) --broadcast --slow

cancel-dst :; forge script $(CURRENT_DIR)/script/txn_example/CancelDst.s.sol:CancelDst --rpc-url $(RPC_URL) --broadcast --slow

balance :; cast balance $(ADDRESS) --rpc-url $(RPC_URL) | cast from-wei

balance-erc20 :; cast call $(TOKEN) "balanceOf(address)(uint256)" $(ADDRESS) --rpc-url $(RPC_URL) | cast from-wei

resolver-balance :; $(MAKE) ADDRESS=$(RESOLVER) balance

resolver-balance-erc20 :; $(MAKE) ADDRESS=$(RESOLVER) TOKEN=$(TOKEN_SRC) balance-erc20

deployer-balance :; $(MAKE) ADDRESS=$(DEPLOYER_ADDRESS) balance

deployer-balance-erc20 :; $(MAKE) ADDRESS=$(DEPLOYER_ADDRESS) TOKEN=$(TOKEN_SRC) balance-erc20

protocol-balance :; $(MAKE) ADDRESS=$(PROTOCOL_FEE_RECIPIENT) balance

protocol-balance-erc20 :; $(MAKE) ADDRESS=$(PROTOCOL_FEE_RECIPIENT) TOKEN=$(TOKEN_SRC) balance-erc20

integrator-balance :; $(MAKE) ADDRESS=$(INTEGRATOR_FEE_RECIPIENT) balance

integrator-balance-erc20 :; $(MAKE) ADDRESS=$(INTEGRATOR_FEE_RECIPIENT) TOKEN=$(TOKEN_SRC) balance-erc20

escrow-src-balance :; $(MAKE) ADDRESS=$(ESCROW_SRC) balance

escrow-src-balance-erc20 :; $(MAKE) ADDRESS=$(ESCROW_SRC) TOKEN=$(TOKEN_SRC) balance-erc20

escrow-dst-balance :; $(MAKE) ADDRESS=$(ESCROW_DST) balance

escrow-dst-balance-erc20 :; $(MAKE) ADDRESS=$(ESCROW_DST) TOKEN=$(TOKEN_SRC) balance-erc20

help:
	@echo "Available targets:"
	@grep -E '^[a-zA-Z0-9_.-]+ *:.*?;' $(CURRENT_DIR)/Makefile | awk -F: '{print "  " $$1}'

..PHONY: update build build-zk tests tests-zk coverage snapshot snapshot-check format clean anvil withdraw-src withdraw-dst deploy-escrow-dst deploy-escrow-src deploy-escrow-factory cancel-src cancel-dst balance balance-erc20 resolver-balance resolver-balance-erc20 deployer-balance deployer-balance-erc20 protocol-balance protocol-balance-erc20 integrator-balance integrator-balance-erc20 escrow-src-balance escrow-src-balance-erc20 escrow-dst-balance escrow-dst-balance-erc20