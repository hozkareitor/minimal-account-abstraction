// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";

/**
 * @title SendUserOpArbSepolia
 * @author Hozkareitor
 * @notice Builds, signs, and sends a UserOperation through the EntryPoint on Arbitrum Sepolia.
 * @dev The operation performs an ERC20 approve from the MinimalAccount to a fixed spender.
 *      Requires environment variables: PRIVATE_KEY_BURNER, ENTRY_POINT_ADDRESS, MINIMAL_ACCOUNT_ADDRESS, ERC20_MOCK_ADDRESS.
 */
contract SendUserOpArbSepolia is Script {
    using MessageHashUtils for bytes32;

    /**
     * @notice Main entry point: generates the UserOperation and sends it to the EntryPoint.
     * @dev Fetches nonce, builds calldata, signs, and calls handleOps.
     *      The beneficiary is set to the burner account.
     */
    function run() external {
        // Read environment variables
        uint256 deployerKey = vm.envUint("PRIVATE_KEY_BURNER");
        address entryPointAddr = vm.envAddress("ENTRY_POINT_ADDRESS");
        address minimalAccountAddr = vm.envAddress("MINIMAL_ACCOUNT_ADDRESS");
        address erc20MockAddr = vm.envAddress("ERC20_MOCK_ADDRESS");
        address deployer = vm.addr(deployerKey);

        // Approve parameters
        address spender = 0x9EA9b0cc1919def1A3CfAEF4F7A66eE3c36F86fC;
        uint256 amount = 1e18;

        // Encode the internal call: approve(spender, amount)
        bytes memory functionData = abi.encodeWithSelector(IERC20.approve.selector, spender, amount);

        // Encode the call to MinimalAccount.execute()
        bytes memory executeCallData = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            erc20MockAddr,
            0, // value
            functionData
        );

        // Get current nonce of the account
        uint256 nonce = IEntryPoint(entryPointAddr).getNonce(minimalAccountAddr, 0);

        // Build unsigned UserOperation
        PackedUserOperation memory userOp = _generateUnsignedUserOperation(executeCallData, minimalAccountAddr, nonce);

        // Compute hash and sign with burner key
        bytes32 userOpHash = IEntryPoint(entryPointAddr).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerKey, digest);
        userOp.signature = abi.encodePacked(r, s, v);

        // Pack and send
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        vm.startBroadcast(deployerKey);
        IEntryPoint(entryPointAddr).handleOps(ops, payable(deployer));
        vm.stopBroadcast();

        console2.log("UserOperation submitted. Beneficiary:", deployer);
    }

    /**
     * @notice Generates an unsigned PackedUserOperation (without signature).
     * @param callData The encoded call to MinimalAccount.execute().
     * @param sender The MinimalAccount address.
     * @param nonce Current nonce of the account.
     * @return userOp The PackedUserOperation struct ready to be signed.
     */
    function _generateUnsignedUserOperation(
        bytes memory callData,
        address sender,
        uint256 nonce
    ) internal pure returns (PackedUserOperation memory) {
        uint128 verificationGasLimit = 1_000_000;
        uint128 callGasLimit = 1_000_000;
        uint128 maxPriorityFeePerGas = 1_000_000_000; // 1 gwei
        uint128 maxFeePerGas = 2_000_000_000;         // 2 gwei

        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}