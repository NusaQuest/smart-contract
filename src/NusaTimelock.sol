// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title NusaTimelock
 * @dev A customized TimelockController used in NusaQuest system to enforce delayed execution of proposals.
 *
 * Inherits from OpenZeppelin's TimelockController and simply forwards constructor parameters.
 * Timelock ensures decentralization by introducing a delay between proposal approval and execution.
 */
contract NusaTimelock is TimelockController {
    /**
     * @notice Constructor for the NusaTimelock contract.
     * @param _minDelay The minimum delay (in seconds) before a queued operation can be executed.
     * @param _proposers List of addresses that can propose operations.
     * @param _executors List of addresses that can execute queued operations.
     * @param _admin Optional admin address with role-granting and revoking permissions.
     */
    constructor(uint256 _minDelay, address[] memory _proposers, address[] memory _executors, address _admin)
        TimelockController(_minDelay, _proposers, _executors, _admin)
    {}
}
