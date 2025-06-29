// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {NusaToken} from "../src/NusaToken.sol";
import {NusaTimelock} from "../src/NusaTimelock.sol";
import {NusaQuest} from "../src/NusaQuest.sol";

contract NusaQuestScript is Script {
    //
    uint256 private i_minDelay;
    uint32 private i_votingDelay;
    uint32 private i_votingPeriod;

    address[] private i_proposers;
    address[] private i_executors;

    function setUp() public {
        i_minDelay = 1 minutes;
        i_votingDelay = 1 minutes;
        i_votingPeriod = 5 minutes;

        i_proposers.push(msg.sender);
        i_proposers.push(msg.sender);
    }

    function run() external returns (NusaQuest) {
        vm.startBroadcast();

        NusaToken nusaToken = new NusaToken();
        NusaTimelock nusaTimelock = new NusaTimelock(i_minDelay, i_proposers, i_executors);
        NusaQuest nusaQuest = new NusaQuest(nusaToken, nusaTimelock, i_votingDelay, i_votingPeriod);

        vm.stopBroadcast();

        return nusaQuest;
    }
    //
}
