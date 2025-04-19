// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "test/TestSetting.t.sol";

contract UtilTest is TestSetting {
    // 경매 생성자가 cancel 할 경우
    function testWhencancel() public {
        vm.prank(tester);
        auctions.cancelAuction(0);
        AuctionLogic.Auction memory info = auctions.getAuctioniList(0);
        assertEq(uint8(info.status), uint8(AuctionLogic.State.Canceled));
    }

    // 경매 생성자가 Listed 상태가 아닐 때 취소 할 경우
    function test_RevertNotListcancel() public {
        // Given: state가 Inprogress 일때
        vm.warp(block.timestamp + 2 days);
        vm.prank(tester);
        vm.expectRevert();
        auctions.cancelAuction(0);
    }

    // 최고 입찰자 자리를 뺏겨 입찰한 금액 회수하는 테스트
    function testWithdraw() public {
        // Given: auction 중 하나에 추가 베팅
        AuctionLogic.Auction memory info = auctions.getAuctioniList(0);
        vm.warp(info.startTime + 2 days);
        auctions.offerBid{value: 0.01 ether}(info.auctionId);

        info = auctions.getAuctioniList(0);
        auctions.offerBid{value: info.highestPrice + 0.001 ether}(info.auctionId);

        // When: 돌려받을 돈 금액을 계산하고 withdrawbid 실행 할 때
        uint256 amount = auctions.getBidreturn();
        auctions.withdrawBid();

        // Then: 제대로 결과 나오는지 확인
        assertEq(0.01 ether, amount);
    }

    // 실제로 swap이 잘 이루워지는지 테스트
    function testSwap() public {
        vm.deal(tester, 0.2 ether);
        vm.startPrank(tester);
        // swap에 돈을 보내야 함
        swap.swapETHToken{value: 0.1 ether}();
        token.approve(address(swap), 0.01 ether);
        swap.swapTokenETH(0.01 ether);
    }

    // 실제로 swap 보다 적게 approve해서 터지는 경우
    function test_RevertSwap() public {
        vm.deal(tester, 0.1 ether);
        vm.startPrank(tester);
        // swap에 돈을 보내야 함
        swap.swapETHToken{value: 0.01 ether}();
        token.approve(address(swap), 0.001 ether);
        vm.expectRevert();
        swap.swapTokenETH(0.01 ether);
    }

    function test_RevertNotProxy() public {
        AuctionLogic test = new AuctionLogic();
        vm.expectRevert();
        test.getauctionOwner();
    }

    receive() external payable {}
}
