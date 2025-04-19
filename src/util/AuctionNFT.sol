// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Pausable} from "src/util/Pausable.sol";
import {WDTOKEN, SwapToken} from "src/util/AuctionToken.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// Nft minting를 위한 token ..
contract UpToken is ERC721, Multicall, Pausable {
    uint256 private _tokenIdCounter;
    WDTOKEN private _token;
    address _auction;

    constructor(address token, address auction) ERC721("UpNFT", "UT") {
        _tokenIdCounter = 1;
        _token = WDTOKEN(token);
        _auction = auction;
    }

    // NFT 민팅 함수  민팅하려면 token을 받아야 한다
    /// approve to -> auction
    function mint(address to) public returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        uint256 amount = _token.allowance(msg.sender, address(this));
        require(amount > 0.0001 ether, "More WD token need!");
        _token.transferFrom(msg.sender, _auction, 0.0001 ether);
        _safeMint(to, tokenId);

        _tokenIdCounter++;
        return (tokenId);
    }

    function multiMint(address[] memory dst) public returns (uint256[] memory) {
        uint256 dstLen = dst.length;
        bytes[] memory results;
        bytes[] memory callData = new bytes[](dstLen);
        uint256[] memory tokenIds = new uint256[](dstLen);
        for (uint256 i = 0; i < dstLen; i++) {
            callData[i] = abi.encodeWithSignature("mint(address)", dst[i]);
        }
        (bool success, bytes memory data) =
            address(this).delegatecall(abi.encodeWithSignature("multicall(bytes[])", callData));
        if (!success) revert();

        results = abi.decode(data, (bytes[]));
        for (uint256 i = 0; i < results.length; i++) {
            tokenIds[i] = abi.decode(results[i], (uint256));
        }
        return (tokenIds);
    }
}
