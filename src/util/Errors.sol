// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

library Errors {
    /// msg.sender가 nft owner가 아니다.
    error NotNFTOwner();

    /// msg.sender가 auction owner가 아니다
    error NotAuctionOwner(address sender);

    /// 전송과정에 false가 났다.
    error transferError();

    /// 상태가 inprogress가 아니다.
    error NotInprogress();

    /// 상태가 completed가 아니다
    error NotCompleted();

    /// multicall 인자 수가 안맞는데
    error NotEqualEachArgument();

    /// DelegateCallFail
    error FailDelegateCall();
}
