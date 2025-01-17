// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Vault.sol";
import "./MockERC20.sol";
import "../src/zkToken.sol";
import "../src/WithdrawVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VaultTest is Test {
    Vault public vault;
    MockERC20 public token;
    address public owner = address(1);
    address public user = address(2);
    address public user2 = address(4);
    address public ceffu = address(3);
    WithdrawVault withdrawVault;

    function setUp() public {
        vm.startPrank(owner);

        // Create new Contract
        token = new MockERC20();

        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = address(token);
        uint256[] memory rewardRate = new uint256[](1);
        rewardRate[0] = 700;
        uint256[] memory minStakeAmount = new uint256[](1);
        minStakeAmount[0] = 0;
        uint256[] memory maxStakeAmount = new uint256[](1);
        maxStakeAmount[0] = type(uint256).max;
        
        zkToken zk = new zkToken("zkUSDT", "zkUSDT", address(owner));
        address[] memory zks = new address[](1);
        zks[0] = address(zk);

        withdrawVault = new WithdrawVault(supportedTokens, owner, owner, owner);

        uint[] memory totals = new uint[](1);
        totals[0] = 0;

        vault = new Vault(
            supportedTokens,
            zks,
            rewardRate,
            minStakeAmount,
            maxStakeAmount,
            owner, // admin
            owner, // bot
            ceffu,
            14 days,
            totals,
            payable(address(withdrawVault)),
            address(0),
            0,
            totals,
            address(0)
        );

        withdrawVault.setVault(address(vault));
        zk.setToVault(address(vault), address(vault));

        vm.stopPrank();

        vm.warp(block.timestamp + 1);
    }

    function testStake() public {
        // should be zero if user does not stake anything
        uint256 claimableAssets = vault.getClaimableAssets(user, address(token));
        uint256 claimableRewards = vault.getClaimableRewards(user, address(token));
        uint256 totalRewards = vault.getTotalRewards(user, address(token));
        assertEq(claimableAssets, 0);
        assertEq(claimableRewards, 0);
        assertEq(totalRewards, 0);

        vm.startPrank(user);
        token.mint(user, 500 ether);
        token.approve(address(vault), 500 ether);

        // Stake 500 tokens
        vault.stake_66380860(address(token), 500 ether);

        // Check user's staked amount
        uint256 stakedAmount = vault.getStakedAmount(user, address(token));
        assertEq(stakedAmount, 500 ether);
        assertEq(token.balanceOf(user), 0);

        // Ensure Vault's token balance updated
        assertEq(token.balanceOf(address(vault)), 500 ether);

        //ensure zkToken minted & equal to staked amount
        uint zkAmount = vault.getZKTokenAmount(user, address(token));
        assertEq(zkAmount, vault.convertToShares(500 ether, address(token)));
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(user2);

        token.mint(user2, 500 ether);
        token.approve(address(vault), 500 ether);

        vault.stake_66380860(address(token), 500 ether);

        // Check user's staked amount
        uint256 stakedAmount1 = vault.getStakedAmount(user2, address(token));
        assertEq(stakedAmount1, 500 ether);
        assertEq(token.balanceOf(user2), 0);

        // Ensure Vault's token balance updated
        assertEq(token.balanceOf(address(vault)), 1000 ether);

        uint zkAmount1 = vault.getZKTokenAmount(user2, address(token));

        // ensure the correct amount of zkToken is minted
        assertEq(zkAmount1, vault.convertToShares(500 ether, address(token)));

        vm.stopPrank();

        //ensure the all rewards calculate correctly
        vm.warp(block.timestamp + 1 days);

        uint userReward = vault.getClaimableRewards(user, address(token));
        uint user1Reward = vault.getClaimableRewards(user2, address(token));
        uint allReward = vault.getTotalRewards(address(vault), address(token));
        assertEq(userReward + user1Reward, allReward);
    }


    function testAddSupportedToken() public {
        vm.startPrank(owner);

        address usdt = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        string memory name = "zkUSDT";
        string memory symbol = "zkUSDT";

        zkToken zk = new zkToken(name, symbol, owner);

        vault.addSupportedToken(usdt, 1, 2, address(zk));
        assertEq(vault.supportedTokens(usdt), true);
        assertGt(uint256(uint160(address(vault.supportedTokenToZkToken(usdt)))), 0);

        vm.stopPrank();
    }


    function testRequestClaim() public returns (uint256, uint256) {
        vm.startPrank(user);
        token.mint(user, 500 ether);
        token.approve(address(vault), 500 ether);
        vault.stake_66380860(address(token), 500 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(user2);
        token.mint(user2, 500 ether);
        token.approve(address(vault), 500 ether);
        vault.stake_66380860(address(token), 500 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(user);
        uint reward = vault.getClaimableRewards(user, address(token));
        uint withdrawAmount = 500 ether + reward;
        // Request to withdraw 500 tokens
        uint256 requestID = vault.requestClaim_8135334(address(token), withdrawAmount);
        vm.stopPrank();

        vm.startPrank(user2);
        reward = vault.getClaimableRewards(user2, address(token));
        uint withdrawAmount1 = 500 ether + reward;
        // Request to withdraw 500 tokens
        uint requestID1 = vault.requestClaim_8135334(address(token), withdrawAmount1);
        vm.stopPrank();


        // Validate the withdrawal request
        ClaimItem memory claimItem = vault.getClaimQueueInfo(requestID);
        assertEq(claimItem.totalAmount, withdrawAmount);
        assertEq(claimItem.token, address(token));

        ClaimItem memory claimItem1 = vault.getClaimQueueInfo(requestID1);
        assertEq(claimItem1.totalAmount, withdrawAmount1);
        assertEq(claimItem.token, address(token));

        //burn all zkTokens
        assertEq(vault.getZKTokenAmount(user, address(token)), 0);
        assertEq(vault.getZKTokenAmount(user2, address(token)), 0);

        return (requestID, requestID1);
    }

/*
    user1 stake 500 ether 2day later reward 191649555099247091
    user2 stake 500 ether 1day later reward 95824777549623545
    claim all
*/
    function testClaimLegally_A() public{
        (uint queueId, uint queueId1) = testRequestClaim();
        token.mint(address(withdrawVault), 1500 ether);//for reward

        vm.warp(block.timestamp + 14 days);

        vm.startPrank(user);
        vault.claim_41202704(queueId, address(token));

        ClaimItem memory claimItem = vault.getClaimQueueInfo(queueId);
        //the user received the correct amount of tokens
        assertEq(token.balanceOf(user), claimItem.totalAmount);
        vm.stopPrank();

        vm.warp(block.timestamp + 1);

        vm.startPrank(user2);
        vault.claim_41202704(queueId1, address(token));

        ClaimItem memory claimItem1 = vault.getClaimQueueInfo(queueId1);
        // //the user received the correct amount of tokens
        assertEq(token.balanceOf(user2), claimItem1.totalAmount);
        vm.stopPrank();

    }

/*
    user1 stake 500 ether 2day later reward 191649555099247091
    user2 stake 500 ether 1day later reward 95824777549623545
    user1 and user2 both claim 95824777549623545
    user1 < reward, user2 == reward
*/

    function testClaimLegally_B() public{
        vm.startPrank(user);
        token.mint(user, 500 ether);
        token.approve(address(vault), 500 ether);
        vault.stake_66380860(address(token), 500 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(user2);
        token.mint(user2, 500 ether);
        token.approve(address(vault), 500 ether);
        vault.stake_66380860(address(token), 500 ether);
        vm.stopPrank();

        vm.warp(vm.getBlockTimestamp() + 1 days);

        vm.startPrank(user);
        uint user1Reward = vault.getClaimableRewards(user, address(token));
        uint withdrawAmount = vault.getClaimableRewards(user2, address(token));
        // Request to withdraw 95824777549623545
        uint256 requestID = vault.requestClaim_8135334(address(token), withdrawAmount);
        assertEq(vault.getClaimableRewards(user, address(token)), user1Reward - withdrawAmount);
        vm.stopPrank();

        vm.startPrank(user2);
        // Request to withdraw 95824777549623545
        uint requestID1 = vault.requestClaim_8135334(address(token), withdrawAmount);

        assertEq(vault.getClaimableRewards(user2, address(token)), 0);
        vm.stopPrank();

        vm.warp(block.timestamp + 14 days);
        token.mint(address(withdrawVault), 1000 ether);

        vm.startPrank(user);
        vault.claim_41202704(requestID, address(token));
        ClaimItem memory claimItem = vault.getClaimQueueInfo(requestID);
        //the user received the correct amount of tokens
        assertEq(token.balanceOf(user), claimItem.totalAmount);
        vm.stopPrank();

        vm.startPrank(user2);
        vault.claim_41202704(requestID1, address(token));
        ClaimItem memory claimItem1 = vault.getClaimQueueInfo(requestID1);
        //the user received the correct amount of tokens
        assertEq(token.balanceOf(user2), claimItem1.totalAmount);
        vm.stopPrank();

        console.log(vault.convertToShares(vault.getClaimableAssets(user, address(token)), address(token)), vault.getZKTokenAmount(user, address(token)));
        console.log(vault.convertToShares(vault.getClaimableAssets(user2, address(token)), address(token)), vault.getZKTokenAmount(user2, address(token)));
    }

/*
    user1 stake 500 ether 2day later reward 191649555099247091
    user2 stake 500 ether 1day later reward 95824777549623545
    claim reward + 100 ether
*/

    function testClaimLegally_C() public{
        vm.startPrank(user);
        token.mint(user, 500 ether);
        token.approve(address(vault), 500 ether);
        vault.stake_66380860(address(token), 500 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(user2);
        token.mint(user2, 500 ether);
        token.approve(address(vault), 500 ether);
        vault.stake_66380860(address(token), 500 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(user);
        uint withdrawAmount = vault.getClaimableRewards(user, address(token)) + 100 ether;
        // Request to withdraw 95824777549623545
        uint256 requestID = vault.requestClaim_8135334(address(token), withdrawAmount);
        vm.stopPrank();

        vm.startPrank(user2);
        uint withdrawAmount1 = vault.getClaimableRewards(user2, address(token)) + 100 ether;
        // Request to withdraw 95824777549623545
        uint requestID1 = vault.requestClaim_8135334(address(token), withdrawAmount1);
        vm.stopPrank();

        vm.warp(block.timestamp + 14 days);
        token.mint(address(withdrawVault), 1000 ether);

        vm.startPrank(user);
        vault.claim_41202704(requestID, address(token));
        ClaimItem memory claimItem = vault.getClaimQueueInfo(requestID);
        //the user received the correct amount of tokens
        assertEq(token.balanceOf(user), claimItem.totalAmount);
        vm.stopPrank();

        vm.startPrank(user2);
        vault.claim_41202704(requestID1, address(token));
        ClaimItem memory claimItem1 = vault.getClaimQueueInfo(requestID1);
        //the user received the correct amount of tokens
        assertEq(token.balanceOf(user2), claimItem1.totalAmount);
        vm.stopPrank();

        console.log(vault.convertToShares(vault.getClaimableAssets(user, address(token)), address(token)), vault.getZKTokenAmount(user, address(token)));
        console.log(vault.convertToShares(vault.getClaimableAssets(user2, address(token)), address(token)), vault.getZKTokenAmount(user2, address(token)));
    }

/*
    user1 stake 500 ether 2day later reward 191649555099247091
    user2 stake 500 ether 1day later reward 95824777549623545
    claim all
    user1 get (500Ether + 191649555099247091) * 9950 / 10000
    user2 get (500Ether + 95824777549623545) * 9950 / 10000
**/

    function testFlashWithdrawWithPenalty_A() public {
        vm.startPrank(user);
        token.mint(user, 500 ether);
        token.approve(address(vault), 500 ether);
        vault.stake_66380860(address(token), 500 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(user2);
        token.mint(user2, 500 ether);
        token.approve(address(vault), 500 ether);
        vault.stake_66380860(address(token), 500 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        uint BASE = 10000;
        uint penalty = 50;

        vm.startPrank(user);
        uint withdrawAmount = vault.getClaimableAssets(user, address(token));
        vault.flashWithdrawWithPenalty(address(token), withdrawAmount);
        assertEq(token.balanceOf(user), withdrawAmount * (BASE - penalty) / BASE);
        vm.stopPrank();

        vm.startPrank(user2);
        uint withdrawAmount1 = vault.getClaimableAssets(user2, address(token));
        vault.flashWithdrawWithPenalty(address(token), withdrawAmount1);
        assertEq(token.balanceOf(user), withdrawAmount * (BASE - penalty) / BASE);
        vm.stopPrank();

        assertEq(vault.totalStakeAmountByToken(address(token)), 0);
        assertEq(vault.totalRewardsAmountByToken(address(token)), 0);
        assertEq(vault.getZKTokenAmount(user, address(token)), 0);
        assertEq(vault.getZKTokenAmount(user2, address(token)), 0);
        assertEq(vault.supportedTokenToZkToken(address(token)).totalSupply(), 0);
    }

/*
    user1 stake 500 ether 2day later reward 191649555099247091
    user2 stake 500 ether 1day later reward 95824777549623545
    claim 95824777549623545
    both get 95824777549623545 * 9950 / 10000
**/

    function testFlashWithdrawWithPenalty_B() public {
        vm.startPrank(user);
        token.mint(user, 500 ether);
        token.approve(address(vault), 500 ether);
        vault.stake_66380860(address(token), 500 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(user2);
        token.mint(user2, 500 ether);
        token.approve(address(vault), 500 ether);
        vault.stake_66380860(address(token), 500 ether);
        vm.stopPrank();

        vm.warp(vm.getBlockTimestamp() + 1 days);
        uint BASE = 10000;
        uint penalty = 50;

        vm.startPrank(user);
        uint withdrawAmount = vault.getClaimableRewards(user2, address(token));
        uint user1Reward = vault.getClaimableRewards(user, address(token));
        vault.flashWithdrawWithPenalty(address(token), withdrawAmount);
        assertEq(token.balanceOf(user), withdrawAmount * (BASE - penalty) / BASE);
        vm.stopPrank();

        vm.startPrank(user2);
        vault.flashWithdrawWithPenalty(address(token), withdrawAmount);
        assertEq(token.balanceOf(user), withdrawAmount * (BASE - penalty) / BASE);
        vm.stopPrank();

        assertEq(vault.getClaimableRewards(user2, address(token)), 0);
        assertEq(vault.getClaimableRewards(user, address(token)), user1Reward - withdrawAmount);
        assertEq(vault.getStakedAmount(user, address(token)), vault.getStakedAmount(user2, address(token)));

        console.log(vault.convertToAssets(vault.getZKTokenAmount(user, address(token)), address(token)), vault.getClaimableAssets(user, address(token)));
        console.log(vault.convertToAssets(vault.getZKTokenAmount(user2, address(token)), address(token)), vault.getClaimableAssets(user2, address(token)));
    }

/*
    user1 stake 500 ether 2day later reward 191649555099247091
    user2 stake 500 ether 1day later reward 95824777549623545
    claim reward + 100 ether
    user1 get (100Ether + 191649555099247091) * 9950 / 10000
    user2 get (100Ether + 95824777549623545) * 9950 / 10000
**/
    
    function testFlashWithdrawWithPenalty_C() public {
        vm.startPrank(user);
        token.mint(user, 500 ether);
        token.approve(address(vault), 500 ether);
        vault.stake_66380860(address(token), 500 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(user2);
        token.mint(user2, 500 ether);
        token.approve(address(vault), 500 ether);
        vault.stake_66380860(address(token), 500 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        uint BASE = 10000;
        uint penalty = 50;

        vm.startPrank(user);
        uint withdrawAmount = vault.getClaimableRewards(user, address(token)) + 100 ether;
        vault.flashWithdrawWithPenalty(address(token), withdrawAmount);
        assertEq(token.balanceOf(user), withdrawAmount * (BASE - penalty) / BASE);
        vm.stopPrank();

        vm.startPrank(user2);
        uint withdrawAmount1 = vault.getClaimableRewards(user2, address(token)) + 100 ether;
        vault.flashWithdrawWithPenalty(address(token), withdrawAmount1);
        assertEq(token.balanceOf(user2), withdrawAmount1 * (BASE - penalty) / BASE);
        vm.stopPrank();

        assertEq(vault.getClaimableRewards(user2, address(token)), 0);
        assertEq(vault.getClaimableRewards(user, address(token)), 0);
        assertEq(vault.getStakedAmount(user, address(token)), 400 ether);
        assertEq(vault.getStakedAmount(user2, address(token)), 400 ether);

        console.log(vault.convertToAssets(vault.getZKTokenAmount(user, address(token)), address(token)), vault.getClaimableAssets(user, address(token)));
        console.log(vault.convertToAssets(vault.getZKTokenAmount(user2, address(token)), address(token)), vault.getClaimableAssets(user2, address(token)));
    }


    function testRewardAfterUpdateRewardState() public {
        vm.startPrank(user);

        token.mint(user, 500 ether);
        token.approve(address(vault), 500 ether);

        // Stake 500 tokens
        vault.stake_66380860(address(token), 500 ether);

        vm.stopPrank();

        vm.warp(block.timestamp + 10 days);

        vm.startPrank(owner);
        vault.setRewardRate(address(token), 1000);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 days);

        uint userAssets = vault.getClaimableAssets(user, address(token));
        uint totalAssets = vault.getClaimableRewards(address(vault), address(token)) + vault.totalStakeAmountByToken(address(token));

        assertEq(userAssets, totalAssets);


    }
}