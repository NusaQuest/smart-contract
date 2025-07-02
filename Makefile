.PHONY: test compile coverage deploy verify

include .env

build:
	forge build

test:
	forge test -vv

coverage:
	forge coverage

format:
	forge fmt

deploy:
	forge script script/NusaQuestScript.s.sol:NusaQuest --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify	