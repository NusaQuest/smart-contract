// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {NusaToken} from "../src/NusaToken.sol";
import {NusaTimelock} from "../src/NusaTimelock.sol";
import {NusaQuest} from "../src/NusaQuest.sol";
import {NusaReward} from "../src/NusaReward.sol";

/**
 * @notice Deploys and initializes the Nusa governance contracts:
 * - Deploys `NusaToken` as the governance token.
 * - Deploys `NusaTimelock` with custom delay, proposers, executors, and admin.
 * - Deploys `NusaQuest` as the governance logic contract.
 * - Deploys `NusaReward` as the reward handler tied to `NusaQuest`.
 * - Grants role to `NusaQuest` in the timelock and links reward contract.
 *
 * @dev Parameters:
 * - `minDelay`: Delay before a queued proposal can be executed (10 minutes).
 * - `votingDelay`: Number of blocks before voting starts (300).
 * - `votingPeriod`: Duration of voting (300 blocks).
 * - `quorum`: Minimum number of votes required to pass (1).
 *
 * Timelock roles (`i_proposers`, `i_executors`, `i_admin`) can be preconfigured or left empty for testing.
 */
contract NusaQuestScript is Script {
    /// @dev Used to initialize the TimelockController.
    address[] private i_proposers;
    address[] private i_executors;
    address private i_admin;

    /// @notice Entry point to deploy contracts with deployer's private key from env.
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        uint256 minDelay = 5 minutes;
        uint32 votingDelay = 300;
        uint32 votingPeriod = 300;
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

        NusaReward nusaReward = new NusaReward(address(nusaQuest), msg.sender);

        nusaTimelock.grantRole(address(nusaQuest));
        nusaQuest.setNusaReward(nusaReward);

        vm.stopBroadcast();
    }
}
