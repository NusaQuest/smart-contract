// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {NusaToken} from "../src/NusaToken.sol";
import {NusaTimelock} from "../src/NusaTimelock.sol";
import {NusaQuest} from "../src/NusaQuest.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract NusaQuestScript is Script {
    //
    address[] private i_proposers;
    address[] private i_executors;
    address private i_admin;

    function run() external returns (NusaQuest) {
        vm.startBroadcast();
        uint256 minDelay = 1 minutes;
        uint32 votingDelay = 1 minutes;
        uint32 votingPeriod = 5 minutes;
        uint256 quorum = 1;

        NusaToken nusaToken = new NusaToken();
        NusaTimelock nusaTimelock = new NusaTimelock(
            minDelay,
            i_proposers,
            i_executors,
            i_admin
        );
        NusaQuest nusaQuest = new NusaQuest(
            nusaToken,
            nusaTimelock,
            votingDelay,
            votingPeriod,
            quorum
        );

        nusaTimelock.grantRole(address(nusaQuest));

        vm.stopBroadcast();

        return nusaQuest;
    }
    //
}
