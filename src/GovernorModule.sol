// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Safe} from "safe-contracts/Safe.sol";
import {Enum} from "safe-contracts/common/Enum.sol";

contract GovernorModule {
    Safe public safeProxy;

    constructor(address _safeProxy) {
        safeProxy = Safe(payable(address(_safeProxy)));
    }

    function replaceOwner(address prevOwner, address oldOwner, address newOwner) internal {
        bytes memory swapOwner = abi.encodeWithSignature(
            "swapOwner(address,address,address)",
            prevOwner,
            oldOwner,
            newOwner
        );
        safeProxy.execTransactionFromModule(
            address(safeProxy),
            0,
            swapOwner,
            Enum.Operation.Call
        );
    }

    function addOwnerWithThreshold(address newOwner, uint256 threshold) internal {
        bytes memory addOwner = abi.encodeWithSignature(
            "addOwnerWithThreshold(address,uint256)",
            newOwner,
            threshold
        );
        safeProxy.execTransactionFromModule(
            address(safeProxy),
            0,
            addOwner,
            Enum.Operation.Call
        );
    }

    function removeOwner(
        address prevOwner,
        address owner,
        uint256 threshold
    ) internal {
        bytes memory addOwner = abi.encodeWithSignature(
            "removeOwner(address,address,uint256)",
            prevOwner,
            owner,
            threshold
        );
        safeProxy.execTransactionFromModule(
            address(safeProxy),
            0,
            addOwner,
            Enum.Operation.Call
        );
    }
}
