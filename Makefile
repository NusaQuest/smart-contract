.PHONY: test compile coverage deploy verify

include .env

build:
	forge build

test:
	forge test

coverage:
	forge coverage

format:
	forge fmt

deploy-verify:
	forge create --rpc-url ${RPC_URL} --etherscan-api-key ${ETHERSCAN_API_KEY} --verify --verifier ${VERIFIER} --verifier-url ${VERIFIER_URL} --private-key ${PRIVATE_KEY} script/NusaQuest.s.sol/NusaQuestScript