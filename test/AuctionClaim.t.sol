// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "test/TestSetting.t.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract ClaimTest is TestSetting {
    /// @dev 정상적인 bid 완료 후 토큰과 이더 교환 하는 테스트
    function testEndBid() public {
        uint256 auctionId = 0;
        // Given: 경매 시작후 bidder가 offer 넣고 경매 종료
        vm.warp(block.timestamp + 3 days);
        receiveContract bider = new receiveContract();
        payable(address(bider)).transfer(0.03 ether);
        vm.prank(address(bider));
        auctions.offerBid{value: 0.02 ether}(auctionId);
        vm.warp(block.timestamp + 1 days + 1);

        /// When: Bidder가 claim 실행
        vm.prank(address(bider));
        auctions.claim(auctionId);

        // 상태가 종료인지 체크
        assertEq(uint256(auctions.getState(auctionId)), uint256(AuctionLogic.State.Completed));

        // 거래자가 실제로 tokenId 오너인지 확인
        assertEq(
            address(bider),
            IERC721(auctions.getAuctioniList(auctionId).tokenAddress).ownerOf(
                auctions.getAuctioniList(auctionId).tokenId
            )
        );
    }

    /// @dev 상태가 completed 되지 않은 상황에서 claim 하는 테스트
    function test_RevertNotComplete() public {
        // Given: 경매 시작 후 비드
        uint256 auctionId = 0;
        vm.warp(block.timestamp + 3 days);
        receiveContract bider = new receiveContract();
        payable(address(bider)).transfer(0.03 ether);
        vm.prank(address(bider));
        auctions.offerBid{value: 0.02 ether}(auctionId);

        // When: 경매가 끝나지 않은 상태에서 claim 진행
        vm.prank(address(bider));
        vm.expectRevert();
        auctions.claim(auctionId);
    }

    /// @dev claim 이후 반복되서 claim이 들어오는 테스트
    function test_RevertDoubleClaim() public {
        uint256 auctionId = 0;
        // Given: 경매 비드 후 경매 종료
        vm.warp(block.timestamp + 3 days);

        receiveContract bider = new receiveContract(); // uptoken 받을 때 필요한 함수 있는 contract
        payable(address(bider)).transfer(0.03 ether);
        vm.prank(address(bider));
        auctions.offerBid{value: 0.02 ether}(auctionId);
        vm.warp(block.timestamp + 1 days + 1); // bid 종료

        vm.prank(address(bider));
        auctions.claim(auctionId);

        //When: 이미 claim을 통해 거래가 완료 되었지만 다시 발생
        vm.prank(address(bider));
        vm.expectRevert();
        auctions.claim(auctionId);
    }

    receive() external payable {}
}

contract receiveContract is IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }

    receive() external payable {}
}
