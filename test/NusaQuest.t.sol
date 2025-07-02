// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {NusaQuest} from "../src/NusaQuest.sol";
import {NusaToken} from "../src/NusaToken.sol";
import {NusaTimelock} from "../src/NusaTimelock.sol";
import {Errors} from "../src/lib/Errors.l.sol";

contract NusaQuestTest is Test {
    //
    NusaQuest private nusaQuest;
    NusaToken private nusaToken;

    address private constant BOB = address(1);
    address private constant ALICE = address(2);
    address private constant CHARLIE = address(3);

    address[] private _targets = new address[](1);
    uint256[] private _values = new uint256[](1);
    bytes[] private _calldatas = new bytes[](1);
    string private _description = "lorem ipsum dolor sit amet";

    address[] private i_proposers;
    address[] private i_executors;
    address private i_admin;

    function setUp() public {
        uint256 minDelay = 1 minutes;
        uint32 votingDelay = 1 minutes;
        uint32 votingPeriod = 5 minutes;
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

    function testSuccessfullyInitiateQuest() public {
        _targets.push(BOB);
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
        uint8 expectedRole = 2;
        uint8 actualRole = nusaQuest.userRole(proposalId, BOB);

        assertEq(expectedProposals, actualProposals);
        assertEq(expectedRole, actualRole);
    }

    function testRevertIfProposalAlreadyExist() public {
        _targets.push(BOB);
        _values.push(0);
        _calldatas.push(
            abi.encodeWithSignature("claimProposerReward(address)", BOB)
        );

        vm.startPrank(BOB);
        nusaQuest.initiate(_targets, _values, _calldatas, _description);
        vm.stopPrank();

        vm.warp(5 minutes);
        vm.expectRevert();

        vm.startPrank(BOB);
        nusaQuest.initiate(_targets, _values, _calldatas, _description);
        vm.stopPrank();
    }

    function testRevertIfActionStillOnCooldown() public {
        _targets.push(BOB);
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

        _targets.push(BOB);
        _values.push(0);
        _calldatas.push(
            abi.encodeWithSignature("claimProposerReward(address)", BOB)
        );

        vm.startPrank(BOB);
        nusaQuest.initiate(_targets, _values, _calldatas, _description);
        vm.stopPrank();
    }

    function testSuccessfullyVoteOnQuest() public {
        vm.startPrank(ALICE);
        nusaToken.delegate();
        vm.stopPrank();

        vm.roll(block.number + 1);

        _targets.push(BOB);
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

    function testRevertIfProposalDoesNotExist() public {
        uint256 proposalId = 1;
        uint8 support = 1;
        string memory reason = "Nice quest.";

        vm.startPrank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidProposalExistence.selector,
                proposalId,
                true
            )
        );
        nusaQuest.vote(proposalId, support, reason);
        vm.stopPrank();
    }

    //
}
