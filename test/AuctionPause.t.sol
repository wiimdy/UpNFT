// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "test/TestSetting.t.sol";

contract PauseTest is TestSetting {
    /// @dev contract가 pause 되는지 테스트
    function testEmergencyStop() public {
        // Given: 경매가 시작된 상태
        vm.warp(block.timestamp + 2 days);
        auctions.offerBid{value: 0.002 ether}(0);

        // When: emergency pause 발생 소유주만 가능
        vm.prank(sender);
        auctions.stopContract();

        // Then: 잘 되었는지 확인
        assertEq(auctions.paused(), true);
    }

    /// @dev contract가 소유자가 아닌 다른사람이 pause 실행하는 함수
    function test_RevertNotownerPause() public {
        // Given: 경매가 시작된 상태
        vm.warp(block.timestamp + 2 days);
        auctions.offerBid{value: 0.002 ether}(0);

        // When: 소유자가 아닌 계정이 pause 발생
        vm.prank(tester);
        vm.expectRevert();
        auctions.stopContract();
    }

    /// @dev contract가 pause 된 상태에서 경매 등록 하는 테스트
    function test_RevertwhenListing() public {
        // Given: auction contract가 pause 한 상태
        vm.warp(block.timestamp + 2 days);
        auctions.offerBid{value: 0.002 ether}(0);
        vm.prank(sender);
        auctions.stopContract();

        // When: 경매 등록 시도 할 경우
        vm.prank(sender);
        uint256 tokenId = uptoken.mint(tester);
        vm.prank(tester);
        uptoken.approve(address(auctions), tokenId);
        vm.prank(tester);

        vm.expectRevert();
        auctions.listingAuction(address(uptoken), tokenId, block.timestamp + 2 days, 0.001 ether);
    }

    /// @dev contract가 pause 된 상태에서 경매 Offer 하는 테스트
    function test_RevertWhenOffer() public {
        // Given: auction contract가 pause 한 상태
        vm.warp(block.timestamp + 2 days);
        auctions.offerBid{value: 0.002 ether}(0);
        vm.prank(sender);
        auctions.stopContract();
        // When: 경매 Offer 시도 할 경우
        vm.expectRevert();
        auctions.offerBid{value: 0.002 ether}(0);
    }

    /// @dev contract가 pause 된 상태에서 실행중인 경매 입찰자에게 돈 환불
    function testEmergencyWithdraw() public {
        // Given: auction contract가 pause 한 상태
        vm.warp(block.timestamp + 2 days);
        auctions.offerBid{value: 0.002 ether}(0);
        vm.prank(sender);
        auctions.stopContract();

        // When: 경매 Offer 시도 할 경우
        uint256 beforePause = address(this).balance;
        auctions.emergencyWithdraw(0);
        uint256 afterPause = address(this).balance;

        // Then: 금액이 정확히 일치하는지 확인
        assertEq(beforePause + 0.002 ether, afterPause);
    }

    receive() external payable {}
}
