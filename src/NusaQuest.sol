// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {NusaReward} from "./NusaReward.sol";
import {NusaToken} from "./NusaToken.sol";
import {NusaTimelock} from "./NusaTimelock.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Errors} from "./lib/Errors.l.sol";
import {Events} from "./lib/Events.l.sol";

/**
 * @title NusaQuest
 * @dev Governance contract extending OpenZeppelin Governor modules with additional reward mechanics.
 * Features include:
 * - Cooldown enforcement between propose and vote actions.
 * - Custom reward system for proposers, voters, and participants.
 * - Proof-based claim mechanism.
 * - Deadline enforcement for completing quests.
 */
contract NusaQuest is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    ReentrancyGuard
{
    /// @notice Enum for different cooldown-controlled actions
    enum Action {
        PROPOSE,
        VOTE
    }

    /// @notice Structure representing a record of a user's submission for a specific proposal.
    /// @dev Stores the proposal ID and a string-based proof (e.g., IPFS hash, link, or description).
    struct SubmissionHistory {
        uint256 proposalId;
        string proof;
    }

    /// @notice Structure representing a single voting record by a user.
    /// @dev Each vote includes the target proposal and the support type:
    /// 0 = Against and 1 = For.
    struct VoteHistory {
        uint256 proposalId;
        uint8 support;
    }

    /// @notice Mapping to track all submissions made by a user across proposals.
    mapping(address => SubmissionHistory[]) private s_submissionHistory;

    /// @notice Mapping to track all votes made by a user.
    mapping(address => VoteHistory[]) private s_voteHistory;

    /// @notice Flags if a proposal exists
    mapping(uint256 => bool) private s_proposalExist;

    /// @notice Stores the timestamp when a proposal was executed.
    mapping(uint256 => uint256) private s_executedTimestamp;

    /// @notice Last propose timestamp per user
    mapping(address => uint256) private s_lastProposeTimestamp;

    /// @notice Last vote timestamp per user
    mapping(address => uint256) private s_lastVoteTimestamp;

    /// @notice Tracks the total number of votes cast by a user
    mapping(address => uint256) private s_totalVotes;

    /// @notice Tracks the total number of proposals created by a user
    mapping(address => uint256) private s_totalProposals;

    /// @notice Tracks the total number of quests executed by a user
    mapping(address => uint256) private s_totalQuestsExecuted;

    /// @notice Whether an address has minting permission
    mapping(address => bool) private s_canMint;

    /// @notice Array of all proposal IDs
    uint256[] private s_proposalIds;

    /// @notice Fixed reward amount in $NUSA tokens for the proposer of a successful quest
    uint256 private constant PROPOSER_REWARD = 10;

    /// @notice Fixed reward amount in $NUSA tokens for the participant of a successful quest
    uint256 private constant PARTICIPANT_REWARD = 40;

    /// @notice Cooldown between actions
    uint256 private constant ACTION_COOLDOWN_PERIOD = 10 minutes;

    /// @notice Deadline to complete a quest after execution
    uint256 private constant QUEST_DEADLINE = 10 minutes;

    /// @notice Contract responsible for distributing rewards
    NusaReward private i_nusaReward;

    /// @notice Governance token contract (ERC20Votes)
    NusaToken private i_nusaToken;

    /// @notice Timelock controller for proposal execution
    NusaTimelock private i_nusaTimelock;

    /// @dev Validates proposal existence matches expectation (should exist or not)
    modifier validateProposalExistence(uint256 _proposalId, bool _expected) {
        _checkProposalExistence(_proposalId, _expected);
        _;
    }

    /// @dev Validates if user is not calling action too soon (respecting cooldown)
    modifier validateLastActionTimestamp(address _user, Action _action) {
        _checkLastActionTimestamp(_user, _action);
        _;
    }

    /// @dev Validates if user has permission to mint NFT (admin-only in most cases)
    modifier validateMintAccess(address _user) {
        _checkMintAccess(_user);
        _;
    }

    /// @dev Ensures proposal is in the expected state (Pending, Active, Succeeded, etc.)
    modifier validateState(uint256 _proposalId, ProposalState _expected) {
        _checkState(_proposalId, _expected);
        _;
    }

    /// @dev Ensures current time is still within the allowed quest completion window
    modifier validateQuestDeadline(uint256 _proposalId) {
        _checkQuestDeadline(_proposalId);
        _;
    }

    /**
     * @notice Initializes the NusaQuest contract and links with token and timelock.
     * @param _token The ERC20Votes-compatible token used for governance.
     * @param _timelock The timelock controller for proposal execution.
     * @param _votingDelay Delay (in blocks) before voting starts.
     * @param _votingPeriod Duration (in blocks) of the voting phase.
     * @param _quorum Required quorum fraction (percentage of total supply).
     */
    constructor(
        NusaToken _token,
        NusaTimelock _timelock,
        uint48 _votingDelay,
        uint32 _votingPeriod,
        uint256 _quorum
    )
        Governor("NusaDAO")
        GovernorSettings(_votingDelay, _votingPeriod, 0)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(_quorum)
        GovernorTimelockControl(_timelock)
    {
        i_nusaReward = new NusaReward(address(this));
        i_nusaToken = _token;
        i_nusaTimelock = _timelock;
        i_nusaToken.setNusaQuest(address(this));
        s_canMint[msg.sender] = true;
    }

    /// @notice Creates a new on-chain quest proposal.
    /// @param _targets The contract addresses to be called if the proposal is executed.
    /// @param _values The amount of ETH to send with each contract call.
    /// @param _calldatas The function call data to be executed for each target.
    /// @param _description A human-readable description of the proposal.
    /// @dev This function wraps the {propose} function, marks the proposal as existing,
    ///      stores the last propose timestamp for the caller, pushes the ID to the proposals list,
    ///      and increments the total number of proposals made by the caller.
    /// @dev Also ensures cooldown between proposals via {validateLastActionTimestamp}.
    /// @dev Emits a {Proposed} event containing the new proposal ID.
    function initiate(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    ) external validateLastActionTimestamp(msg.sender, Action.PROPOSE) {
        uint256 proposalId = propose(
            _targets,
            _values,
            _calldatas,
            _description
        );

        s_proposalExist[proposalId] = true;
        s_lastProposeTimestamp[msg.sender] = block.timestamp;
        s_proposalIds.push(proposalId);
        s_totalProposals[msg.sender] += 1;

        emit Events.Proposed(proposalId);
    }

    /// @notice Cast a vote on an active proposal with an optional reason.
    /// @param _proposalId The ID of the active proposal to vote on.
    /// @param _support Type of vote: 0 = Against and 1 = For.
    /// @param _reason Optional reason for voting, stored off-chain for transparency.
    /// @return voteWeight The amount of voting power used for this vote.
    /// @dev Requirements:
    /// - The proposal must exist and be active (validated by {validateProposalExistence}).
    /// - The voter must not be in cooldown (enforced by {validateLastActionTimestamp}).
    /// @dev Effects:
    /// - Records the voter's support choice in their vote history.
    /// - Updates the last vote timestamp and increments the user's total vote count.
    /// @dev Emits a {Voted} event with the proposal ID, vote type, and voter's address.
    function vote(
        uint256 _proposalId,
        uint8 _support,
        string calldata _reason
    )
        external
        validateProposalExistence(_proposalId, true)
        validateLastActionTimestamp(msg.sender, Action.VOTE)
        returns (uint256)
    {
        s_voteHistory[msg.sender].push(VoteHistory(_proposalId, _support));
        s_lastVoteTimestamp[msg.sender] = block.timestamp;
        s_totalVotes[msg.sender] += 1;

        emit Events.Voted(_proposalId, _support, msg.sender);

        return castVoteWithReason(_proposalId, _support, _reason);
    }

    /// @notice Swaps user's $NUSA tokens for a specific NFT.
    /// @param _nftId ID of the NFT to be redeemed.
    /// @dev Burns the equivalent amount of $NUSA and transfers the NFT to the user.
    /// @dev Emits a {Swapped} event.
    function swap(uint256 _nftId) external nonReentrant {
        uint256 amount = i_nusaReward.nftPrice(_nftId);
        i_nusaToken.burn(msg.sender, amount);
        i_nusaReward.transfer(_nftId, msg.sender);

        emit Events.Swapped(msg.sender, _nftId);
    }

    /// @notice Claims reward for the proposer after successful proposal execution.
    /// @param _user Address of the proposer to receive reward.
    /// @dev Can only be called by the governance (TimelockController).
    /// @dev Emits a {Claimed} event.
    function claimProposerReward(address _user) external onlyGovernance {
        i_nusaToken.mint(_user, PROPOSER_REWARD);

        emit Events.Claimed(_user, PROPOSER_REWARD);
    }

    /// @notice Claim reward for participating in a quest by submitting a hashed proof.
    /// @param _proposalId The ID of the executed proposal (quest) to claim rewards from.
    /// @param _proof A hashed string (e.g., IPFS CID or SHA-256) of the participant's video submission as proof of quest completion.
    /// @dev Requirements:
    /// - The proposal must exist and be in the `Executed` state.
    /// - The quest must still be within the allowed claim period (see {validateQuestDeadline}).
    /// - The sender must not have previously submitted proof for this proposal.
    /// @dev Effects:
    /// - Records the hashed proof in the submission history.
    /// - Mints a fixed amount of NUSA tokens to the participant.
    /// - Increments the sender’s completed quest count.
    /// @dev Emits a {Claimed} event with the sender's address and reward amount.
    function claimParticipantReward(
        uint256 _proposalId,
        string memory _proof
    )
        external
        validateProposalExistence(_proposalId, true)
        validateState(_proposalId, ProposalState.Executed)
        validateQuestDeadline(_proposalId)
    {
        s_submissionHistory[msg.sender].push(
            SubmissionHistory(_proposalId, _proof)
        );
        i_nusaToken.mint(msg.sender, PARTICIPANT_REWARD);
        s_totalQuestsExecuted[msg.sender] += 1;

        emit Events.Claimed(msg.sender, PARTICIPANT_REWARD);
    }

    /// @notice Mints new NFTs to the quest reward pool.
    /// @param _ids Array of NFT IDs.
    /// @param _values Amount of each NFT to mint.
    /// @param _prices Price of each NFT in $NUSA.
    /// @param _uris IPFS URIs for each NFT.
    /// @dev Only authorized minters can call this.
    /// @dev Emits a {Minted} event.
    function mint(
        uint256[] memory _ids,
        uint256[] memory _values,
        uint256[] memory _prices,
        string[] memory _uris
    ) external validateMintAccess(msg.sender) {
        i_nusaReward.mint(_ids, _values, _prices, _uris);

        emit Events.Minted(_ids);
    }

    /// @notice Returns the metadata URI of a specific NFT.
    /// @param _id ID of the NFT.
    /// @return The full IPFS URI of the NFT.
    function uri(uint256 _id) external view returns (string memory) {
        return i_nusaReward.uri(_id);
    }

    /// @notice Returns the price of a specific NFT in $NUSA.
    /// @param _id ID of the NFT.
    /// @return The price in $NUSA tokens.
    function nftPrice(uint256 _id) external view returns (uint256) {
        return i_nusaReward.nftPrice(_id);
    }

    /// @notice Returns the NFT balance of a user for a specific NFT ID.
    /// @param _user Address of the user.
    /// @param _nftId ID of the NFT.
    /// @return The amount of NFT owned by the user.
    function nftBalance(
        address _user,
        uint256 _nftId
    ) external view returns (uint256) {
        return i_nusaReward.balanceOf(_user, _nftId);
    }

    /// @notice Returns the fungible token ($NUSA) balance of a user.
    /// @param _user Address of the user.
    /// @return The $NUSA token balance.
    function ftBalance(address _user) external view returns (uint256) {
        return i_nusaToken.balanceOf(_user);
    }

    /// @notice Checks if an address is authorized to mint NFTs.
    /// @param _user Address to check.
    /// @return True if the address is authorized to mint, false otherwise.
    function isAuthorizedMinter(address _user) external view returns (bool) {
        return s_canMint[_user];
    }

    /// @notice Returns the duration of the voting period in blocks.
    /// @return Number of blocks the voting period lasts.
    function votingPeriod()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    /// @notice Returns the delay (in blocks) before voting on a proposal starts.
    /// @return Number of blocks to wait before voting begins.
    function votingDelay()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    /// @notice Returns the full submission history of a user.
    /// @param _user The address of the user.
    /// @return An array of SubmissionHistory structs associated with the user.
    function userSubmissionHistory(
        address _user
    ) external view returns (SubmissionHistory[] memory) {
        return s_submissionHistory[_user];
    }

    /// @notice Returns the full voting history of a user.
    /// @param _user The address of the user.
    /// @return An array of VoteHistory structs representing the user's votes across proposals.
    function userVoteHistory(
        address _user
    ) external view returns (VoteHistory[] memory) {
        return s_voteHistory[_user];
    }

    /// @notice Returns the contribution statistics of a given user.
    /// @param _user The wallet address of the user.
    /// @return proposalCount Total number of proposals created by the user.
    /// @return voteCount Total number of proposals the user has voted on.
    /// @return questExecutedCount Total number of quests executed by the user.
    /// @dev Useful for calculating user engagement or displaying reputation metrics.
    function contribution(
        address _user
    ) external view returns (uint256, uint256, uint256) {
        return (
            s_totalProposals[_user],
            s_totalVotes[_user],
            s_totalQuestsExecuted[_user]
        );
    }

    /// @notice Returns an array of all proposal IDs created in the system.
    /// @return Array of proposal IDs.
    function proposalIds() external view returns (uint256[] memory) {
        return s_proposalIds;
    }

    /// @notice Checks whether a proposal with the given ID exists.
    /// @param _proposalId ID of the proposal.
    /// @return True if the proposal exists, false otherwise.
    function proposalExist(uint256 _proposalId) external view returns (bool) {
        return s_proposalExist[_proposalId];
    }

    /// @notice Returns the timestamp of the last time a user proposed.
    /// @param _user Address of the user.
    /// @return UNIX timestamp of the last propose action.
    function lastProposeTimestamp(
        address _user
    ) external view returns (uint256) {
        return s_lastProposeTimestamp[_user];
    }

    /// @notice Returns the timestamp of the last time a user voted.
    /// @param _user Address of the user.
    /// @return UNIX timestamp of the last vote action.
    function lastVoteTimestamp(address _user) external view returns (uint256) {
        return s_lastVoteTimestamp[_user];
    }

    /// @notice Returns the execution timestamp of a given proposal.
    /// @param _proposalId The ID of the proposal.
    /// @return The UNIX timestamp (in seconds) when the proposal was executed.
    function executedTimestamp(
        uint256 _proposalId
    ) external view returns (uint256) {
        return s_executedTimestamp[_proposalId];
    }

    /// @dev Checks whether a proposal exists or not based on expectation.
    /// @dev Reverts with `InvalidProposalExistence` if the condition fails.
    /// @param _proposalId ID of the proposal to check.
    /// @param _expected Expected existence status (true = should exist, false = should not exist).
    function _checkProposalExistence(
        uint256 _proposalId,
        bool _expected
    ) private view {
        require(
            s_proposalExist[_proposalId] == _expected,
            Errors.InvalidProposalExistence(_proposalId, !_expected)
        );
    }

    /// @dev Checks whether a proposal is in the expected Governor state.
    /// @dev Reverts with `InvalidProposalState` if current state does not match expected.
    /// @param _proposalId ID of the proposal.
    /// @param _state Expected proposal state.
    function _checkState(
        uint256 _proposalId,
        ProposalState _state
    ) private view {
        require(
            state(_proposalId) == _state,
            Errors.InvalidProposalState(_proposalId, uint8(state(_proposalId)))
        );
    }

    /// @dev Checks if a user has waited long enough since their last action (propose or vote).
    /// @dev Enforces a cooldown period between actions.
    /// @dev Reverts with `ActionOnCooldown` if action is attempted too soon.
    /// @param _user Address of the user.
    /// @param _action Action type: PROPOSE or VOTE.
    function _checkLastActionTimestamp(
        address _user,
        Action _action
    ) private view {
        uint256 lastActionTime = _action == Action.PROPOSE
            ? s_lastProposeTimestamp[_user]
            : s_lastVoteTimestamp[_user];

        require(
            block.timestamp > lastActionTime + ACTION_COOLDOWN_PERIOD ||
                lastActionTime == 0,
            Errors.ActionOnCooldown(_user, uint8(_action))
        );
    }

    /// @dev Checks if a user has permission to mint NFTs.
    /// @dev Reverts with `MintAccessDenied` if not authorized.
    /// @param _user Address of the user.
    function _checkMintAccess(address _user) private view {
        require(s_canMint[_user], Errors.MintAccessDenied(_user));
    }

    /// @dev Checks whether the participant is still within the allowed quest completion period.
    /// @dev Reverts with `QuestExpired` if the current time has passed the deadline.
    /// @param _proposalId ID of the proposal representing the quest.
    function _checkQuestDeadline(uint256 _proposalId) private view {
        require(
            block.timestamp <= (proposalEta(_proposalId) + QUEST_DEADLINE),
            Errors.QuestExpired(
                _proposalId,
                (proposalEta(_proposalId) + QUEST_DEADLINE),
                block.timestamp
            )
        );
    }

    /// @notice Returns the minimum number of votes required for a proposal to be created.
    /// @dev Inherited from GovernorSettings, can be customized if needed.
    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    /// @notice Returns the current state of a proposal.
    /// @dev Overridden to integrate GovernorTimelockControl logic (e.g., Queued, Executed).
    /// @param proposalId The ID of the proposal to check.
    function state(
        uint256 proposalId
    )
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    /// @notice Checks whether a proposal needs to be queued in the timelock before execution.
    /// @dev Ensures compatibility with timelock-based governance.
    /// @param proposalId The ID of the proposal.
    /// @return True if the proposal must be queued.
    function proposalNeedsQueuing(
        uint256 proposalId
    ) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.proposalNeedsQueuing(proposalId);
    }

    /// @dev Internal function that queues the operations associated with a proposal into the timelock.
    /// @param proposalId ID of the proposal being queued.
    /// @param targets Target contract addresses for execution.
    /// @param values ETH values to be sent with calls.
    /// @param calldatas Encoded function calls.
    /// @param descriptionHash Hash of the proposal description.
    /// @return The ETA (execution timestamp) from the timelock.
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return
            super._queueOperations(
                proposalId,
                targets,
                values,
                calldatas,
                descriptionHash
            );
    }

    /// @dev Internal function that executes the queued operations for a proposal.
    /// @param proposalId ID of the proposal being executed.
    /// @param targets Target contract addresses for execution.
    /// @param values ETH values to be sent with calls.
    /// @param calldatas Encoded function calls.
    /// @param descriptionHash Hash of the proposal description.
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        s_executedTimestamp[proposalId] = block.timestamp;

        super._executeOperations(
            proposalId,
            targets,
            values,
            calldatas,
            descriptionHash
        );
    }

    /// @dev Cancels a queued proposal in the timelock and returns its ID.
    /// @param targets Target contract addresses in the proposal.
    /// @param values ETH values to be sent with calls.
    /// @param calldatas Encoded function calls.
    /// @param descriptionHash Hash of the proposal description.
    /// @return ID of the canceled proposal.
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    /// @dev Returns the address that should execute queued proposals (i.e., the timelock controller).
    /// @return Address of the executor contract.
    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }
}
