// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {HashManager} from "../src/HashManager.sol";

contract HashManagerTest is Test {
    HashManager hm;

    // This is the standard pattern when using vm.expectEmit in Foundry.
    event HashAdded(bytes32 indexed hashValue, address indexed owner);
    event HashUpdated(bytes32 indexed oldHashValue, bytes32 indexed newHashValue, address indexed owner);
    event HashDeprecated(bytes32 indexed hashValue, address indexed owner);

    function setUp() public {
        hm = new HashManager();
    }

    function testAdd_StoresOwnerAndIndex_EmitsEvent() public {
        bytes32 h = keccak256("alpha");

        // Validate event emission: both parameters are indexed, and there is no non-indexed data.
        vm.expectEmit(true, true, false, false);
        emit HashAdded(h, address(this));

        hm.add(h);

        (uint256 index, address owner) = hm.read(h);
        assertEq(owner, address(this), "owner mismatch");
        assertEq(index, 0, "index mismatch");
    }

    function testAdd_RevertsOnZeroHash() public {
        vm.expectRevert(bytes("Invalid hash"));
        hm.add(bytes32(0));
    }

    function testAdd_RevertsOnDuplicate() public {
        bytes32 h = keccak256("dup");
        hm.add(h);

        vm.expectRevert(bytes("Hash already exists"));
        hm.add(h);
    }

    function testRead_RevertsWhenMissing() public {
        vm.expectRevert(bytes("Hash does not exist"));
        hm.read(keccak256("missing"));
    }

    function testDeprecate_OnlyOwnerCanDeprecate() public {
        bytes32 h = keccak256("secure");
        address alice = address(0xA11CE);
        address bob = address(0xB0B);

        vm.prank(alice);
        hm.add(h);

        vm.prank(bob);
        vm.expectRevert(bytes("Caller is not the owner"));
        hm.deprecate(h);
    }

    function testDeprecate_RevertsWhenMissing() public {
        vm.expectRevert(bytes("Hash does not exist"));
        hm.deprecate(keccak256("ghost"));
    }

    function testDeprecate_EmitsEventAndMaintainsIndices() public {
        bytes32 h1 = keccak256("one");
        bytes32 h2 = keccak256("two");
        bytes32 h3 = keccak256("three");

        hm.add(h1);
        hm.add(h2);
        hm.add(h3);

        // Before deprecating, h2 has index 1.
        (uint256 idx2Before, ) = hm.read(h2);
        assertEq(idx2Before, 1, "precondition index for h2");

        // Expect event from the owner (this test contract is the msg.sender for add/deprecate here).
        vm.expectEmit(true, true, false, false);
        emit HashDeprecated(h2, address(this));
        hm.deprecate(h2);

        // h2 is removed; read should revert.
        vm.expectRevert(bytes("Hash does not exist"));
        hm.read(h2);

        // h3 should have been moved to index 1; h1 remains at index 0.
        (uint256 idx3, ) = hm.read(h3);
        assertEq(idx3, 1, "h3 should be at index 1 after swap-pop");
        (uint256 idx1, ) = hm.read(h1);
        assertEq(idx1, 0, "h1 should remain at index 0");
    }

    // Optional: demonstrate non-owner add then owner deprecate via prank in one flow.
    function testFlow_AddFromAlice_DeprecateFromAlice() public {
        address alice = address(0xA11CE);
        bytes32 h = keccak256("flow");

        vm.prank(alice);
        hm.add(h);

        // Confirm owner.
        (, address owner) = hm.read(h);
        assertEq(owner, alice, "owner should be alice");

        // Expect event from alice and deprecate.
        vm.prank(alice);
        vm.expectEmit(true, true, false, false);
        emit HashDeprecated(h, alice);
        hm.deprecate(h);

        vm.expectRevert(bytes("Hash does not exist"));
        hm.read(h);
    }
}
