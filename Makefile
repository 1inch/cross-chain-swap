# Conditionally include .env or .env.automation based on OPS_LAUNCH_MODE
ifeq ($(OPS_LAUNCH_MODE),auto)
-include .env.automation
else
-include .env
endif
export

CURRENT_DIR:=$(shell pwd)

FILE_CONSTANTS_JSON:=$(CURRENT_DIR)/config/constants.json

OPS_NETWORK := $(subst ",,$(OPS_NETWORK))
OPS_CHAIN_ID := $(subst ",,$(OPS_CHAIN_ID))
OPS_VERIFIER := $(subst ",,$(OPS_VERIFIER))
OPS_ETHERSCAN_URL := $(subst ",,$(OPS_ETHERSCAN_URL))

ifeq ("$(OPS_VERIFIER)",)
	OPS_VERIFIER := etherscan
	ifneq ("$(findstring zksync,$(OPS_NETWORK))","")
		OPS_VERIFIER := zksync
	endif
endif

FILE_FACTORY_NAME := EscrowFactory

ifneq ("$(findstring zksync,$(OPS_NETWORK))", "")
	FILE_FACTORY_NAME := EscrowFactoryZkSync
endif

PREFIX:=$(shell echo "$(OPS_NETWORK)" | sed -r 's/([a-z0-9])([A-Z])/\1_\2/g' | tr '[:lower:]' '[:upper:]')
REGOP_ENV_RPC_URL:=$(PREFIX)_RPC_URL
REGOP_ENV_PK:=$(PREFIX)_PRIVATE_KEY

RPC_URL=$(shell echo "$${!REGOP_ENV_RPC_URL}" | tr -d '"')
PRIVATE_KEY=$(shell echo "$${!REGOP_ENV_PK}" | tr -d '"')

COMPILER_VERSION:=$(shell cat foundry.toml | grep 'solc_version =' | head -1 | awk -F'"' '{print $$2}')

ANVIL_HOST:=http://127.0.0.1
ANVIL_PORT:=8545

deploy-escrow-factory:
	@$(MAKE) CONSTRUCTOR_ARGS=$(shell $(MAKE) constructor-args) FILE_DEPLOY_NAME=$$FILE_FACTORY_NAME validate-escrow-factory deploy-escrow-factory-impl save-deployments verify-impl

deploy-true-token:
	@$(MAKE) CONSTRUCTOR_ARGS=0x FILE_DEPLOY_NAME=ERC20True validate-true-token deploy-true-token-impl save-deployments verify-impl

deploy-escrow-factory-impl:
	@{ \
	    $(MAKE) ID=FILE_DEPLOY_NAME validate || exit 1; \
		if [ "$(findstring zksync,$(OPS_NETWORK))" = "" ]; then \
			forge script $(CURRENT_DIR)/script/Deploy$${FILE_DEPLOY_NAME}.s.sol:Deploy$${FILE_DEPLOY_NAME} \
				--rpc-url $(RPC_URL) \
				--private-key $(PRIVATE_KEY) \
				--broadcast -vvvv; \
		else \
			forge script $(CURRENT_DIR)/script/Deploy$${FILE_DEPLOY_NAME}.s.sol:Deploy$${FILE_DEPLOY_NAME} --zksync \
				--rpc-url $(RPC_URL) \
				--private-key $(PRIVATE_KEY) \
				--broadcast -vvvv; \
		fi; \
	}

deploy-true-token-impl:
	@forge script $(CURRENT_DIR)/script/DeployERC20True.s.sol:DeployERC20True \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast -vvvv

verify-impl:
	@{ \
		if [ "$(OPS_CHAIN_ID)" = "31337" ]; then \
			exit 0; \
		else \
			DEPLOYMENT_FILE="$(CURRENT_DIR)/deployments/$(OPS_NETWORK)/$${FILE_DEPLOY_NAME}.json"; \
			CONTRACT_ADDRESS=$$($(MAKE) contract-address DEPLOYMENT_FILE=$$DEPLOYMENT_FILE); \
			echo "Verifying contract $${FILE_DEPLOY_NAME} at address: $${CONTRACT_ADDRESS} on $(OPS_ETHERSCAN_URL) using verifier $(OPS_VERIFIER) with compiler version $${COMPILER_VERSION} and constructor args $${CONSTRUCTOR_ARGS}"; \
			forge verify-contract --chain-id $(OPS_CHAIN_ID) \
				--compiler-version $${COMPILER_VERSION} \
				--constructor-args $${CONSTRUCTOR_ARGS} \
				--verifier $(OPS_VERIFIER) \
				--verifier-url $(OPS_ETHERSCAN_URL) \
				--verifier-api-key $(ETHERSCAN_API_KEY) \
				$${CONTRACT_ADDRESS} \
				$(CURRENT_DIR)/contracts/$${FILE_DEPLOY_NAME}.sol:$${FILE_DEPLOY_NAME}; \
		fi; \
	}

# Helper targets
save-deployments:
	@{ \
		$(MAKE) ID=FILE_DEPLOY_NAME validate || exit 1; \
		DEPLOYMENT_FILE="$(CURRENT_DIR)/broadcast/Deploy$${FILE_DEPLOY_NAME}.s.sol/$(OPS_CHAIN_ID)/run-latest.json"; \
		DIRECTORY="$(CURRENT_DIR)/deployments/$(OPS_NETWORK)"; \
		mkdir -p $$DIRECTORY; \
		if [ -f $$DEPLOYMENT_FILE ]; then \
			cp -f $$DEPLOYMENT_FILE "$${DIRECTORY}/$${FILE_DEPLOY_NAME}.json"; \
		else \
			echo "Deployment file $$DEPLOYMENT_FILE does not exist!"; \
			exit 1; \
		fi; \
	}

constructor-args:
	@echo $(shell cast abi-encode "constructor(address,address,address,uint32,uint32)" \
		$(shell jq -r --arg id "$(OPS_CHAIN_ID)" '.lop[$$id]' $(FILE_CONSTANTS_JSON)) \
		$(shell jq -r --arg id "$(OPS_CHAIN_ID)" '.accessToken[$$id]' $(FILE_CONSTANTS_JSON)) \
		$(shell jq -r --arg id "$(OPS_CHAIN_ID)" '.factoryOwner[$$id]' $(FILE_CONSTANTS_JSON)) \
		691200 \
		691200 \
	)

contract-address:
	@{ \
		$(MAKE) ID=DEPLOYMENT_FILE validate || exit 1; \
		if [ "$(findstring zksync,$(OPS_NETWORK))" = "" ]; then \
			SALT=$$(jq -r '.transactions[0].arguments[0]' $(DEPLOYMENT_FILE)); \
			DEPLOYER_ADDRESS=$$(echo "$${OPS_CREATE3_DEPLOYER_ADDRESS}" | tr -d '"'); \
			echo $$(cast call $${DEPLOYER_ADDRESS} "addressOf(bytes32)(address)" $${SALT} --rpc-url $${!REGOP_ENV_RPC_URL}); \
		else \
			echo $$(jq -r '.transactions[0].contractAddress' $(DEPLOYMENT_FILE)); \
		fi; \
	}

# Validation targets
validate-escrow-factory:
		@{ \
		$(MAKE) ID=OPS_NETWORK validate || exit 1; \
		$(MAKE) ID=OPS_CHAIN_ID validate || exit 1; \
		$(MAKE) ID=OPS_FACTORY_OWNER_ADDRESS validate || exit 1; \
		$(MAKE) ID=OPS_LOP_ADDRESS validate || exit 1; \
		$(MAKE) ID=OPS_ACCESS_TOKEN_ADDRESS validate || exit 1; \
		if [ "$(findstring zksync,$(OPS_NETWORK))" = "" ]; then \
			$(MAKE) ID=OPS_FACTORY_SALT validate || exit 1; \
			$(MAKE) ID=OPS_CREATE3_DEPLOYER_ADDRESS validate || exit 1; \
		fi; \
		$(MAKE) process-factory-owner process-lop process-access-token process-factory-salt process-create3-deployer; \
		}

validate-true-token:
		@{ \
		$(MAKE) ID=OPS_NETWORK validate || exit 1; \
		$(MAKE) ID=OPS_CHAIN_ID validate || exit 1; \
		if [ "$(findstring zksync,$(OPS_NETWORK))" = "" ]; then \
			$(MAKE) ID=OPS_CREATE3_DEPLOYER_ADDRESS validate || exit 1; \
			$(MAKE) ID=OPS_TRUE_TOKEN_SALT validate || exit 1; \
		fi; \
		$(MAKE) process-true-token-salt process-create3-deployer; \
		}

validate:
		@{ \
			VALUE=$$(echo "$${!ID}" | tr -d '"'); \
			if [ -z "$${VALUE}" ]; then \
				echo "$${ID} is not set (Value: '$${VALUE}')!"; \
				exit 1; \
			fi; \
		}

if_not_empty:
		@{ \
			VALUE=$$(echo "$${!ID}" | tr -d '"'); \
			if [ -n "$${VALUE}" ]; then \
				echo "$${ID} is set to: $${VALUE}"; \
			fi; \
		}

# Process constant functions for new addresses
process-create3-deployer:
		@$(MAKE) ID=OPS_CREATE3_DEPLOYER_ADDRESS if_not_empty && $(MAKE) OPS_GEN_VAL='$(OPS_CREATE3_DEPLOYER_ADDRESS)' OPS_GEN_KEY='create3Deployer' upsert-constant

process-factory-owner:
		@$(MAKE) OPS_GEN_VAL='$(OPS_FACTORY_OWNER_ADDRESS)' OPS_GEN_KEY='factoryOwner' upsert-constant

process-lop:
		@$(MAKE) OPS_GEN_VAL='$(OPS_LOP_ADDRESS)' OPS_GEN_KEY='lop' upsert-constant

process-access-token:
		@$(MAKE) OPS_GEN_VAL='$(OPS_ACCESS_TOKEN_ADDRESS)' OPS_GEN_KEY='accessToken' upsert-constant

process-factory-salt:
		@$(MAKE) ID=OPS_FACTORY_SALT if_not_empty && $(MAKE) OPS_GEN_VAL='$(OPS_FACTORY_SALT)' OPS_GEN_KEY='factorySalt' upsert-constant

process-true-token-salt:
		@$(MAKE) ID=OPS_TRUE_TOKEN_SALT if_not_empty && $(MAKE) OPS_GEN_VAL='$(OPS_TRUE_TOKEN_SALT)' OPS_GEN_KEY='trueTokenSalt' upsert-constant

upsert-constant:
		@{ \
		$(MAKE) ID=OPS_GEN_VAL validate || exit 1; \
		$(MAKE) ID=OPS_GEN_KEY validate || exit 1; \
		$(MAKE) ID=OPS_CHAIN_ID validate || exit 1; \
		tmpfile=$$(mktemp); \
		jq '.$(OPS_GEN_KEY)."$(OPS_CHAIN_ID)" = $(OPS_GEN_VAL)' $(FILE_CONSTANTS_JSON) > $$tmpfile && mv $$tmpfile $(FILE_CONSTANTS_JSON); \
		echo "Updated $(OPS_GEN_KEY)[$(OPS_CHAIN_ID)] = $(OPS_GEN_VAL)"; \
		}

# Get deployed contract addresses from deployment files
get:
		@{ \
		$(MAKE) ID=PARAMETER validate || exit 1; \
		$(MAKE) ID=OPS_NETWORK validate || exit 1; \
		if [ ! -d "$(CURRENT_DIR)/deployments/$(OPS_NETWORK)" ]; then \
			echo "Error: Directory $(CURRENT_DIR)/deployments/$(OPS_NETWORK) does not exist"; \
			exit 1; \
		fi; \
		CONTRACT_FILE=""; \
		contracts_list=$$(ls $(CURRENT_DIR)/deployments/$(OPS_NETWORK)/*.json | xargs -n1 basename | sed 's/\.json$$//'); \
		found=0; \
		for contract in $$contracts_list; do \
			contract_upper=$$(echo $$contract | sed 's/\([A-Z][a-z]\)/_\1/g' | sed 's/^_//' | tr 'a-z' 'A-Z'); \
			if [ "$(PARAMETER)" = "OPS_$${contract_upper}_ADDRESS" ]; then \
				CONTRACT_FILE="$${contract}.json"; \
				found=1; \
				break; \
			fi; \
		done; \
		if [ "$$found" -eq 0 ]; then \
			echo "Error: Unknown parameter $(PARAMETER)"; exit 1; \
		fi; \
		DEPLOYMENT_FILE="$(CURRENT_DIR)/deployments/$(OPS_NETWORK)/$$CONTRACT_FILE"; \
		if [ ! -f "$$DEPLOYMENT_FILE" ]; then \
			echo "Error: Deployment file $$DEPLOYMENT_FILE not found"; \
			exit 1; \
		fi; \
		ADDRESS=$$($(MAKE) contract-address DEPLOYMENT_FILE=$$DEPLOYMENT_FILE); \
		echo "$$ADDRESS"; \
		}

launch-anvil:
		@anvil --fork-url $(RPC_URL) --steps-tracing --chain-id 31337 --host $(ANVIL_HOST) --port $(ANVIL_PORT) -vvvvv

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
		@grep -E '^[a-zA-Z0-9_.-]+:' $(CURRENT_DIR)/Makefile | grep -v '^\.' | awk -F: '{print "  " $$1}' | sort -u

.PHONY: update build build-zk tests tests-zk coverage coverage-zk snapshot snapshot-check format clean lint anvil \
	deploy-escrow-factory deploy-true-token deploy-escrow-factory-impl deploy-true-token-impl \
	verify-impl constructor-args contract-address \
	withdraw-src withdraw-dst deploy-escrow-dst deploy-escrow-src cancel-src cancel-dst \
	balance balance-erc20 resolver-balance resolver-balance-erc20 deployer-balance deployer-balance-erc20 \
	protocol-balance protocol-balance-erc20 integrator-balance integrator-balance-erc20 \
	escrow-src-balance escrow-src-balance-erc20 escrow-dst-balance escrow-dst-balance-erc20 \
	validate-escrow-factory validate-true-token validate if_not_empty \
	process-create3-deployer process-factory-owner process-lop process-access-token \
	process-factory-salt process-true-token-salt upsert-constant launch-anvil help
