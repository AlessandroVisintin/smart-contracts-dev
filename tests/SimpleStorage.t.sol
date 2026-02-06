// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleStorage.sol";

contract SimpleStorageTest is Test {
    SimpleStorage internal s;

    event DataChanged(string oldValue, string newValue, address indexed changer);

    function setUp() public {
        s = new SimpleStorage();
    }

    function testInitialValue() public view {
        assertEq(s.get(), "Initial Value");
    }

    function testSetUpdatesAndEmits() public {
        vm.expectEmit(true, false, false, true, address(s));
        emit DataChanged("Initial Value", "Hello", address(this));
        s.set("Hello");
        assertEq(s.get(), "Hello");
    }

    function testRevertsOnTriggerError() public {
        vm.expectRevert(bytes("Test Value to test error triggering and catching"));
        s.set("Trigger Error");
    }

    function testSetFromDifferentSenderEmitsChanger() public {
        address alice = makeAddr("alice");
        vm.expectEmit(true, false, false, true, address(s));
        emit DataChanged("Initial Value", "Alice set", alice);
        vm.prank(alice);
        s.set("Alice set");
        assertEq(s.get(), "Alice set");
    }

    function testFuzz_Set_AnyStringExceptSentinel(string memory newValue) public {
        vm.assume(keccak256(bytes(newValue)) != keccak256(bytes("Trigger Error")));
        s.set(newValue);
        assertEq(s.get(), newValue);
    }
}
