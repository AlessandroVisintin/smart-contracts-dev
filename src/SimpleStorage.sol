// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleStorage {
    string public storedData;

    event DataChanged(string oldValue, string newValue, address indexed changer);

    constructor() {
        storedData = "Initial Value";
    }

    function set(string memory newValue) public {
        require(
            keccak256(abi.encodePacked(newValue)) != keccak256(abi.encodePacked("Trigger Error")),
            "Test Value to test error triggering and catching"
            );
        string memory oldValue = storedData;
        storedData = newValue;
        emit DataChanged(oldValue, newValue, msg.sender);
    }

    function get() public view returns (string memory) {
        return storedData;
    }
    
}