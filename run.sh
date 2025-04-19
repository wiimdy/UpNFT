#!/bin/bash
source .env

if [ "$1" == "start" ]; then
  echo "Starting the service..."
  # start 서비스 관련 명령어
  anvil > /dev/null 2>&1 &

elif [ "$1" == "script" ]; then
  echo "start the script..."
  forge script script/Auctions.s.sol:AuctionScript --rpc-url $RPC_URL -vvvv --account $ACCOUNT --sender $USERADDR --etherscan-api-key $ETHERSCAN_API_KEY --broadcast --verify

elif [ "$1" == "test" ]; then
  echo "start the test..."
  forge test --fork-url localhost:8545 --summary
  fi