// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

library Events {
    // ========================
    //        NusaQuest
    // ========================

    /// @notice Emitted when a new proposal is successfully created.
    /// @param proposalId The ID of the newly created proposal.
    event Proposed(uint256 proposalId);

    /// @notice Emitted when a vote is cast on a proposal.
    /// @param proposalId The ID of the proposal being voted on.
    /// @param support The support type: 0 = Against, 1 = For, 2 = Abstain.
    /// @param voter The address of the voter.
    event Voted(uint256 proposalId, uint8 support, address voter);

    /// @notice Emitted when a user swaps an NFT.
    /// @param user The address of the user who performed the swap.
    /// @param nftId The ID of the NFT involved in the swap.
    event Swapped(address user, uint256 nftId);

    /// @notice Emitted when a user claims a token reward.
    /// @param user The address of the user claiming the reward.
    /// @param amount The amount of tokens claimed.
    event Claimed(address user, uint256 amount);

    /// @notice Emitted when new NFTs are minted.
    /// @param ids The list of NFT IDs that were minted.
    event Minted(uint256[] ids);

    // ========================
    //        NusaToken
    // ========================

    /// @notice Emitted when a user delegates their voting power.
    /// @param user The address of the user who delegated.
    event Delegated(address user);

    // ========================
    //       NusaTimelock
    // ========================

    /// @notice Emitted when roles are granted to the NusaQuest contract.
    /// @param proposer The address granted the PROPOSER_ROLE.
    /// @param canceller The address granted the CANCELLER_ROLE.
    /// @param executor The address granted the EXECUTOR_ROLE.
    event Granted(address proposer, address canceller, address executor);
}
