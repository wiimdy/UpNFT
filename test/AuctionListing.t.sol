// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {UpToken} from "src/util/AuctionNFT.sol";
import {AuctionProxy} from "src/core/AuctionProxy.sol";
import {AuctionLogic} from "src/core/AuctionLogic.sol";
import {WDTOKEN, SwapToken} from "src/util/AuctionToken.sol";

contract ListingTest is Test {
    AuctionLogic public auctions;
    UpToken public uptoken;
    WDTOKEN public token;
    SwapToken public swap;
    AuctionLogic public logic;
    AuctionProxy public myAuction;
    address tester;
    /// 테스트 세팅
    /// 컨트랙트 생성후 NFT 생성까지

    function setUp() public {
        uint256 tokenId;
        address sender = vm.envAddress("OWNER");
        tester = address(0xDEADbeefdeadbeef);
        vm.startPrank(sender);

        auctions = AuctionLogic(payable(vm.envAddress("PROXYADDR")));
        swap = SwapToken(payable(vm.envAddress("SWAPADDR")));
        uptoken = UpToken(vm.envAddress("NFTADDR"));
        token = WDTOKEN(address(swap.token()));

        vm.deal(sender, 1 ether);
        swap.swapETHToken{value: 0.5 ether}();
        token.approve(address(uptoken), 500000000000000000);
        tokenId = uptoken.mint(tester);
        vm.stopPrank();
    }

    /// @dev NFT Listing이 잘되는지 확인하는 test
    function testListingNft() public {
        // Given: token minting이 되어 있는 상태
        uint256 tokenId = 1;
        // When: 제대로 등록할 때
        vm.prank(tester); //소유자만이 경매에 등록 할 수 있음
        uptoken.approve(address(auctions), tokenId);
        vm.prank(tester);
        uint256 auctionId = auctions.listingAuction(address(uptoken), tokenId, block.timestamp + 1 days, 0.001 ether);

        // then: 제대로 입력되었는지 확인
        AuctionLogic.Auction memory info = auctions.getAuctioniList(auctionId);
        assertEq(info.owner, tester);
        assertEq(info.tokenId, tokenId);
        assertEq(info.openPrice, 0.001 ether);
    }

    /// @dev NFT의 권한을 거래소에서 부여 안한 경우
    function test_RevertNotApprove() public {
        // Given: token minting이 되어 있는 상태
        uint256 tokenId = 1;

        // When: 권한 부여를 안하고 등록할 때
        vm.prank(tester); //소유자만이 경매에 등록 할 수 있음
        vm.expectRevert();

        auctions.listingAuction(address(uptoken), tokenId, block.timestamp + 1 days, 0.001 ether);
    }

    /// @dev 시작 시간이 현재보다 이전일 경우 revert
    function test_RevertAddTime() public {
        // Given: nft가 mint되었고 approve 된 상태
        uint256 tokenId = 1;
        vm.prank(tester);
        uptoken.approve(address(auctions), tokenId);

        // when: block.timestamp < startTime 일 경우
        vm.prank(tester);
        vm.expectRevert();
        auctions.listingAuction(address(uptoken), tokenId, block.timestamp - 1, 0.001 ether);
    }

    /// @dev 이미 등록된 nft를 또 등록할때 에러나는 테스트
    function test_RevertDupNFT() public {
        // Give: 이미 등록된 nft 경매 내역 가져옴
        uint256 tokenId = 1;

        vm.prank(tester);
        uptoken.approve(address(auctions), tokenId);
        vm.prank(tester);
        uint256 auctionId = auctions.listingAuction(address(uptoken), tokenId, block.timestamp + 1 days, 0.001 ether);

        uint256 _tokenId = auctions.getAuctioniList(auctionId).tokenId;
        address _owner = auctions.getAuctioniList(auctionId).owner;

        // when: 다시 등록할 경우
        vm.prank(_owner);
        vm.expectRevert();
        auctions.listingAuction(address(uptoken), _tokenId, block.timestamp + 1 days, 0.001 ether);
    }
}
