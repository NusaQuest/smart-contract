// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {Errors} from "./lib/Errors.l.sol";
import {Events} from "./lib/Events.l.sol";

/**
 * @title NusaTimelock
 * @dev A customized TimelockController used in the NusaQuest governance system to enforce delayed execution of proposals.
 *
 * Inherits from OpenZeppelin's TimelockController and forwards constructor parameters.
 * This contract introduces a custom one-time setup function to assign governance roles.
 */
contract NusaTimelock is TimelockController {
    /// @dev Internal flag to ensure roles are only granted once.
    bool private _isInit;

    /**
     * @dev Modifier to ensure a function can only be called once.
     * Used to prevent re-granting of roles after initial setup.
     */
    modifier onlyOnce() {
        _checkOnlyOnce();
        _;
    }

    /**
     * @notice Constructor for the NusaTimelock contract.
     * @param _minDelay The minimum delay (in seconds) before a queued operation can be executed.
     * @param _proposers Initial list of addresses that can propose operations.
     * @param _executors Initial list of addresses that can execute queued operations.
     * @param _admin Address with permission to grant and revoke roles. Can be set to address(0) for trustless setup.
     */
    constructor(
        uint256 _minDelay,
        address[] memory _proposers,
        address[] memory _executors,
        address _admin
    ) TimelockController(_minDelay, _proposers, _executors, _admin) {}

    /**
     * @notice Grants all essential roles (PROPOSER, CANCELLER, EXECUTOR) to the NusaQuest Governor contract.
     * @dev Can only be called once due to the `onlyOnce` modifier. Intended for initial governance setup.
     * @param _nusaQuest Address of the NusaQuest Governor contract.
     */
    function grantRole(address _nusaQuest) external onlyOnce {
        _grantRole(PROPOSER_ROLE, _nusaQuest);
        _grantRole(CANCELLER_ROLE, _nusaQuest);
        _grantRole(EXECUTOR_ROLE, _nusaQuest);
        _isInit = true;

        emit Events.Granted(_nusaQuest, _nusaQuest, _nusaQuest);
    }

    /// @dev Internal check to ensure roles are not granted more than once.
    function _checkOnlyOnce() private view {
        require(!_isInit, Errors.AlreadyGranted());
    }
}
