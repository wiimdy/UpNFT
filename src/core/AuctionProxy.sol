// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AuctionProxy is ERC1967Proxy {
    constructor(address contractLogic, bytes memory contractData) ERC1967Proxy(contractLogic, contractData) {}

    receive() external payable {}
}
