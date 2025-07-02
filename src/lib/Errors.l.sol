// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

library Errors {
    // NusaQuest Custom Errors
    error UnauthorizedRole(address user, uint256 proposalId, uint8 expected);
    error InvalidProposalExistence(uint256 proposalId, bool expected);
    error InvalidProofExistence(uint256 proposalId, address user, bool expected);
    error InvalidProposalState(uint256 proposalId);
    error ActionOnCooldown(address user, uint8 action);
    error MintAccessDenied(address user);
}
