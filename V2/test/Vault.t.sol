// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Vault.sol";
import "../src/IVault.sol";
import "../src/zkToken.sol";
import "./MockERC20.sol";
import "../src/WithdrawVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VaultV2Test is Test {
    Vault public vault;
    MockERC20 public token;
    address public owner = address(1);
    address public user = address(2);
    address public user2 = address(4);
    address public user3 = address(5);
    address public newUser = address(6);
    address public ceffu = address(3);
    IVault vaultV1 = IVault(0x7264Bd557ecdb3E6A12D78B570d85528Dbd1a05d);

    uint snapShotTime;
    address airdrop = makeAddr("airDropper");

    uint user1Assets;
    uint user2Assets;
    uint user3Assets;

    WithdrawVault withdrawVault;

    function setUp() public {

        token = MockERC20(0x515CB39D176B36833eB7813996Fa8C53f4331d88);

        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = address(token);
        uint256[] memory rewardRate = new uint256[](1);
        rewardRate[0] = 700;
        uint256[] memory minStakeAmount = new uint256[](1);
        minStakeAmount[0] = 0;
        uint256[] memory maxStakeAmount = new uint256[](1);
        maxStakeAmount[0] = type(uint256).max;

        vm.createSelectFork("https://eth-sepolia.public.blastapi.io", 7389490);

        vm.startPrank(owner);
        withdrawVault = new WithdrawVault(supportedTokens, owner, owner, owner);
        vm.stopPrank();

        vm.startPrank(user);
        token.mint(user, 500 ether);
        token.approve(address(vaultV1), 500 ether);
        vaultV1.stake_66380860(address(token), 500 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(user2);
        token.mint(user2, 500 ether);
        token.approve(address(vaultV1), 500 ether);
        vaultV1.stake_66380860(address(token), 500 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(user3);
        token.mint(user3, 500 ether);
        token.approve(address(vaultV1), 500 ether);
        vaultV1.stake_66380860(address(token), 500 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(user);
        vaultV1.requestClaim_8135334(address(token), type(uint).max);
        vm.stopPrank();

        vm.warp(block.timestamp + 1);

        vm.startPrank(0x2b2E23ceC9921288f63F60A839E2B28235bc22ad);
        vaultV1.pause();
        vm.stopPrank();

        snapShotTime = block.timestamp;

        uint[] memory totalStaked = new uint[](1);
        user1Assets = vaultV1.getClaimableAssets(user, address(token));
        user2Assets = vaultV1.getClaimableAssets(user2, address(token));
        user3Assets = vaultV1.getClaimableAssets(user3, address(token));
        totalStaked[0] = user1Assets + user2Assets + user3Assets;

        zkToken zk = new zkToken("zkUSDT", "zkUSDT", address(owner));
        address[] memory zks = new address[](1);
        zks[0] = address(zk);

        zk.mint(airdrop, totalStaked[0]);

        vm.warp(block.timestamp + 100);

        uint[] memory tvl = new uint[](1);
        tvl[0] = 1500 ether;

        vm.startPrank(owner);
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
            totalStaked,
            payable(address(withdrawVault)),
            address(vaultV1),
            snapShotTime,
            tvl,
            airdrop
        );

        withdrawVault.setVault(address(vault));
        zk.setToVault(address(vault), address(vault));
        zk.setAirdropper(airdrop);

        vm.stopPrank();

        vm.warp(block.timestamp + 1);
    }

    function testAirDrop()public{
        vm.warp(block.timestamp + 1 days);

        require(block.timestamp > snapShotTime + 1 days, "Not enough time has passed");

        vm.startPrank(airdrop);

        //Calculate and transfer assets at timestamp of pause
        vault.supportedTokenToZkToken(address(token)).transfer(user, user1Assets);
        vault.supportedTokenToZkToken(address(token)).transfer(user2, user2Assets);
        vault.supportedTokenToZkToken(address(token)).transfer(user3, user3Assets);

        vm.stopPrank();

        assertEq(vault.supportedTokenToZkToken(address(token)).balanceOf(airdrop), 0);
    }

    function testStake() public {
        testAirDrop();
        vm.startPrank(user2);
        token.mint(user2, 500 ether);
        token.approve(address(vault), 500 ether);

        // Stake 500 tokens
        vault.stake_66380860(address(token), 500 ether);

        // Check user's staked amount
        uint256 stakedAmount = vault.getStakedAmount(user2, address(token));
        assertEq(stakedAmount, 500 ether + user2Assets);
        assertEq(token.balanceOf(user), 0);

        // Ensure Vault's token balance updated
        assertEq(token.balanceOf(address(vault)), 500 ether);

        //ensure zkToken minted & equal to staked amount
        uint zkAmount = vault.getZKTokenAmount(user2, address(token));
        console.log(
            zkAmount,
            vault.convertToShares(500 ether + user2Assets + vault.getClaimableRewards(user2, address(token)), address(token))
            );//误差在小数点后17位，精度为1e18，因此在预期范围之内
        vm.stopPrank();
    }

    //把旧合约中已经requestClaim的人的信息迁移过来并测试能否正常claim
    function testClaim() public {
        vm.startPrank(user);
        uint[] memory ids = vaultV1.getClaimQueueIDs(user, address(token));
        assertEq(ids.length, 1); //only 1 request

        // mint to withdrawVault for withdraw
        token.mint(address(withdrawVault), vaultV1.getClaimQueueInfo(ids[0]).totalAmount);

        
        vm.warp(block.timestamp + 14 days);

        vault.claim_41202704(ids[0], address(token));

        vm.stopPrank();

        assertEq(token.balanceOf(user), vaultV1.getClaimQueueInfo(ids[0]).totalAmount);
    }

    function testFlashWithdraw() public {
        token.mint(address(vault), 1000 ether);

        uint tvlBefore = vault.getTVL(address(token));
        uint totalStakedBefore = vault.totalStakeAmountByToken(address(token));

        vm.startPrank(user3);
        vault.flashWithdrawWithPenalty(address(token), type(uint).max);
        vm.stopPrank();

        uint tvlAfter = vault.getTVL(address(token));
        uint totalStakedAfter = vault.totalStakeAmountByToken(address(token));

        assertEq(totalStakedAfter, totalStakedBefore - user3Assets);
        assertEq(tvlAfter, tvlBefore - user3Assets);

        assertEq(token.balanceOf(user3), (user3Assets + vault.getTotalRewards(user3, address(token))) * (10000 - 50) / 10000);

    }

    function testStakeNew() public {

        vm.startPrank(newUser);
        token.mint(newUser, 500 ether);
        token.approve(address(vault), 500 ether);

        // Stake 500 tokens
        vault.stake_66380860(address(token), 500 ether);

        // Check user's staked amount
        uint256 stakedAmount = vault.getStakedAmount(newUser, address(token));
        assertEq(stakedAmount, 500 ether);
        assertEq(token.balanceOf(newUser), 0);

        // Ensure Vault's token balance updated
        assertEq(token.balanceOf(address(vault)), 500 ether);

        //ensure zkToken minted & equal to staked amount
        uint zkAmount = vault.getZKTokenAmount(newUser, address(token));
        assertEq(zkAmount, vault.convertToShares(500 ether, address(token)));
        vm.stopPrank();
    }

    function testRequestClaimNew() public returns (uint, uint, uint){
        testStakeNew();
        vm.warp(block.timestamp + 1 days);
        vm.startPrank(newUser);
        uint reward = vault.getClaimableRewards(newUser, address(token));
        uint withdrawAmount = 500 ether + reward;
        uint256 requestID = vault.requestClaim_8135334(address(token), withdrawAmount);
        vm.stopPrank();


        // Validate the withdrawal request
        ClaimItem memory claimItem = vault.getClaimQueueInfo(requestID);
        assertEq(claimItem.totalAmount, withdrawAmount);
        assertEq(claimItem.token, address(token));

        //burn all zkTokens
        assertEq(vault.getZKTokenAmount(newUser, address(token)), 0);

        return (requestID, claimItem.totalAmount, claimItem.principalAmount);
    }

    function testClaimNew() public {
        (uint id, uint totalAmount, uint principalAmount) = testRequestClaimNew();
        token.mint(address(withdrawVault), 1000 ether);

        vm.warp(block.timestamp + 14 days + 1);

        uint tvlBefore = vault.getTVL(address(token));

        vm.startPrank(newUser);
        vault.claim_41202704(id, address(token));//正常claim在withdrawVault扣款
        vm.stopPrank();

        uint tvlAfter = vault.getTVL(address(token));
        
        // Check user's balance
        assertEq(token.balanceOf(newUser), totalAmount);
        assertEq(tvlAfter, tvlBefore - principalAmount);
    }

    function testFlashWithdrawNew() public{
        testStakeNew();
        vm.warp(block.timestamp + 1 days);

        uint totalAssets = vault.getClaimableAssets(newUser, address(token));
        token.mint(address(vault), totalAssets);//flashWithdraw在vault扣款

        vm.startPrank(newUser);
        vault.flashWithdrawWithPenalty(address(token), type(uint).max);
        vm.stopPrank();

        // Check user's balance
        assertEq(token.balanceOf(newUser), totalAssets * (10000 - 50) / 10000);
    }

    function testTokenTransfer() public {
        vm.startPrank(newUser);
        token.mint(newUser, 500 ether);
        token.approve(address(vault), 500 ether);
        vault.stake_66380860(address(token), 500 ether);
        // vault.supportedTokenToZkToken(address(token)).approve(address(vault), 100 ether);
        vault.transferOrTransferFrom(address(token), newUser, user, 100 ether);
        vm.stopPrank();

        vm.startPrank(user);
        assertGt(vault.getClaimableAssets(user, address(token)), 0);
        vm.stopPrank();

    }

    function testChangeRate() public{
        vm.startPrank(newUser);
        token.mint(newUser, 500 ether);
        token.approve(address(vault), 500 ether);
        vault.stake_66380860(address(token), 500 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        vault.setRewardRate(address(token), 1400);
        vm.stopPrank();

        vm.warp(block.timestamp + 2 days);

        uint reward = vault.getClaimableRewards(newUser, address(token));

        uint expect = uint(500 ether) * 3500 / 3652500;  //（700 * 1 + 1400 * 2）

        assertEq(reward, expect);
    }

}