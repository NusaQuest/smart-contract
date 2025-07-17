// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {NusaToken} from "../src/NusaToken.sol";
import {NusaTimelock} from "../src/NusaTimelock.sol";
import {NusaQuest} from "../src/NusaQuest.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @notice Deploys and initializes NusaToken, NusaTimelock, and NusaQuest contracts for testing.
 * - Sets the `minDelay`, `votingDelay`, `votingPeriod`, and `quorum` for governance parameters.
 * - Deploys `NusaToken` as the governance token.
 * - Deploys `NusaTimelock` with empty proposer and executor arrays, and an admin address.
 * - Deploys `NusaQuest` with the token, timelock, and governance parameters.
 * - Grants the NusaQuest contract role access in the timelock controller.
 */
contract NusaQuestScript is Script {
    /// @dev Used to initialize the TimelockController contract.
    /// - `i_proposers`: list of addresses allowed to propose actions to the timelock (usually left empty, then granted later).
    /// - `i_executors`: list of addresses allowed to execute queued proposals (can be open or specific).
    /// - `i_admin`: initial admin address for the TimelockController (often set to address(0) or the deployer for tests).
    address[] private i_proposers;
    address[] private i_executors;
    address private i_admin;

    /// @notice Placeholder `run` function. Can be used to manually trigger logic for scripts or testing via external call.
    function run() external {
        vm.startBroadcast();
        uint256 minDelay = 10 minutes;
        uint32 votingDelay = 300; // ~10 minutes
        uint32 votingPeriod = 300; // ~10 minutes
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
    }
    //
}
