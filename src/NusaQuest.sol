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

contract NusaQuest is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    ReentrancyGuard
{
    //
    enum Role {
        UNREGISTERED,
        VOTER,
        PROPOSER,
        PARTICIPANT
    }
    enum Action {
        PROPOSE,
        VOTE
    }

    mapping(uint256 => mapping(address => string)) private s_proof;
    mapping(uint256 => mapping(address => Role)) private s_userRole;
    mapping(uint256 => bool) private s_proposalExist;
    mapping(address => uint256) private s_lastProposeTimestamp;
    mapping(address => uint256) private s_lastVoteTimestamp;
    mapping(address => bool) private s_canMint;

    uint256[] private s_proposalIds;

    uint256 private constant PROPOSER_REWARD = 25;
    uint256 private constant VOTER_REWARD = 15;
    uint256 private constant PARTICIPANT_REWARD = 60;
    uint256 private constant DAILY_REWARD = 2;
    uint256 private constant ACTION_COOLDOWN_PERIOD = 1 minutes;
    uint256 private constant QUEST_DEADLINE = 7 days;

    NusaReward private i_nusaReward;
    NusaToken private i_nusaToken;
    NusaTimelock private i_nusaTimelock;

    modifier validateRole(
        address _user,
        uint256 _proposalId,
        Role _expected
    ) {
        _checkRole(_user, _proposalId, _expected);
        _;
    }

    modifier validateProposalExistence(uint256 _proposalId, bool _expected) {
        _checkProposalExistence(_proposalId, _expected);
        _;
    }

    modifier validateLastActionTimestamp(address _user, Action _action) {
        _checkLastActionTimestamp(_user, _action);
        _;
    }

    modifier validateMintAccess(address _user) {
        _checkMintAccess(_user);
        _;
    }

    modifier validateProofExistence(
        uint256 _proposalId,
        address _user,
        bool _expected
    ) {
        _checkProofExistence(_proposalId, _user, _expected);
        _;
    }

    modifier validateState(uint256 _proposalId, ProposalState _expected) {
        _checkState(_proposalId, _expected);
        _;
    }

    modifier validateQuestDeadline(uint256 _proposalId) {
        _checkQuestDeadline(_proposalId);
        _;
    }

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
        s_userRole[proposalId][msg.sender] = Role.PROPOSER;
        s_proposalIds.push(proposalId);

        emit Events.Proposed(proposalId);
    }

    function vote(
        uint256 _proposalId,
        uint8 _support,
        string calldata _reason
    )
        external
        validateProposalExistence(_proposalId, true)
        validateLastActionTimestamp(msg.sender, Action.VOTE)
        validateRole(msg.sender, _proposalId, Role.UNREGISTERED)
        returns (uint256)
    {
        s_userRole[_proposalId][msg.sender] = Role.VOTER;
        s_lastVoteTimestamp[msg.sender] = block.timestamp;

        emit Events.Voted(_proposalId, _support, msg.sender);

        return castVoteWithReason(_proposalId, _support, _reason);
    }

    function swap(uint256 _nftId) external nonReentrant {
        uint256 amount = i_nusaReward.nftPrice(_nftId);
        i_nusaToken.burn(msg.sender, amount);
        i_nusaReward.transfer(_nftId, msg.sender);

        emit Events.Swapped(msg.sender, _nftId);
    }

    function claimProposerReward(address _user) external onlyGovernance {
        i_nusaToken.mint(_user, PROPOSER_REWARD);

        emit Events.Claimed(_user, PROPOSER_REWARD);
    }

    function claimVoterReward(
        uint256 _proposalId
    )
        external
        validateRole(msg.sender, _proposalId, Role.VOTER)
        validateState(_proposalId, ProposalState.Executed)
    {
        i_nusaToken.mint(msg.sender, VOTER_REWARD);

        emit Events.Claimed(msg.sender, VOTER_REWARD);
    }

    function claimParticipantReward(
        uint256 _proposalId,
        string memory _proof
    )
        external
        validateProposalExistence(_proposalId, true)
        validateProofExistence(_proposalId, msg.sender, false)
        validateState(_proposalId, ProposalState.Executed)
        validateQuestDeadline(_proposalId)
    {
        s_proof[_proposalId][msg.sender] = _proof;
        i_nusaToken.mint(msg.sender, PARTICIPANT_REWARD);

        emit Events.Claimed(msg.sender, PARTICIPANT_REWARD);
    }

    function mint(
        uint256[] memory _ids,
        uint256[] memory _values,
        uint256[] memory _prices,
        string[] memory _uris
    ) external validateMintAccess(msg.sender) {
        i_nusaReward.mint(_ids, _values, _prices, _uris);

        emit Events.Minted(_ids);
    }

    function uri(uint256 _id) external view returns (string memory) {
        return i_nusaReward.tokenURI(_id);
    }

    function nftPrice(uint256 _id) external view returns (uint256) {
        return i_nusaReward.nftPrice(_id);
    }

    function nftBalance(
        address _user,
        uint256 _nftId
    ) external view returns (uint256) {
        return i_nusaReward.balance(_user, _nftId);
    }

    function ftBalance(address _user) external view returns (uint256) {
        return i_nusaToken.balance(_user);
    }

    function isAuthorizedMinter(address _user) external view returns (bool) {
        return s_canMint[_user];
    }

    function votingPeriod()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function votingDelay()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function executionDelay() external view returns (uint256) {
        return NusaTimelock(payable(timelock())).getMinDelay();
    }

    function proof(
        uint256 _proposalId,
        address _user
    ) external view returns (string memory) {
        return s_proof[_proposalId][_user];
    }

    function userRole(
        uint256 _proposalId,
        address _user
    ) external view returns (uint8) {
        return uint8(s_userRole[_proposalId][_user]);
    }

    function proposalIds() external view returns (uint256[] memory) {
        return s_proposalIds;
    }

    function proposalExist(uint256 _proposalId) external view returns (bool) {
        return s_proposalExist[_proposalId];
    }

    function lastProposeTimestamp(
        address _user
    ) external view returns (uint256) {
        return s_lastProposeTimestamp[_user];
    }

    function lastVoteTimestamp(address _user) external view returns (uint256) {
        return s_lastVoteTimestamp[_user];
    }

    function _checkRole(
        address _user,
        uint256 _proposalId,
        Role _expected
    ) private view {
        require(
            s_userRole[_proposalId][_user] == _expected,
            Errors.UnauthorizedRole(
                _user,
                _proposalId,
                uint8(s_userRole[_proposalId][_user])
            )
        );
    }

    function _checkProposalExistence(
        uint256 _proposalId,
        bool _expected
    ) private view {
        require(
            s_proposalExist[_proposalId] == _expected,
            Errors.InvalidProposalExistence(_proposalId, !_expected)
        );
    }

    function _checkProofExistence(
        uint256 _proposalId,
        address _user,
        bool _expected
    ) private view {
        require(
            _expected
                ? bytes(s_proof[_proposalId][_user]).length > 0
                : bytes(s_proof[_proposalId][_user]).length == 0,
            Errors.InvalidProofExistence(_proposalId, _user, !_expected)
        );
    }

    function _checkState(
        uint256 _proposalId,
        ProposalState _state
    ) private view {
        require(
            state(_proposalId) == _state,
            Errors.InvalidProposalState(_proposalId, uint8(state(_proposalId)))
        );
    }

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

    function _checkMintAccess(address _user) private view {
        require(s_canMint[_user], Errors.MintAccessDenied(_user));
    }

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

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

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

    function proposalNeedsQueuing(
        uint256 proposalId
    ) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.proposalNeedsQueuing(proposalId);
    }

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

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(
            proposalId,
            targets,
            values,
            calldatas,
            descriptionHash
        );
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }
    //
}
