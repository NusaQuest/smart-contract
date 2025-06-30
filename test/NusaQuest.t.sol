// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {NusaQuest} from "../src/NusaQuest.sol";
import {NusaQuestScript} from "../script/NusaQuest.s.sol";

contract NusaQuestTest is Test {
    //
    NusaQuest private nusaQuest;

    address private constant DEPLOYER = address(1);
    address private constant BOB = address(2);
    address private constant ALICE = address(3);
    address private constant CHARLIE = address(4);

    uint8 private constant QUEST_REQUEST = 0;
    uint8 private constant REWARD_REQUEST = 1;

    address[] private i_targets;
    uint256[] private i_values;
    bytes[] private i_calldatas;

    string private _description1 = "lorem ipsum dolor sit amet";
    string private _hash = "NusaQuest";

    function setUp() public {
        NusaQuestScript nusaQuestScript = new NusaQuestScript();
        nusaQuest = nusaQuestScript.run();

        i_targets.push(BOB);
        i_values.push(0);
        i_calldatas.push(
            abi.encodeWithSignature("claimProposerReward(address)", BOB)
        );
    }

    function testSuccessfullyInitiateQuest() public {
        vm.startPrank(BOB);
        nusaQuest.initiate(
            i_targets,
            i_values,
            i_calldatas,
            _description1,
            _hash,
            0,
            QUEST_REQUEST
        );
        vm.stopPrank();

        uint256 expectedQuests = 1;
        uint256 actualQuests = nusaQuest.questIds().length;

        assertEq(expectedQuests, actualQuests);
    }

    function testRevertIfProposalAlreadyExist() public {
        testSuccessfullyInitiateQuest();
        vm.warp(5 minutes);
        vm.expectRevert();
        testSuccessfullyInitiateQuest();
    }

    function testRevertIfActionStillOnCooldown() public {}
    //
}
