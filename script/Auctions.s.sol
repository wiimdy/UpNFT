// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Script, console} from "forge-std/Script.sol";
import {UpToken} from "src/util/AuctionNFT.sol";
import {AuctionProxy} from "src/core/AuctionProxy.sol";
import {AuctionLogic} from "src/core/AuctionLogic.sol";
import {WDTOKEN, SwapToken} from "src/util/AuctionToken.sol";

contract AuctionScript is Script {
    AuctionProxy public myAuction;
    AuctionLogic public logic;
    AuctionLogic public auctions;
    WDTOKEN public token;
    SwapToken public swap;
    UpToken public uptokens;

    function setUp() public {}

    function run() external {
        vm.startBroadcast();
        logic = new AuctionLogic();
        myAuction = new AuctionProxy(address(logic), "");
        auctions = AuctionLogic(payable(address(myAuction)));

        token = new WDTOKEN();
        swap = new SwapToken(address(token));
        bool success = payable(address(swap)).send(1 ether);
        require(success, "You have no ether...");
        token.transfer(address(swap), token.totalSupply() / 2);

        auctions.intializeV2(address(swap));
        uptokens = new UpToken(address(token), address(auctions));
        console.log("proxy: ", address(myAuction));
        console.log("swap: ", address(swap));
        console.log("NFT: ", address(uptokens));

        vm.stopBroadcast();
    }
}
