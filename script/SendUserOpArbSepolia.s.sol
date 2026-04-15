// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SendUserOpArbSepolia is Script {
    using MessageHashUtils for bytes32;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY_BURNER");
        address entryPointAddr = vm.envAddress("ENTRY_POINT_ADDRESS");
        address minimalAccountAddr = vm.envAddress("MINIMAL_ACCOUNT_ADDRESS");
        address erc20MockAddr = vm.envAddress("ERC20_MOCK_ADDRESS");
        address deployer = vm.addr(deployerKey);

        // Parámetros de la operación
        address spender = 0x9EA9b0cc1919def1A3CfAEF4F7A66eE3c36F86fC; // dirección cualquiera
        uint256 amount = 1e18; // aprobar 1 token

        // 1. Calldata para el approve
        bytes memory functionData = abi.encodeWithSelector(IERC20.approve.selector, spender, amount);

        // 2. Calldata para execute() de MinimalAccount
        bytes memory executeCallData = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            erc20MockAddr,
            0, // value
            functionData
        );

        // 3. Obtener nonce actual de la MinimalAccount
        uint256 nonce = IEntryPoint(entryPointAddr).getNonce(minimalAccountAddr, 0);

        // 4. Construir UserOperation sin firmar
        PackedUserOperation memory userOp = _generateUnsignedUserOperation(executeCallData, minimalAccountAddr, nonce);

        // 5. Calcular hash y firmar con la clave del owner (el mismo burner)
        bytes32 userOpHash = IEntryPoint(entryPointAddr).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerKey, digest);
        userOp.signature = abi.encodePacked(r, s, v);

        // 6. Enviar al EntryPoint
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        vm.startBroadcast(deployerKey);
        IEntryPoint(entryPointAddr).handleOps(ops, payable(deployer));
        vm.stopBroadcast();

        console2.log("UserOperation submitted. Beneficiary:", deployer);
    }

    function _generateUnsignedUserOperation(
        bytes memory callData,
        address sender,
        uint256 nonce
    ) internal pure returns (PackedUserOperation memory) {
        uint128 verificationGasLimit = 1_000_000;
        uint128 callGasLimit = 1_000_000;
        uint128 maxPriorityFeePerGas = 1_000_000_000; // 1 gwei
        uint128 maxFeePerGas = 2_000_000_000; // 2 gwei

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