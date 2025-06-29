// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {NusaQuest} from "../src/NusaQuest.sol";

contract NusaQuestScript is Script {
    NusaQuest public nusaQuest;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        vm.stopBroadcast();
    }
}
