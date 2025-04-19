// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {UpToken} from "src/util/AuctionNFT.sol";
import {AuctionProxy} from "src/core/AuctionProxy.sol";
import {AuctionLogic} from "src/core/AuctionLogic.sol";
import {WDTOKEN, SwapToken} from "src/util/AuctionToken.sol";

contract TestSetting is Test {
    AuctionLogic public auctions;
    UpToken public uptoken;
    WDTOKEN public token;
    SwapToken public swap;
    AuctionLogic public logic;
    AuctionProxy public myAuction;
    address sender;
    address tester;

    /// 테스트 세팅
    /// 컨트랙트 생성후 실제 옥션 등록까지
    function setUp() public {
        uint256 tokenId;
        sender = vm.envAddress("OWNER");
        vm.startPrank(sender);
        tester = address(0xDEADbeefdeadbeef);

        auctions = AuctionLogic(payable(vm.envAddress("PROXYADDR")));
        swap = SwapToken(payable(vm.envAddress("SWAPADDR")));
        uptoken = UpToken(vm.envAddress("NFTADDR"));
        token = WDTOKEN(address(swap.token()));
        vm.deal(sender, 1 ether);
        swap.swapETHToken{value: 0.5 ether}();
        token.approve(address(uptoken), 500000000000000000);
        tokenId = uptoken.mint(tester);

        vm.stopPrank();
        // 소유권 넘기기 위해 msg.sender -> tester 변경
        vm.prank(tester);
        uptoken.approve(address(auctions), tokenId); // 경매 등록하기 위해서는 권한 부여 해야 함

        vm.prank(tester); //소유자만이 경매에 등록 할 수 있음
        auctions.listingAuction(address(uptoken), tokenId, block.timestamp + 1 days, 0.001 ether);
    }
}
