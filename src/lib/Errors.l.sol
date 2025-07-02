// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title Errors
/// @notice Centralized library for custom error definitions used across Nusa contracts.
library Errors {
    // ========================
    //        NusaQuest
    // ========================

    /// @notice Thrown when a user with invalid role attempts to take an action on a proposal.
    /// @param user The address of the user attempting the action.
    /// @param proposalId The ID of the proposal being interacted with.
    /// @param actual The actual role/status of the user.
    error UnauthorizedRole(address user, uint256 proposalId, uint8 actual);

    /// @notice Thrown when a proposal is expected to exist or not, but doesn't match.
    /// @param proposalId The ID of the proposal being checked.
    /// @param actual Whether the proposal currently exists.
    error InvalidProposalExistence(uint256 proposalId, bool actual);

    /// @notice Thrown when a user is expected to have or not have submitted proof of their action.
    /// @param proposalId The ID of the related proposal.
    /// @param user The address of the user.
    /// @param actual Whether the proof exists.
    error InvalidProofExistence(uint256 proposalId, address user, bool actual);

    /// @notice Thrown when a proposal is in an unexpected or invalid state for the attempted action.
    /// @param proposalId The ID of the proposal.
    /// @param state The current state of the proposal.
    error InvalidProposalState(uint256 proposalId, uint8 state);

    /// @notice Thrown when a user performs an action before their cooldown period expires.
    /// @param user The address of the user.
    /// @param action The action type being attempted (represented as an enum uint8).
    error ActionOnCooldown(address user, uint8 action);

    /// @notice Thrown when an unauthorized address attempts to mint tokens.
    /// @param user The address attempting the mint.
    error MintAccessDenied(address user);

    // ========================
    //       NusaReward
    // ========================

    /// @notice Thrown when mint input arrays (ids, values, prices, uris) have mismatched lengths.
    /// @param idsLength Length of the NFT IDs array.
    /// @param valuesLength Length of the values array.
    /// @param pricesLength Length of the prices array.
    /// @param urisLength Length of the URIs array.
    error InvalidInputLength(
        uint256 idsLength,
        uint256 valuesLength,
        uint256 pricesLength,
        uint256 urisLength
    );

    // ========================
    //      NusaTimelock
    // ========================

    /// @notice Thrown when trying to grant a role that has already been granted.
    error AlreadyGranted();

    // ========================
    //       NusaToken
    // ========================

    /// @notice Thrown when a user attempts to delegate but has already delegated before.
    /// @param user The address attempting delegation.
    error AlreadyDelegated(address user);

    /// @notice Thrown when trying to set the governance contract more than once.
    /// @param governor The already set governor contract address.
    error GovernanceAlreadySet(address governor);

    /// @notice Thrown when a function restricted to NusaQuest is called by another address.
    /// @param caller The unauthorized caller address.
    error NotNusaQuest(address caller);
}
