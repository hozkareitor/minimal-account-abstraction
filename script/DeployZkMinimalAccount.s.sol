// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ZkMinimalAccount} from "src/zksync/ZkMinimalAccount.sol";

/**
 * @title DeployZkMinimalAccount
 * @author Hozkareitor
 * @notice Deploys ZkMinimalAccount to zkSync Sepolia testnet
 * @dev Uses burner account from environment variable PRIVATE_KEY_BURNER
 */
contract DeployZkMinimalAccount is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY_BURNER");
        address owner = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);
        ZkMinimalAccount account = new ZkMinimalAccount();
        vm.stopBroadcast();

        console2.log("ZkMinimalAccount deployed at:", address(account));
        console2.log("Owner:", owner);
    }
}