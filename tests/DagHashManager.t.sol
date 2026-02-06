// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {DagHashManager} from "../src/DagHashManager.sol";

contract DagHashManagerTest is Test {

    // Re-declare events for expectEmit matching
    event HashAdded(bytes32 indexed hashValue, address indexed owner);
    event HashDeprecated(bytes32 indexed hashValue, address indexed owner);
    event HashDeleted(bytes32 indexed hashValue, address indexed owner);
    event LinkAdded(bytes32 indexed fromHash, bytes32 indexed toHash);
    event LinkDeleted(bytes32 indexed fromHash, bytes32 indexed toHash);

    DagHashManager private dag;
    
    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");
    address private carol = makeAddr("carol");

    function setUp() public {
        dag = new DagHashManager();
    }

    function H(string memory s) internal pure returns (bytes32) {
        return keccak256(bytes(s));
    }

    function _contains(bytes32[] memory arr, bytes32 needle) internal pure returns (bool) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == needle) return true;
        }
        return false;
    }

    function test_AddHash_EmitsAndStoresOwnerAndIndex() public {
        bytes32 h1 = H("H1");
        vm.prank(alice); // set msg.sender for next call
        vm.expectEmit(true, true, false, false);
        emit HashAdded(h1, alice);
        dag.addHash(h1); // expect event and success

        (uint256 idx, address owner, DagHashManager.HashState st) = dag.readHash(h1);
        assertEq(idx, 0);
        assertEq(owner, alice);
        assertEq(uint256(st), uint256(DagHashManager.HashState.ACTIVE));
    }

    function test_AddHash_RevertOnZeroOrDuplicate() public {
        vm.expectRevert(bytes("Invalid hash")); // next external call must revert with this reason
        dag.addHash(bytes32(0)); // zero hash blocked

        bytes32 h1 = H("H1");
        vm.prank(alice);
        dag.addHash(h1); // first ok
        vm.expectRevert(bytes("Hash already exists"));
        vm.prank(alice);
        dag.addHash(h1); // duplicate blocked
    }

    function test_ReadHash_RevertWhenMissing() public {
        vm.expectRevert(bytes("Hash does not exist")); // modifier enforces existence
        dag.readHash(H("missing")); // must revert
    }

    // -----------------------
    // deprecateHash
    // -----------------------

    function test_Deprecate_OnlyOwnerAndIdempotence() public {
        bytes32 h1 = H("H1");
        vm.prank(alice);
        dag.addHash(h1); // owner set to alice

        vm.expectRevert(bytes("Caller is not the owner"));
        vm.prank(bob);
        dag.deprecateHash(h1); // non-owner blocked

        vm.prank(alice);
        vm.expectEmit(true, true, false, false);
        emit HashDeprecated(h1, alice);
        dag.deprecateHash(h1); // success

        (, , DagHashManager.HashState st) = dag.readHash(h1);
        assertEq(uint256(st), uint256(DagHashManager.HashState.DEPRECATED));

        vm.expectRevert(bytes("Hash is already deprecated"));
        vm.prank(alice);
        dag.deprecateHash(h1); // cannot deprecate twice
    }

    // -----------------------
    // deleteHash
    // -----------------------

    function test_DeleteHash_MustBeDeprecatedThenRemovesAndCompacts() public {
        bytes32 h1 = H("H1");
        bytes32 h2 = H("H2");
        bytes32 h3 = H("H3");

        vm.startPrank(alice); // persist caller for multiple calls
        dag.addHash(h1);
        dag.addHash(h2);
        dag.addHash(h3);
        vm.stopPrank();

        vm.expectRevert(bytes("Hash must be deprecated before deletion"));
        vm.prank(alice);
        dag.deleteHash(h2); // must first deprecate

        vm.prank(alice);
        dag.deprecateHash(h2); // prepare for deletion

        vm.prank(alice);
        vm.expectEmit(true, true, false, false);
        emit HashDeleted(h2, alice);
        dag.deleteHash(h2); // deletes and compacts hashList

        // h3 should have moved to index 1 due to swap-and-pop compaction
        (uint256 idx3,,) = dag.readHash(h3);
        assertEq(idx3, 1);

        // The deleted hash should no longer be readable
        vm.expectRevert(bytes("Hash does not exist"));
        dag.readHash(h2); // gone
    }

    // -----------------------
    // addOutgoingLink
    // -----------------------

    function test_AddOutgoingLink_HappyPathAndDupGuard() public {
        bytes32 a = H("A");
        bytes32 b = H("B");

        vm.startPrank(alice);
        dag.addHash(a);
        dag.addHash(b);
        vm.stopPrank();

        vm.prank(alice);
        vm.expectEmit(true, true, false, false);
        emit LinkAdded(a, b);
        dag.addOutgoingLink(a, b); // success

        bytes32[] memory outA = dag.readOutgoingLinks(a);
        assertEq(outA.length, 1);
        assertEq(outA[0], b);

        vm.expectRevert(bytes("Link already exists"));
        vm.prank(alice);
        dag.addOutgoingLink(a, b); // duplicate blocked
    }

    function test_AddOutgoingLink_Reverts_OnInvalidStatesAndSelfAndExistence() public {
        bytes32 a = H("A");
        bytes32 b = H("B");
        bytes32 c = H("C");

        vm.startPrank(alice);
        dag.addHash(a);
        dag.addHash(b);
        dag.addHash(c);
        vm.stopPrank();

        vm.expectRevert(bytes("Cannot link hash to itself"));
        vm.prank(alice);
        dag.addOutgoingLink(a, a); // self link blocked

        vm.prank(alice);
        dag.deprecateHash(b); // mark target inactive
        vm.expectRevert(bytes("Target hash is not active"));
        vm.prank(alice);
        dag.addOutgoingLink(a, b); // cannot link to deprecated

        vm.prank(alice);
        dag.deprecateHash(a); // mark source inactive
        vm.expectRevert(bytes("Source hash is not active"));
        vm.prank(alice);
        dag.addOutgoingLink(a, c); // cannot link from deprecated

        vm.expectRevert(bytes("Hash does not exist"));
        vm.prank(alice);
        dag.addOutgoingLink(H("missing"), c); // from missing

        vm.expectRevert(bytes("Hash does not exist"));
        vm.prank(alice);
        dag.addOutgoingLink(c, H("missing")); // to missing
    }

    function test_AddOutgoingLink_Reverts_OnCycle() public {
        bytes32 a = H("A");
        bytes32 b = H("B");
        bytes32 c = H("C");

        vm.startPrank(alice);
        dag.addHash(a);
        dag.addHash(b);
        dag.addHash(c);
        dag.addOutgoingLink(a, b);
        dag.addOutgoingLink(b, c);
        vm.stopPrank();

        vm.expectRevert(bytes("Link would create a cycle")); // C->A would close a cycle A->B->C->A
        vm.prank(alice);
        dag.addOutgoingLink(c, a); // blocked by cycle prevention
    }

    // -----------------------
    // readOutgoingLinks
    // -----------------------

    function test_ReadOutgoingLinks_Reverts_WhenMissing() public {
        vm.expectRevert(bytes("Hash does not exist"));
        dag.readOutgoingLinks(H("missing")); // guarded by modifier
    }

    // -----------------------
    // deleteOutgoingLink
    // -----------------------

    function test_DeleteOutgoingLink_OnlyOwnerAndEffect() public {
        bytes32 a = H("A");
        bytes32 b = H("B");

        vm.startPrank(alice);
        dag.addHash(a);
        dag.addHash(b);
        dag.addOutgoingLink(a, b);
        vm.stopPrank();

        vm.expectRevert(bytes("Caller is not the owner"));
        vm.prank(bob);
        dag.deleteOutgoingLink(a, b); // only owner of 'a' may delete

        vm.prank(alice);
        vm.expectEmit(true, true, false, false);
        emit LinkDeleted(a, b);
        dag.deleteOutgoingLink(a, b); // success

        bytes32[] memory outA = dag.readOutgoingLinks(a);
        assertEq(outA.length, 0);

        vm.expectRevert(bytes("Link does not exist"));
        vm.prank(alice);
        dag.deleteOutgoingLink(a, b); // cannot delete twice
    }

    // -----------------------
    // Link cleanup on deleteHash
    // -----------------------

    function test_DeleteHash_RemovesFromNeighborsOutgoing() public {
        bytes32 a = H("A");
        bytes32 b = H("B");
        bytes32 c = H("C");

        vm.startPrank(alice);
        dag.addHash(a);
        dag.addHash(b);
        dag.addHash(c);
        dag.addOutgoingLink(a, b); // a->b
        dag.addOutgoingLink(b, c); // b->c
        dag.deprecateHash(b);
        vm.stopPrank();

        // Deleting b should remove a->b and remove b from any neighbors' arrays
        vm.prank(alice);
        dag.deleteHash(b); // triggers link cleanup

        // a's out should no longer contain b
        bytes32[] memory outA = dag.readOutgoingLinks(a);
        assertEq(outA.length, 0);

        // c had only incoming from b; its own outgoing list remains empty
        bytes32[] memory outC = dag.readOutgoingLinks(c);
        assertEq(outC.length, 0);

        // Re-adding link to deleted b must fail due to non-existence
        vm.expectRevert(bytes("Hash does not exist"));
        vm.prank(alice);
        dag.addOutgoingLink(a, b); // target no longer exists
    }
}
