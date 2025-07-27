// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title Errors
/// @notice Centralized library for custom error definitions used across Nusa contracts.
library Errors {
    // ========================
    //        NusaQuest
    // ========================

    /// @notice Thrown when a proposal is expected to exist or not, but doesn't match.
    /// @param proposalId The ID of the proposal being checked.
    /// @param actual Whether the proposal currently exists.
    error InvalidProposalExistence(uint256 proposalId, bool actual);

    /// @notice Reverts when the quest is attempted after the 7-day execution window has passed.
    /// @param proposalId The ID of the quest/proposal.
    /// @param expiredAt The timestamp when the quest expired.
    /// @param currentTime The current block timestamp at execution attempt.
    error QuestExpired(
        uint256 proposalId,
        uint256 expiredAt,
        uint256 currentTime
    );

    /// @notice Thrown when a proposal is in an unexpected or invalid state for the attempted action.
    /// @param proposalId The ID of the proposal.
    /// @param state The current state of the proposal.
    error InvalidProposalState(uint256 proposalId, uint8 state);

    /// @notice Thrown when a user performs an action before their cooldown period expires.
    /// @param user The address of the user.
    /// @param action The action type being attempted (represented as an enum uint8).
    error ActionOnCooldown(address user, uint8 action);

    /// @notice Reverts when a required identity is not found for the given user.
    /// @param user The address of the user who has not yet registered an identity.
    error IdentityNotRegistered(address user);

    /// @notice Thrown when trying to set the reward contract more than once.
    /// @param nusaReward The already set reward contract address.
    error NusaRewardAlreadySet(address nusaReward);

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

    // ========================
    //        Reusable
    // ========================

    /// @notice Reverts when the caller is not the expected address.
    error UnexpectedCaller();
}
