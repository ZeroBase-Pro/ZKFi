// // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {MockERC20} from "../test/MockERC20.sol";

// forge script script/Vault.s.sol:VaultDeployerScript --broadcast --etherscan-api-key %Sepolia_Etherscan_Key% --verify -vvvv --rpc-url "https://ethereum-sepolia-rpc.publicnode.com"
contract VaultDeployerScript is Script {

    // @dev TODO: Please replace `multipleSignaturesAddress` with your own
    address multipleSignaturesAddress = 0x8FF3a85fC13E9a33cf42d2AdA473Ce665A4d30cd;
    // @dev TODO: Please replace `botAddress` with the bot address
    address botAddress = 0x021ea0E89f2e853D045E466929410E5B25487dEc;
    // @dev TODO: Please replace `ceffu` with the actual ceffu address
    address ceffu = 0x00004d81A8403D09D14851b7EdEEcF89ECB38563;
    uint256 waitingTime = 14 days;

    function run() public {
        // Get the private key from the .env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // @dev We do not need to deploy the ERC20 token used for testing in the production environment. 
        //      Therefore, remove the following two lines of code during production deployment.
        MockERC20 token = new MockERC20();
        console.log("Mock ERC20 address:", address(token));

        // @dev TODO: Please set the corresponding configurations in the production environment.
        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = address(token);
        uint256[] memory rewardRate = new uint256[](1);
        rewardRate[0] = 700; // APR: 7%
        uint256[] memory minStakeAmount = new uint256[](1);
        minStakeAmount[0] = 0;
        uint256[] memory maxStakeAmount = new uint256[](1);
        maxStakeAmount[0] = type(uint256).max;

        Vault vault = new Vault(
            supportedTokens, 
            rewardRate,
            minStakeAmount, 
            maxStakeAmount, 
            multipleSignaturesAddress, // admin
            botAddress, // bot
            ceffu, 
            waitingTime
        );

        console.log("Vault address:", address(vault));
        
        vm.stopBroadcast();
    }
}