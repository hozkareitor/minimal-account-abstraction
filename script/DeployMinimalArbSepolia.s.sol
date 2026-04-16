// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {console2} from "forge-std/console2.sol";

/**
 * @title DeployMinimalArbSepolia
 * @author Hozkareitor
 * @notice Deploys the MinimalAccount to Arbitrum Sepolia using a burner account.
 * @dev Reads environment variables: PRIVATE_KEY_BURNER, ENTRY_POINT_ADDRESS.
 *      Transfers ownership of the account to the deployer address.
 */
contract DeployMinimalArbSepolia is Script {
    /**
     * @notice Executes the deployment of MinimalAccount.
     * @dev Uses vm.startBroadcast with the burner private key.
     *      Logs the deployed contract address.
     */
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY_BURNER");
        address entryPoint = vm.envAddress("ENTRY_POINT_ADDRESS");
        address owner = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);
        MinimalAccount minimalAccount = new MinimalAccount(entryPoint);
        minimalAccount.transferOwnership(owner);
        vm.stopBroadcast();

        console2.log("MinimalAccount deployed at:", address(minimalAccount));
    }
}