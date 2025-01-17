// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/Vault.sol";
import "../src/zkToken.sol";
import "../test/MockERC20.sol";
import "../src/WithdrawVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VaultV2 is Script {
    address owner = address(1);
    address ceffu = owner;
    address bot = owner;
    address airdrop = owner;
    address deployer = 0x2b2E23ceC9921288f63F60A839E2B28235bc22ad;
    IVault vaultV1 = IVault(0x7264Bd557ecdb3E6A12D78B570d85528Dbd1a05d);
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MockERC20 token = MockERC20(0x515CB39D176B36833eB7813996Fa8C53f4331d88);

        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = address(token);
        uint256[] memory rewardRate = new uint256[](1);
        rewardRate[0] = 700;
        uint256[] memory minStakeAmount = new uint256[](1);
        minStakeAmount[0] = 0;
        uint256[] memory maxStakeAmount = new uint256[](1);
        maxStakeAmount[0] = type(uint256).max;

        WithdrawVault withdrawVault = new WithdrawVault(supportedTokens, deployer, bot, ceffu);

        // vaultV1.pause();

        uint snapShotTime = block.timestamp;

        uint[] memory totalStaked = new uint[](1);
        totalStaked[0] = 1500 ether;


        uint[] memory tvl = new uint[](1);
        tvl[0] = 1500 ether;

        zkToken zk = new zkToken("zkUSDT", "zkUSDT", deployer);
        address[] memory zks = new address[](1);
        zks[0] = address(zk);
        zk.mint(airdrop, totalStaked[0]);

        IVault vault = new Vault(
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
        withdrawVault.changeAdmin(owner);

        zk.setToVault(address(vault), address(vault));
        zk.setAirdropper(airdrop);
        zk.setAdmin(owner);

        vm.stopBroadcast();

        console.log("vault address:", address(vault));
        console.log("withdrawVault address:", address(withdrawVault));
        console.log("vaultV1 address:", address(vaultV1));
        console.log("zk address:", address(zk));

    }
}
//forge script VaultV2 --rpc-url https://eth-sepolia.public.blastapi.io --broadcast --etherscan-api-key F41MZG297XBH3D4RHMN96Y6S15HYFDJQNC --verify