// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Pausable} from "src/util/Pausable.sol";

contract WDTOKEN is ERC20 {
    constructor() ERC20("WDETH", "WD") {
        _mint(msg.sender, 10 ** decimals() * 1); // auction 에게 100 * 10**18 개 발행
    }
}

contract SwapToken is Pausable {
    WDTOKEN public token;

    constructor(address _token) {
        token = WDTOKEN(_token);
    }

    function swapETHToken() external payable {
        uint256 ethReserve = address(this).balance;
        uint256 tokenReserve = token.balanceOf(address(this));

        uint256 ethIn = msg.value;
        uint256 tokenOut = (ethIn * tokenReserve) / (ethReserve + ethIn);

        require(tokenReserve >= tokenOut, "Not enough tokens");

        ethReserve += ethIn;
        tokenReserve -= tokenOut;

        token.transfer(msg.sender, tokenOut);
    }

    function swapTokenETH(uint256 amount) external {
        uint256 ethReserve = address(this).balance;
        uint256 tokenReserve = token.balanceOf(address(this));

        uint256 tokenIn = amount;
        require(tokenIn <= token.allowance(msg.sender, address(this)), "Must approve amount");
        token.transferFrom(msg.sender, address(this), tokenIn);
        uint256 ethOut = (tokenIn * ethReserve) / (tokenReserve + tokenIn);

        require(ethReserve >= ethOut, "Not enough ethers Sorry");

        ethReserve -= ethOut;
        tokenReserve += tokenIn;

        bool success = payable(msg.sender).send(ethOut);
        require(success, "Something wrong through sending");
    }

    function getTokenPriceInETH(uint256 tokenAmount) external view returns (uint256) {
        uint256 ethReserve = address(this).balance;
        uint256 tokenReserve = token.balanceOf(address(this));

        uint256 ethOut = (tokenAmount * ethReserve) / (tokenReserve + tokenAmount);
        return ethOut;
    }

    function getETHPriceInToken(uint256 etherAmount) external view returns (uint256) {
        uint256 ethReserve = address(this).balance;
        uint256 tokenReserve = token.balanceOf(address(this));

        uint256 tokenAmount = (etherAmount * tokenReserve) / (ethReserve + etherAmount);
        return tokenAmount;
    }

    receive() external payable {}
}
