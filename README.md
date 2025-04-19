## Upside NFT Auction Project - wiimdy

## project 배포 법
- `./build.sh start`  처음 시작할 때 로컬네트워크로 연결 하여 배포 시작

## script 배포
- `./build.sh script`  실행하기 이때 꼭 env 파일 확인해서 어디에 배포되는지 확인하기
- verify 필요하면 넣기 잘 안되긴함
### remote deploy
`forge script script/Auctions.s.sol:AuctionScript --rpc-url $RPC_URL -vvvv --account $ACCOUNT --sender $USERADDR --etherscan-api-key $ETHERSCAN_API_KEY --broadcast --verify`

## test 하는 법
- `./build.sh test` test 폴더의 파일 시작

### local test
`forge test --fork-url localhost:8545 --summary`
### 배포된 네트워크로 테스트 하는법
1. `anvil --fork-url https://base-sepolia.infura.io/v3`
2. 주소와 owner 배포된 네트워크로 설정
- env 파일의 Owner, contract 주소 remote와 일치하게 만들기

### .env 파일 만들기
- 예시 
```plaintext
# test 파일에 들어가는 변수 설정
OWNER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
PROXYADDR=0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE
SWAPADDR=0x3Aa5ebB10DC797CAC828524e59A333d0A371443c
NFTADDR=0x322813Fd9A801c5507c9de605d63CEA4f2CE6c44

## 실제 스크립트에 들어가는 변수 설정  (로컬)
RPC_URL="http://localhost:8545"
ACCOUNT=local
USERADDR=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

## 실제 스크립트에 들어가는 변수 설정  (base-sepolia)
# RPC_URL="https://base-sepolia.infura.io/v3/##################"
# ACCOUNT=wiimdy
# USERADDR=########################################
```
스크립트로 배포하고 나오는 로그로 
여기서 owner, proxyaddr, swapaddr, neftaddr 꼭 수정하기!!!

