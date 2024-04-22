// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TimeLock} from "../src/TImeLock.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {GovToken} from "../src/GovToken.sol";
import {Gold} from "../src/Gold.sol";

contract MyGovernorTest is Test {
    Gold public gold;
    GovToken public govToken;
    MyGovernor public myGovernor;
    TimeLock public timelock;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    uint256 public constant MIN_DELAY = 1; // 1hour
    uint256 public constant VOTTING_DELAY = 1; // how many blocks till a vote is active
    uint256 public constant VOTING_PERIOD = 10; // how many blocks till a vote is active
    address[] public proposers;
    address[] public executors;

    uint256[] public values;
    bytes[] public calldatas;
    address[] public targets;

    function setUp() public {
        vm.startPrank(USER);

        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);

        govToken.delegates(USER);
        timelock = new TimeLock(MIN_DELAY, proposers, executors, USER);
        myGovernor = new MyGovernor(govToken, timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(myGovernor));
        timelock.grantRole(executorRole, address(myGovernor));
        timelock.revokeRole(adminRole, USER);

        gold = new Gold(USER);

        gold.transferOwnership(address(timelock));
        vm.stopPrank();
    }

    function testGovernanceUpdatesGold() public {
        uint256 valueToStore = 444;
        string memory description = "store 1 in gold";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);
        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(gold));

        // 1. propose to the DAO
        uint256 proposedId = myGovernor.propose(targets, values, calldatas, description);
        console.log("Proposal State: ", uint256(myGovernor.state(proposedId)));

        vm.warp(block.timestamp + VOTTING_DELAY + 1);
        vm.roll(block.number + VOTTING_DELAY + 1);

        console.log("Proposal State: ", uint256(myGovernor.state(proposedId)));

        // 2 . Vote
        string memory reason = "because blue fog is awesome";

        // * - `support=bravo` refers to the vote options 0 = Against, 1 = For, 2 = Abstain, as in `GovernorBravo`.
        //  * - `quorum=bravo` means that only For votes are counted towards quorum.
        //  * - `quorum=for,abstain` means that both For and Abstain votes are counted towards quorum.
        uint8 voteWay = 1; // voting yes

        myGovernor.castVoteWithReason(proposedId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        bool checkNeedQuee = myGovernor.proposalNeedsQueuing(proposedId);
        console.log(checkNeedQuee);

        bytes32 descriptionHash = keccak256(abi.encodePacked(description));

        vm.prank(USER);
        myGovernor.queueOperations(proposedId, targets, values, calldatas, descriptionHash);
        // proposedId = myGovernor.queue(targets, values, calldatas, descriptionHash);

        console.log("Proposal State: ", uint256(myGovernor.state(proposedId)));

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        myGovernor.execute(targets, values, calldatas, descriptionHash);
        console.log("Gold Value: ", gold.getNumber());
        assert(gold.getNumber() == valueToStore);
    }

    function testCanUpdateGoldWithoutGovernornce() public {
        vm.expectRevert();
        gold.store(1);
    }
}
