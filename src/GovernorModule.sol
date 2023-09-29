// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Safe} from "safe-contracts/Safe.sol";
import {Enum} from "safe-contracts/common/Enum.sol";

contract GovernorModule {
    Safe public safeProxy;

    constructor(address _safeProxy) {
        safeProxy = Safe(payable(address(_safeProxy)));
    }

    /// @notice this is to call replaceOwner() on the safe
    /// @dev done with execTransactionFromModule() 
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

    /// @notice this is to call addOwnerWithThreshold() on the safe
    /// @dev done with execTransactionFromModule() 
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

    /// @notice this is to call removeOwner() on the safe
    /// @dev done with execTransactionFromModule() 
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

    /// @notice this is to remove one owner from the safe when a replacement election starts
    /// @dev removeOwner() needs a prevOwner param as well which is the owner that points to the owner to be removed in the linked list
    function removeSingleOwner(address owner) internal {

        /// @dev this is to get the previous owner param
        for (uint256 i = 0; i < safeProxy.getOwners().length; i++) {
            //todo: get prevOwner
            // if (safeProxy.getOwner(prevOwner) == owner) {
            //     break;
            // }
        }

        //todo: removeOwner and adjust threshold accordingly
        // removeOwner(address(0), owner, 1);
    }

    /// @notice this is to add one owner to the safe when a replacement election ends
    /// @dev threshold is adjusted according to the number of owners
    /// should always be majority
    /// exact thresholds are listed in README.md
    function addSingleOwner(address owner) internal {
        //todo: add owner and adjust threshold accordingly
        // addOwnerWithThreshold(owner, 1);
    }

    /// @notice this is to add in the whole council to the safe when a full election ends
    function putInFullElection(address[5] memory owners) internal {
        //todo: if current owners are less than 5, add in the rest
        //todo: replace all current owners
        // make threshold 3
    }
}
