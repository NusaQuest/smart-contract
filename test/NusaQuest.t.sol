// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {NusaQuest} from "../src/NusaQuest.sol";
import {NusaToken} from "../src/NusaToken.sol";
import {NusaTimelock} from "../src/NusaTimelock.sol";
import {Errors} from "../src/lib/Errors.l.sol";

/// @title NusaQuestTest
/// @dev Unit test contract for NusaQuest governance logic, including delegation, proposal lifecycle, voting, and reward claiming.
contract NusaQuestTest is Test {
    /// @dev Core contract instances and reusable test data
    NusaQuest private nusaQuest;
    NusaToken private nusaToken;

    /// @dev Test addresses representing different actors
    address private constant BOB = address(1);
    address private constant ALICE = address(2);
    address private constant CHARLIE = address(3);

    /// @dev Reusable arrays for constructing proposals data
    address[] private _targets = new address[](1);
    uint256[] private _values = new uint256[](1);
    bytes[] private _calldatas = new bytes[](1);
    string private _description = "lorem ipsum dolor sit amet";

    /// @dev Reusable arrays for constructing NFTs data
    uint256[] private _ids = new uint256[](2);
    uint256[] private _nftValues = new uint256[](2);
    uint256[] private _prices = new uint256[](2);
    string[] private _uris = new string[](2);

    /// @dev Role configuration for timelock deployment
    address[] private i_proposers;
    address[] private i_executors;
    address private i_admin;

    /**
     * @notice Sets up the test environment before each test runs.
     * - Deploys the NusaToken (ERC20 token with vote delegation support).
     * - Deploys the NusaTimelock (timelock controller with role-based permissions).
     * - Deploys the NusaQuest contract (governance-based quest/proposal logic).
     * - Configures governance parameters: voting delay, voting period, quorum, and execution delay.
     * - Grants executor permissions to NusaQuest so it can execute queued proposals through the timelock.
     */
    function setUp() public {
        uint256 minDelay = 1 minutes;
        uint32 votingDelay = 30; // 1 minute (approx. 30 blocks assuming 2s per block)
        uint32 votingPeriod = 150; // 5 minutes (approx. 150 blocks)
        uint256 quorum = 1;

        nusaToken = new NusaToken();
        NusaTimelock nusaTimelock = new NusaTimelock(
            minDelay,
            i_proposers,
            i_executors,
            i_admin
        );
        nusaQuest = new NusaQuest(
            nusaToken,
            nusaTimelock,
            votingDelay,
            votingPeriod,
            quorum
        );

        nusaTimelock.grantRole(address(nusaQuest));
    }

    /**
     * @notice Tests that a user can successfully delegate their voting power.
     * - Delegates from ALICE
     * - Checks that ALICE is marked as having delegated
     * - Verifies that ALICE receives the initial 10 token reward
     */
    function testSuccessfullyDelegate() public {
        vm.startPrank(ALICE);
        nusaToken.delegate();
        vm.stopPrank();

        bool expectedIsDelegate = true;
        bool actualIsDelegate = nusaToken.isAlreadyDelegate(ALICE);
        uint256 expectedBalance = 10;
        uint256 actualBalance = nusaQuest.ftBalance(ALICE);

        assertEq(expectedIsDelegate, actualIsDelegate);
        assertEq(expectedBalance, actualBalance);
    }

    /**
     * @notice Tests that a user can successfully initiate a new proposal.
     * - Proposal calls `claimProposerReward(address)`
     * - Confirms that the proposal is stored
     * - Checks that BOB is assigned the correct role (Proposer = 2)
     */
    function testSuccessfullyInitiateProposal() public {
        _targets.push(address(nusaQuest));
        _values.push(0);
        _calldatas.push(
            abi.encodeWithSignature("claimProposerReward(address)", BOB)
        );

        vm.startPrank(BOB);
        nusaQuest.initiate(_targets, _values, _calldatas, _description);
        vm.stopPrank();

        uint256 proposalId = nusaQuest.proposalIds()[0];

        uint256 expectedProposals = 1;
        uint256 actualProposals = nusaQuest.proposalIds().length;

        assertEq(expectedProposals, actualProposals);
    }

    /**
     * @notice Tests that a proposer can cancel their proposal before it becomes active.
     * - BOB initiates a proposal
     * - Immediately cancels it before voting starts
     * - No assertion needed, test passes if no revert occurs
     */
    function testSuccessfullyCancelProposal() public {
        _targets.push(address(nusaQuest));
        _values.push(0);
        _calldatas.push(
            abi.encodeWithSignature("claimProposerReward(address)", BOB)
        );

        vm.startPrank(BOB);
        nusaQuest.initiate(_targets, _values, _calldatas, _description);
        nusaQuest.cancel(
            _targets,
            _values,
            _calldatas,
            keccak256(bytes(_description))
        );
        vm.stopPrank();
    }

    /**
     * @notice Reverts when trying to cancel a proposal that has already become active.
     * - BOB initiates a proposal.
     * - Voting delay passes, making the proposal active.
     * - Cancelling at this point should revert.
     */
    function testRevertIfCancelProposalThatAlreadyActive() public {
        _targets.push(address(nusaQuest));
        _values.push(0);
        _calldatas.push(
            abi.encodeWithSignature("claimProposerReward(address)", BOB)
        );

        vm.startPrank(BOB);
        nusaQuest.initiate(_targets, _values, _calldatas, _description);
        vm.stopPrank();

        vm.roll(block.number + nusaQuest.votingDelay() + 1);
        vm.expectRevert();

        vm.startPrank(BOB);
        nusaQuest.cancel(
            _targets,
            _values,
            _calldatas,
            keccak256(bytes(_description))
        );
        vm.stopPrank();
    }

    /**
     * @notice Reverts when trying to create a proposal that already exists.
     * - BOB initiates a proposal.
     * - After voting delay, tries to re-initiate the same proposal with same calldata + description hash.
     * - Should revert due to duplicate proposal hash.
     */
    function testRevertIfProposalAlreadyExist() public {
        _targets.push(address(nusaQuest));
        _values.push(0);
        _calldatas.push(
            abi.encodeWithSignature("claimProposerReward(address)", BOB)
        );

        vm.startPrank(BOB);
        nusaQuest.initiate(_targets, _values, _calldatas, _description);
        vm.stopPrank();

        vm.roll(block.number + nusaQuest.votingDelay() + 1);
        vm.expectRevert();

        vm.startPrank(BOB);
        nusaQuest.initiate(_targets, _values, _calldatas, _description);
        vm.stopPrank();
    }

    /**
     * @notice Reverts when user tries to initiate another proposal during cooldown period.
     * - BOB initiates a proposal.
     * - Immediately attempts to create another one.
     * - Should revert due to action cooldown restriction.
     */
    function testRevertIfActionStillOnCooldown() public {
        _targets.push(address(nusaQuest));
        _values.push(0);
        _calldatas.push(
            abi.encodeWithSignature("claimProposerReward(address)", BOB)
        );

        vm.startPrank(BOB);
        nusaQuest.initiate(_targets, _values, _calldatas, _description);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(Errors.ActionOnCooldown.selector, BOB, 0)
        );

        _targets.push(address(nusaQuest));
        _values.push(0);
        _calldatas.push(
            abi.encodeWithSignature("claimProposerReward(address)", BOB)
        );

        vm.startPrank(BOB);
        nusaQuest.initiate(_targets, _values, _calldatas, _description);
        vm.stopPrank();
    }

    /**
     * @notice Successfully casts a vote on an active proposal.
     * - ALICE delegates her tokens to gain voting power.
     * - BOB creates a proposal.
     * - ALICE votes after the proposal becomes active.
     * - Asserts vote counts are correctly recorded (for/against/abstain).
     */
    function testSuccessfullyVoteOnQuest() public {
        vm.startPrank(ALICE);
        nusaToken.delegate();
        vm.stopPrank();

        vm.roll(block.number + 1);

        _targets.push(address(nusaQuest));
        _values.push(0);
        _calldatas.push(
            abi.encodeWithSignature("claimProposerReward(address)", BOB)
        );

        vm.startPrank(BOB);
        nusaQuest.initiate(_targets, _values, _calldatas, _description);
        vm.stopPrank();

        uint256 proposalId = nusaQuest.proposalIds()[0];
        uint256 voteStart = nusaQuest.proposalSnapshot(proposalId);
        uint8 support = 1;
        string memory reason = "Nice quest.";

        vm.roll(voteStart + 1);

        vm.startPrank(ALICE);
        nusaQuest.vote(proposalId, support, reason);
        vm.stopPrank();

        (
            uint256 expectedAgainstVotes,
            uint256 expectedForVotes,
            uint256 expectedAbstainVotes
        ) = (0, 10, 0);
        (
            uint256 actualAgainstVotes,
            uint256 actualForVotes,
            uint256 actualAbstainVotes
        ) = nusaQuest.proposalVotes(proposalId);

        assertEq(expectedAgainstVotes, actualAgainstVotes);
        assertEq(expectedForVotes, actualForVotes);
        assertEq(expectedAbstainVotes, actualAbstainVotes);
    }

    /**
     * @notice Reverts when attempting to vote on a proposal that doesn't exist.
     * - ALICE tries to vote on proposal ID 1, which has not been created.
     * - Should revert with InvalidProposalExistence error.
     */
    function testRevertIfProposalDoesNotExist() public {
        uint256 proposalId = 1;
        uint8 support = 1;
        string memory reason = "Nice quest.";

        vm.startPrank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidProposalExistence.selector,
                proposalId,
                false
            )
        );
        nusaQuest.vote(proposalId, support, reason);
        vm.stopPrank();
    }

    /**
     * @notice Successfully mints an NFT with correct values and metadata.
     * - Sets NFT ID, value, price, and URI.
     * - Verifies that the stored URI and price match expectations.
     */
    function testCanMintNFT() public {
        _ids.push(1);
        _nftValues.push(2);
        _prices.push(10);
        _uris.push("a");

        nusaQuest.mint(_ids, _nftValues, _prices, _uris);

        string memory expectedUri = "https://gateway.pinata.cloud/ipfs/a";
        string memory actualUri = nusaQuest.uri(1);
        uint256 expectedPrice = 10;
        uint256 actualPrice = nusaQuest.nftPrice(1);

        assertEq(expectedPrice, actualPrice);
        assert(
            keccak256(abi.encodePacked(expectedUri)) ==
                keccak256(abi.encodePacked(actualUri))
        );
    }

    /**
     * @notice Reverts when a non-authorized user attempts to mint NFTs.
     * - BOB (not the authorized NusaQuest contract) tries to call mint().
     * - Should revert with MintAccessDenied error.
     */
    function testRevertIfNonAuthorizedMintNFT() public {
        _ids.push(1);
        _nftValues.push(2);
        _prices.push(10);
        _uris.push("a");

        vm.startPrank(BOB);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.MintAccessDenied.selector, BOB)
        );
        nusaQuest.mint(_ids, _nftValues, _prices, _uris);
        vm.stopPrank();
    }

    /**
     * @notice Reverts when minting NFT with mismatched input array lengths.
     * - Length of IDs, values, prices, and URIs arrays must match.
     * - Should revert with InvalidInputLength error.
     */
    function testRevertIfInvalidLengthWhileMintNFT() public {
        _ids.push(1);
        _ids.push(2);
        _nftValues.push(2);
        _prices.push(10);
        _uris.push("a");

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidInputLength.selector,
                _ids.length,
                _nftValues.length,
                _prices.length,
                _uris.length
            )
        );
        nusaQuest.mint(_ids, _nftValues, _prices, _uris);
    }

    /**
     * @notice Successfully swaps fungible tokens for an NFT.
     * - NusaQuest mints an NFT with a price of 5 FT.
     * - ALICE delegates to receive FT, then swaps for the NFT.
     * - Verifies updated FT and NFT balances.
     */
    function testSuccessfullySwap() public {
        _ids.push(1);
        _nftValues.push(2);
        _prices.push(5);
        _uris.push("a");

        nusaQuest.mint(_ids, _nftValues, _prices, _uris);

        vm.startPrank(ALICE);
        nusaToken.delegate();
        nusaQuest.swap(1);
        vm.stopPrank();

        uint256 expectedFtBalance = 5;
        uint256 actualFtBalance = nusaQuest.ftBalance(ALICE);
        uint256 expectedNftBalance = 1;
        uint256 actualNftBalance = nusaQuest.nftBalance(ALICE, 1);

        assertEq(expectedFtBalance, actualFtBalance);
        assertEq(expectedNftBalance, actualNftBalance);
    }

    /**
     * @notice Successfully completes the full proposal lifecycle and distributes rewards.
     * - BOB creates a proposal to claim his reward.
     * - ALICE delegates, votes in favor, and the proposal gets queued and executed.
     * - ALICE claims voter reward, CHARLIE claims participant reward.
     * - Verifies all final FT balances and CHARLIE's proof.
     */
    function testSuccessfullyExecuteProposalAndDoQuest() public {
        _targets.push(address(nusaQuest));
        _values.push(0);
        _calldatas.push(
            abi.encodeWithSignature("claimProposerReward(address)", BOB)
        );

        vm.startPrank(BOB);
        nusaQuest.initiate(_targets, _values, _calldatas, _description);
        vm.stopPrank();

        vm.startPrank(ALICE);
        nusaToken.delegate();
        vm.stopPrank();

        vm.roll(block.number + 1);

        uint256 proposalId = nusaQuest.proposalIds()[0];
        uint256 voteStart = nusaQuest.proposalSnapshot(proposalId);
        uint8 support = 1;
        string memory reason = "Nice quest.";

        vm.roll(voteStart + 1);

        vm.startPrank(ALICE);
        nusaQuest.vote(proposalId, support, reason);
        vm.stopPrank();

        vm.roll(block.number + nusaQuest.votingPeriod());
        nusaQuest.queue(
            _targets,
            _values,
            _calldatas,
            keccak256(bytes(_description))
        );

        vm.warp(block.timestamp + nusaQuest.executionDelay());
        nusaQuest.execute(
            _targets,
            _values,
            _calldatas,
            keccak256(bytes(_description))
        );

        vm.startPrank(CHARLIE);
        nusaQuest.claimParticipantReward(proposalId, "NusaQuest");
        vm.stopPrank();

        uint256 expectedBobFtBalance = 30;
        uint256 actualBobFtBalance = nusaQuest.ftBalance(BOB);
        uint256 expectedCharlieFtBalance = 70;
        uint256 actualCharlieFtBalance = nusaQuest.ftBalance(CHARLIE);
        string memory expectedProof = "NusaQuest";
        string memory actualProof = nusaQuest.proof(proposalId, CHARLIE);

        assertEq(expectedBobFtBalance, actualBobFtBalance);
        assertEq(expectedCharlieFtBalance, actualCharlieFtBalance);
        assert(
            keccak256(abi.encodePacked(expectedProof)) ==
                keccak256(abi.encodePacked(actualProof))
        );
    }

    /**
     * @notice Reverts when a participant tries to do a quest after the deadline has passed.
     * - BOB creates and ALICE votes on a proposal.
     * - Proposal is executed successfully.
     * - ALICE claims voter reward.
     * - CHARLIE tries to claim participant reward 8 days after execution.
     * - Should revert with QuestExpired error (deadline is 7 days after execution).
     */
    function testRevertIfDoQuestAfterDeadline() public {
        _targets.push(address(nusaQuest));
        _values.push(0);
        _calldatas.push(
            abi.encodeWithSignature("claimProposerReward(address)", BOB)
        );

        vm.startPrank(BOB);
        nusaQuest.initiate(_targets, _values, _calldatas, _description);
        vm.stopPrank();

        vm.startPrank(ALICE);
        nusaToken.delegate();
        vm.stopPrank();

        vm.roll(block.number + 1);

        uint256 proposalId = nusaQuest.proposalIds()[0];
        uint256 voteStart = nusaQuest.proposalSnapshot(proposalId);
        uint8 support = 1;
        string memory reason = "Nice quest.";

        vm.roll(voteStart + 1);

        vm.startPrank(ALICE);
        nusaQuest.vote(proposalId, support, reason);
        vm.stopPrank();

        vm.roll(block.number + nusaQuest.votingPeriod());
        nusaQuest.queue(
            _targets,
            _values,
            _calldatas,
            keccak256(bytes(_description))
        );

        vm.warp(block.timestamp + nusaQuest.executionDelay());
        nusaQuest.execute(
            _targets,
            _values,
            _calldatas,
            keccak256(bytes(_description))
        );

        vm.warp(block.timestamp + 8 days);
        vm.startPrank(CHARLIE);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.QuestExpired.selector,
                proposalId,
                (nusaQuest.proposalEta(proposalId) + 7 days),
                block.timestamp
            )
        );
        nusaQuest.claimParticipantReward(proposalId, "NusaQuest");
        vm.stopPrank();
    }

    //
}
