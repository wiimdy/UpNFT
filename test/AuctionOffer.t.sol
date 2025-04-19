// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "test/TestSetting.t.sol";

contract OfferTest is TestSetting {
    /// @dev 실제로 offer가 잘들어가는지 test
    function testOfferbid() public {
        vm.warp(block.timestamp + 2 days);
        auctions.offerBid{value: 0.002 ether}(0);

        AuctionLogic.Auction memory info = auctions.getAuctioniList(0);
        // 실제로 잘 bid 되었는지 확인
        assertEq(info.highestBidder, address(this));
        assertEq(info.highestPrice, 0.002 ether);
    }

    /// @dev startTime 전에 offer 하는 경우
    function test_RevertNotInprogress() public {
        vm.expectRevert(); // offer할 때 process 체크
        auctions.offerBid{value: 0.002 ether}(0);
    }

    /// @dev 보낸 돈 보다 더 적게 입찰하는경우
    function test_Reverlowamount() public {
        vm.warp(block.timestamp + 2 days);
        vm.expectRevert();

        auctions.offerBids{value: 0.02 ether}(0, 0.021 ether);
    }

    /// @dev 현재 입찰가 보다 낮을 가격으로 입찰 하는 경우
    function test_RevertLowOffer() public {
        // Given 시간이 지난 후 입찰 프로세스 진행
        vm.warp(block.timestamp + 2 days);

        // When: 현재 입찰가보다 낮게 진행
        AuctionLogic.Auction memory info = auctions.getAuctioniList(0);

        vm.expectRevert();
        auctions.offerBid{value: info.highestPrice - 1}(0);
    }

    /// @dev Multioffer가 잘들어가는지 확인
    function testMultiOffer() public {
        uint256 sumAmount;
        uint256[] memory times = new uint256[](5);
        uint256[] memory prices = new uint256[](5);
        uint256[] memory auctionIds = new uint256[](5);
        address[] memory tokenaddrs = new address[](5);
        address[] memory toaddrs = new address[](5);

        for (uint256 i = 0; i < 5; i++) {
            toaddrs[i] = address(tester); // user addr
            times[i] = block.timestamp + 1 days;
            prices[i] = 0.001 ether + 0.001 ether * i;
        }

        // minting하려면 WDTOKEN 필요
        vm.prank(sender);
        uint256[] memory tokenIds = uptoken.multiMint(toaddrs);
        uint256[] memory bids = new uint256[](tokenIds.length);
        for (uint256 i = 0; i < 5; i++) {
            bids[i] = 0.002 ether + 0.001 ether * i;
            sumAmount += bids[i];
        }

        // multicall approve
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(tester); // 승인해야 해서 uptoken 소유자 계정으로 변경
            uptoken.approve(address(auctions), tokenIds[i]);
            tokenaddrs[i] = address(uptoken);
        }

        // multicall listing
        vm.prank(tester); // msg.sender가 token owner여야 함
        auctionIds = auctions.multiList(tokenaddrs, tokenIds, times, prices);
        // start time 지나야 함
        vm.warp(block.timestamp + 2 days);

        auctions.multiOffer{value: sumAmount}(auctionIds, bids);

        // 실제로 offer 잘 되었는지 확인
        for (uint256 i = 0; i < 5; i++) {
            AuctionLogic.Auction memory info = auctions.getAuctioniList(auctionIds[i]);
            assertEq(info.highestBidder, address(this));
            assertEq(info.highestPrice, bids[i]);
            assertEq(info.tokenId, tokenIds[i]);
        }
    }
}
