// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GovernanceToken} from "../src/token/GovernanceToken.sol";
import {StakedGovernanceToken} from "../src/token/StakedGovernanceToken.sol";

contract StakedGovernanceTokenTest is Test {
    GovernanceToken internal underlying;
    StakedGovernanceToken internal staked;

    address internal recipient = makeAddr("recipient");
    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 internal constant INITIAL_SUPPLY = 1_000 ether;
    uint256 internal constant MAX_SUPPLY = 10_000 ether;

    function setUp() public {
        underlying = new GovernanceToken(
            "Test Token", "TT", INITIAL_SUPPLY, MAX_SUPPLY, recipient, owner
        );
        staked = new StakedGovernanceToken(address(underlying), "Staked Test Token", "sTT");

        vm.prank(recipient);
        assertTrue(underlying.transfer(alice, 500 ether), "transfer failed");
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_SetsUnderlying() public view {
        assertEq(address(staked.underlying()), address(underlying));
    }

    function test_Constructor_RevertsOnZeroUnderlying() public {
        vm.expectRevert(StakedGovernanceToken.ZeroUnderlying.selector);
        new StakedGovernanceToken(address(0), "Staked Test Token", "sTT");
    }

    /*//////////////////////////////////////////////////////////////
                                STAKING
    //////////////////////////////////////////////////////////////*/

    function test_Stake_RevertsOnZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(StakedGovernanceToken.ZeroAmount.selector);
        staked.stake(0);
    }

    function test_Stake_RevertsWithoutApproval() public {
        vm.prank(alice);
        vm.expectRevert();
        staked.stake(100 ether);
    }

    function test_Stake_PullsUnderlyingAndMintsStaked() public {
        vm.startPrank(alice);
        underlying.approve(address(staked), 200 ether);
        staked.stake(200 ether);
        vm.stopPrank();

        assertEq(underlying.balanceOf(alice), 300 ether);
        assertEq(underlying.balanceOf(address(staked)), 200 ether);
        assertEq(staked.balanceOf(alice), 200 ether);
    }

    function test_Stake_AutoDelegatesToSelfOnFirstStake() public {
        assertEq(staked.delegates(alice), address(0));

        vm.startPrank(alice);
        underlying.approve(address(staked), 200 ether);
        staked.stake(200 ether);
        vm.stopPrank();

        assertEq(staked.delegates(alice), alice);
        assertEq(staked.getVotes(alice), 200 ether);
    }

    function test_Stake_PreservesExistingDelegationOnSubsequentStakes() public {
        vm.startPrank(alice);
        underlying.approve(address(staked), 500 ether);
        staked.stake(100 ether);

        // Alice delegates elsewhere after her first stake.
        staked.delegate(bob);
        assertEq(staked.delegates(alice), bob);

        // A second stake must not silently override that choice back to
        // self-delegation.
        staked.stake(100 ether);
        vm.stopPrank();

        assertEq(staked.delegates(alice), bob);
        assertEq(staked.getVotes(bob), 200 ether);
        assertEq(staked.getVotes(alice), 0);
    }

    function test_Stake_EmitsStakedEvent() public {
        vm.startPrank(alice);
        underlying.approve(address(staked), 200 ether);

        vm.expectEmit(true, false, false, true);
        emit StakedGovernanceToken.Staked(alice, 200 ether);
        staked.stake(200 ether);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                UNSTAKING
    //////////////////////////////////////////////////////////////*/

    function test_Unstake_RevertsOnZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(StakedGovernanceToken.ZeroAmount.selector);
        staked.unstake(0);
    }

    function test_Unstake_RevertsWithoutSufficientStakedBalance() public {
        vm.prank(alice);
        vm.expectRevert();
        staked.unstake(1 ether);
    }

    function test_Unstake_BurnsStakedAndReturnsUnderlying() public {
        vm.startPrank(alice);
        underlying.approve(address(staked), 200 ether);
        staked.stake(200 ether);

        staked.unstake(150 ether);
        vm.stopPrank();

        assertEq(staked.balanceOf(alice), 50 ether);
        assertEq(underlying.balanceOf(alice), 450 ether);
        assertEq(underlying.balanceOf(address(staked)), 50 ether);
    }

    function test_Unstake_ReducesVotingPower() public {
        vm.startPrank(alice);
        underlying.approve(address(staked), 200 ether);
        staked.stake(200 ether);
        staked.unstake(200 ether);
        vm.stopPrank();

        assertEq(staked.getVotes(alice), 0);
    }

    function test_Unstake_EmitsUnstakedEvent() public {
        vm.startPrank(alice);
        underlying.approve(address(staked), 200 ether);
        staked.stake(200 ether);

        vm.expectEmit(true, false, false, true);
        emit StakedGovernanceToken.Unstaked(alice, 200 ether);
        staked.unstake(200 ether);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
            HISTORICAL VOTE INTEGRITY (the whole point of this design)
    //////////////////////////////////////////////////////////////*/

    function test_GetPastVotes_UnaffectedByLaterUnstaking() public {
        vm.startPrank(alice);
        underlying.approve(address(staked), 200 ether);
        staked.stake(200 ether);
        vm.stopPrank();

        uint256 snapshotBlock = block.number;
        vm.roll(block.number + 1);

        // Alice fully unstakes after the snapshot.
        vm.prank(alice);
        staked.unstake(200 ether);
        vm.roll(block.number + 1);

        // Her voting power right now is zero...
        assertEq(staked.getVotes(alice), 0);
        // ...but the historical snapshot is untouched - a proposal that
        // already recorded her vote or counted her toward quorum at that
        // block keeps that record intact.
        assertEq(staked.getPastVotes(alice, snapshotBlock), 200 ether);
    }

    function test_GetPastTotalSupply_ReflectsStakedSupplyOverTime() public {
        vm.startPrank(alice);
        underlying.approve(address(staked), 200 ether);
        staked.stake(200 ether);
        vm.stopPrank();

        uint256 blockAfterFirstStake = block.number;
        vm.roll(block.number + 1);

        vm.prank(recipient);
        assertTrue(underlying.transfer(bob, 100 ether), "transfer failed");
        vm.startPrank(bob);
        underlying.approve(address(staked), 100 ether);
        staked.stake(100 ether);
        vm.stopPrank();

        vm.roll(block.number + 1);

        assertEq(staked.getPastTotalSupply(blockAfterFirstStake), 200 ether);
        assertEq(staked.getPastTotalSupply(block.number - 1), 300 ether);
    }
}
