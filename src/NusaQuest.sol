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
    enum Request {
        QUEST,
        REWARD
    }

    mapping(uint256 => mapping(uint256 => mapping(address => string)))
        private s_proof;
    mapping(uint256 => mapping(address => Role)) private s_userRole;
    mapping(uint256 => Request) private s_requestType;
    mapping(uint256 => bool) private s_proposalExist;
    mapping(address => uint256) private s_lastActionTimestamp;
    mapping(address => bool) private s_canMint;
    mapping(address => bool) private s_alreadyDelegate;

    uint256[] private s_questIds;
    uint256[] private s_submissionIds;

    uint256 private constant PROPOSER_REWARD = 30;
    uint256 private constant VOTER_REWARD = 20;
    uint256 private constant PARTICIPANT_REWARD = 80;
    uint256 private constant ACTION_COOLDOWN_PERIOD = 1 days;

    NusaReward private i_nusaReward;
    NusaToken private i_nusaToken;

    modifier validateRole(
        address _user,
        uint256 _proposalId,
        Role _expectedRole
    ) {
        _checkRole(_user, _proposalId, _expectedRole);
        _;
    }

    modifier validateProposalExistence(
        uint256 _proposalId,
        bool _expectedValue
    ) {
        _checkProposalExistence(_proposalId, _expectedValue);
        _;
    }

    modifier validateLastActionTimestamp(address _user) {
        _checkLastActionTimestamp(_user);
        _;
    }

    modifier validateMintAccess(address _user) {
        _checkMintAccess(_user);
        _;
    }

    constructor(
        NusaToken _token,
        NusaTimelock _timelock,
        uint48 _votingDelay,
        uint32 _votingPeriod
    )
        Governor("NusaDAO")
        GovernorSettings(_votingDelay, _votingPeriod, 0)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(1)
        GovernorTimelockControl(_timelock)
    {
        i_nusaReward = new NusaReward(address(this));
        i_nusaToken = _token;
        i_nusaToken.setNusaQuest(address(this));
        s_canMint[msg.sender] = true;
    }

    function delegate() external {
        i_nusaToken.delegate(msg.sender);
        s_alreadyDelegate[msg.sender] = true;
    }

    function initiate(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description,
        string memory _hash,
        uint256 _questId,
        Request _request
    ) external validateLastActionTimestamp(msg.sender) {
        uint256 proposalId = propose(
            _targets,
            _values,
            _calldatas,
            _description
        );
        _checkProposalExistence(proposalId, false);
        _checkRole(msg.sender, proposalId, Role.UNREGISTERED);

        s_requestType[proposalId] = _request;
        s_proposalExist[proposalId] = true;
        s_lastActionTimestamp[msg.sender] = block.timestamp;

        if (_request == Request.QUEST) {
            s_userRole[proposalId][msg.sender] = Role.PROPOSER;
            s_questIds.push(proposalId);
        } else if (_request == Request.REWARD) {
            s_userRole[proposalId][msg.sender] = Role.PARTICIPANT;
            s_proof[_questId][proposalId][msg.sender] = _hash;
            s_submissionIds.push(proposalId);
        }
    }

    function vote(
        uint256 _proposalId,
        uint8 _support,
        string calldata _reason
    )
        external
        nonReentrant
        validateProposalExistence(_proposalId, true)
        validateLastActionTimestamp(msg.sender)
        validateRole(msg.sender, _proposalId, Role.UNREGISTERED)
        returns (uint256)
    {
        s_userRole[_proposalId][msg.sender] = Role.VOTER;
        s_lastActionTimestamp[msg.sender] = block.timestamp;
        return castVoteWithReason(_proposalId, _support, _reason);
    }

    function swap(uint256 _amount, uint256 _nftId) external nonReentrant {
        i_nusaToken.burn(msg.sender, _amount);
        i_nusaReward.transfer(_nftId, msg.sender);
    }

    function claim(uint256 _proposalId, address _user) external {
        Role role = s_userRole[_proposalId][_user];

        if (role == Role.PROPOSER) {
            _checkGovernance();
            i_nusaToken.mint(_user, PROPOSER_REWARD);
        } else if (role == Role.PARTICIPANT) {
            _checkGovernance();
            i_nusaToken.mint(_user, PARTICIPANT_REWARD);
        } else if (role == Role.VOTER) {
            _checkVoter(_proposalId, msg.sender);
            i_nusaToken.mint(_user, VOTER_REWARD);
        }
    }

    function mint(
        uint256[] memory _ids,
        uint256[] memory _values,
        uint256[] memory _prices,
        string[] memory _uris
    ) external validateMintAccess(msg.sender) {
        i_nusaReward.mint(_ids, _values, _prices, _uris);
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

    function isAlreadyDelegate(address _user) external view returns (bool) {
        return s_alreadyDelegate[_user];
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
        uint256 _questId,
        uint256 _submissionId,
        address _user
    ) external view returns (string memory) {
        return s_proof[_questId][_submissionId][_user];
    }

    function userRole(
        uint256 _proposalId,
        address _user
    ) external view returns (Role) {
        return s_userRole[_proposalId][_user];
    }

    function questIds() external view returns (uint256[] memory) {
        return s_questIds;
    }

    function submissionIds() external view returns (uint256[] memory) {
        return s_submissionIds;
    }

    function requestType(uint256 _proposalId) external view returns (Request) {
        return s_requestType[_proposalId];
    }

    function proposalExist(uint256 _proposalId) external view returns (bool) {
        return s_proposalExist[_proposalId];
    }

    function lastActionTimestamp(
        address _user
    ) external view returns (uint256) {
        return s_lastActionTimestamp[_user];
    }

    function _checkRole(
        address _user,
        uint256 _proposalId,
        Role _expectedRole
    ) private view {
        require(
            s_userRole[_proposalId][_user] == _expectedRole,
            "You are not authorized to perform this action."
        );
    }

    function _checkProposalExistence(
        uint256 _proposalId,
        bool _expectedValue
    ) private view {
        require(
            s_proposalExist[_proposalId] == _expectedValue,
            "Invalid proposal existence."
        );
    }

    function _checkVoter(uint256 _proposalId, address _user) private view {
        _checkRole(_user, _proposalId, Role.VOTER);
        require(
            state(_proposalId) == ProposalState.Executed,
            "Proposal must be executed first."
        );
    }

    function _checkLastActionTimestamp(address _user) private view {
        require(
            s_lastActionTimestamp[_user] + ACTION_COOLDOWN_PERIOD >
                block.timestamp,
            "Cooldown period between actions is not finished."
        );
    }

    function _checkMintAccess(address _user) private view {
        require(s_canMint[_user], "You do not have permission to mint an NFT.");
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
