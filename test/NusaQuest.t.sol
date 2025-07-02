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

    uint256[] private _ids = new uint256[](2);
    uint256[] private _nftValues = new uint256[](2);
    uint256[] private _prices = new uint256[](2);
    string[] private _uris = new string[](2);

    address[] private i_proposers;
    address[] private i_executors;
    address private i_admin;

    function setUp() public {
        uint256 minDelay = 1 minutes;
        uint32 votingDelay = 30; // 1 minutes (60 / 2)
        uint32 votingPeriod = 150; // 5 minutes ((60 * 5) / 2)
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
        uint8 expectedRole = 2;
        uint8 actualRole = nusaQuest.userRole(proposalId, BOB);

        assertEq(expectedProposals, actualProposals);
        assertEq(expectedRole, actualRole);
    }

    function testRevertIfProposalAlreadyExist() public {
        _targets.push(address(nusaQuest));
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

    function testRevertIfProposerVotesOnTheirOwnProposal() public {
        _targets.push(address(nusaQuest));
        _values.push(0);
        _calldatas.push(
            abi.encodeWithSignature("claimProposerReward(address)", BOB)
        );

        vm.startPrank(BOB);
        nusaToken.delegate();

        vm.roll(block.number + 1);

        nusaQuest.initiate(_targets, _values, _calldatas, _description);

        uint256 proposalId = nusaQuest.proposalIds()[0];
        uint256 voteStart = nusaQuest.proposalSnapshot(proposalId);
        uint8 support = 1;
        string memory reason = "Nice quest.";

        vm.roll(voteStart + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.UnauthorizedRole.selector,
                BOB,
                proposalId,
                2
            )
        );
        nusaQuest.vote(proposalId, support, reason);

        vm.stopPrank();
    }

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

    function testSuccessfullyExecuteProposal() public {
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

        vm.startPrank(ALICE);
        nusaQuest.claimVoterReward(proposalId);
        vm.stopPrank();

        vm.startPrank(CHARLIE);
        nusaQuest.claimParticipantReward(proposalId, "NusaQuest");
        vm.stopPrank();

        uint256 expectedBobFtBalance = 25;
        uint256 actualBobFtBalance = nusaQuest.ftBalance(BOB);
        uint256 expectedAliceFtBalance = 25;
        uint256 actualAliceFtBalance = nusaQuest.ftBalance(ALICE);
        uint256 expectedCharlieFtBalance = 60;
        uint256 actualCharlieFtBalance = nusaQuest.ftBalance(CHARLIE);
        string memory expectedProof = "NusaQuest";
        string memory actualProof = nusaQuest.proof(proposalId, CHARLIE);

        assertEq(expectedBobFtBalance, actualBobFtBalance);
        assertEq(expectedAliceFtBalance, actualAliceFtBalance);
        assertEq(expectedCharlieFtBalance, actualCharlieFtBalance);
        assert(
            keccak256(abi.encodePacked(expectedProof)) ==
                keccak256(abi.encodePacked(actualProof))
        );
    }

    function testRevertIfProposalNotExecutedYet() public {
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
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidProposalState.selector,
                proposalId,
                5
            )
        );

        vm.startPrank(ALICE);
        nusaQuest.claimVoterReward(proposalId);
        vm.stopPrank();
    }

    //
}
