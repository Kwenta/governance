// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {GovernorModule} from "../src/GovernorModule.sol";
import {Enum} from "safe-contracts/common/Enum.sol";
import {Safe} from "safe-contracts/Safe.sol";
import {SafeProxy} from "safe-contracts/proxies/SafeProxy.sol";
import {SafeProxyFactory} from "safe-contracts/proxies/SafeProxyFactory.sol";
import {AutomatedVotingInternals} from "./AutomatedVotingInternals.sol";
import {DefaultStakingV2Setup} from "../lib/token/test/foundry/utils/setup/DefaultStakingV2Setup.t.sol";

contract GovernorModuleTest is DefaultStakingV2Setup {
    AutomatedVotingInternals automatedVotingInternals;
    address constant SAFE = 0x41675C099F32341bf84BFc5382aF534df5C7461a;
    address constant SAFEPROXYFACTORY =
        0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67;
    Safe safe;
    Safe safeProxy;
    SafeProxyFactory safeProxyFactory;
    SafeProxy proxy;
    uint256 owner1PrivateKey = 123;
    address Owner1 = vm.addr(owner1PrivateKey);
    uint256 owner2PrivateKey = 456;
    address Owner2 = vm.addr(owner2PrivateKey);

    // BLOCK_NUMBER corresponds to Jul-25-2023 08:49:11 PM +UTC - Ethereum Mainnet
    uint256 constant BLOCK_NUMBER = 17_772_593;

    function setUp() public override {
        super.setUp();

        vm.rollFork(BLOCK_NUMBER);
        safe = Safe(payable(SAFE));
        safeProxyFactory = SafeProxyFactory(SAFEPROXYFACTORY);

        // create proxy for safe and call the setup function during proxy creation
        proxy = safeProxyFactory.createProxyWithNonce(
            address(safe),
            bytes(""),
            0
        );
        safeProxy = Safe(payable(address(proxy)));

        address[] memory owners = new address[](1);
        owners[0] = Owner1;
        uint256 threshold = 1;
        address to = address(0);
        bytes memory data = bytes("");
        address fallbackHandler = address(0);
        address paymentToken = address(0);
        uint256 payment = 0;
        address payable paymentReceiver = payable(address(0));

        safeProxy.setup(
            owners,
            threshold,
            to,
            data,
            fallbackHandler,
            paymentToken,
            payment,
            paymentReceiver
        );

        automatedVotingInternals = new AutomatedVotingInternals(
            address(stakingRewardsV2),
            block.timestamp,
            address(safeProxy)
        );

        /// @dev add AutomatedVoting as a module
        bytes memory enableModuleData = abi.encodeWithSignature(
            "enableModule(address)",
            address(automatedVotingInternals)
        );

        bytes32 messageHash = safeProxy.getTransactionHash(
            address(safeProxy),
            0,
            enableModuleData,
            Enum.Operation.Call,
            50000,
            0,
            0,
            address(0),
            payable(address(0)),
            0
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            owner1PrivateKey,
            messageHash
        );

        // Pack the ECDSA signature
        bytes memory packedSignature = abi.encodePacked(r, s, v);

        safeProxy.execTransaction(
            address(safeProxy),
            0,
            enableModuleData,
            Enum.Operation.Call,
            50000,
            0,
            0,
            address(0),
            payable(address(0)),
            packedSignature
        );
    }

    /// @notice make sure the AutomatedVoting module is enabled
    function testGovernorModuleEnabled() public {
        (address[] memory array, address next) = safeProxy.getModulesPaginated(
            address(0x1),
            10
        );
        assertEq(address(automatedVotingInternals), array[0]);
        assertTrue(safeProxy.isModuleEnabled(address(automatedVotingInternals)));
    }

    function testReplaceOwner() public {
        assertFalse(safeProxy.isOwner(address(this)));
        // replace owner
        automatedVotingInternals.replaceOwnerInternal(Owner1, address(this));
        // check if owner was replaced
        assertEq(address(this), safeProxy.getOwners()[0]);
        assertTrue(safeProxy.isOwner(address(this)));
        assertFalse(safeProxy.isOwner(Owner1));
    }

    function testAddOwnerWithThreshold() public {
        // add owner
        vm.prank(Owner1);
        automatedVotingInternals.addOwnerWithThresholdInternal(Owner2);
        // check if owner was added
        assertTrue(safeProxy.isOwner(Owner2));
    }

    /// @notice test that only safe owners can call the module
    function testAddThenRemoveAnOwner() public {
        // add Owner2
        vm.prank(Owner1);
        automatedVotingInternals.addOwnerWithThresholdInternal(Owner2);
        // check if Owner2 was added
        assertTrue(safeProxy.isOwner(Owner2));

        // remove Owner1
        vm.prank(Owner2);
        automatedVotingInternals.removeOwnerInternal(Owner2, Owner1, 1);
        // check if Owner1 was removed
        assertFalse(safeProxy.isOwner(Owner1));

        // make sure Owner2 is still an owner
        assertTrue(safeProxy.isOwner(Owner2));
    }

    /// @notice test that a newly added owner can execute a transaction
    function testReplacedOwnerCanExecTransaction() public {
        automatedVotingInternals.replaceOwnerInternal(Owner1, Owner2);
        execTransactionTransfer(Owner2, owner2PrivateKey);
    }

    /// @notice test that a removed owner CANT execute a transaction
    function testFailRemovedOwnerCantExecTransaction() public {
        automatedVotingInternals.replaceOwnerInternal(Owner1, Owner2);
        execTransactionTransfer(Owner1, owner1PrivateKey);
    }

    //util functions

    function execTransactionTransfer(
        address publicAddress,
        uint256 privateKey
    ) public {
        bytes memory transferData = abi.encodeWithSignature(
            "transfer(address,uint256)",
            address(Owner1),
            1
        );

        bytes32 transferHash = safeProxy.getTransactionHash(
            address(safeProxy),
            0,
            transferData,
            Enum.Operation.Call,
            50000,
            0,
            0,
            address(0),
            payable(address(0)),
            1
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, transferHash);

        address signer = ecrecover(transferHash, v, r, s);
        assertEq(publicAddress, signer);

        // Pack the ECDSA signature
        bytes memory packedSignature = abi.encodePacked(r, s, v);

        safeProxy.execTransaction(
            address(safeProxy),
            0,
            transferData,
            Enum.Operation.Call,
            50000,
            0,
            0,
            address(0),
            payable(address(0)),
            packedSignature
        );
    }
}
