// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DagHashManager {

    enum HashState { ACTIVE, DEPRECATED }

    struct HashInfo {
        uint256 index;
        address owner;
        HashState state;
    }

    mapping(bytes32 => HashInfo) private hashMapping;
    bytes32[] private hashList;

    mapping(bytes32 => bytes32[]) private outgoingLinksList;
    mapping(bytes32 => bytes32[]) private incomingLinksList;

    event HashAdded(bytes32 indexed hashValue, address indexed owner);
    event HashDeprecated(bytes32 indexed hashValue, address indexed owner);
    event HashDeleted(bytes32 indexed hashValue, address indexed owner);

    event LinkAdded(bytes32 indexed fromHash, bytes32 indexed toHash);
    event LinkDeleted(bytes32 indexed fromHash, bytes32 indexed toHash);

    modifier hashExists(bytes32 _hash) {
        require(hashMapping[_hash].owner != address(0), "Hash does not exist");
        _;
    }
    modifier onlyHashOwner(bytes32 _hash) {
        require(hashMapping[_hash].owner == msg.sender, "Caller is not the owner");
        _;
    }

    function addHash(bytes32 _hash) external {
        require(_hash != bytes32(0), "Invalid hash");
        require(hashMapping[_hash].owner == address(0), "Hash already exists");
        
        hashMapping[_hash] = HashInfo({
            index: hashList.length,
            owner: msg.sender,
            state: HashState.ACTIVE
        });
        
        hashList.push(_hash);
        emit HashAdded(_hash, msg.sender);
    }

    function readHash(bytes32 _hash) external view
        hashExists(_hash)
        returns (uint256 index, address owner, HashState state)
    {
        HashInfo memory hashInfo = hashMapping[_hash];
        return (hashInfo.index, hashInfo.owner, hashInfo.state);
    }

    function deprecateHash(bytes32 _hash) external
        hashExists(_hash)
        onlyHashOwner(_hash)
    {
        require(hashMapping[_hash].state == HashState.ACTIVE, "Hash is already deprecated");

        hashMapping[_hash].state = HashState.DEPRECATED;
        emit HashDeprecated(_hash, msg.sender);
    }

    function deleteHash(bytes32 _hash) external
        hashExists(_hash)
        onlyHashOwner(_hash)
    {
        require(hashMapping[_hash].state == HashState.DEPRECATED, "Hash must be deprecated before deletion");

        bytes32[] memory outgoingLinks = outgoingLinksList[_hash];
        for (uint256 i = 0; i < outgoingLinks.length; i++) {
            _removeFromArray(incomingLinksList[outgoingLinks[i]], _hash);
            emit LinkDeleted(_hash, outgoingLinks[i]);
        }
        delete outgoingLinksList[_hash];

        bytes32[] memory incomingLinks = incomingLinksList[_hash];
        for (uint256 i = 0; i < incomingLinks.length; i++) {
            _removeFromArray(outgoingLinksList[incomingLinks[i]], _hash);
            emit LinkDeleted(incomingLinks[i], _hash);
        }
        delete incomingLinksList[_hash];

        uint256 index = hashMapping[_hash].index;
        uint256 lastIndex = hashList.length - 1;
        if (index != lastIndex) {
            bytes32 lastHash = hashList[lastIndex];
            hashList[index] = lastHash;
            hashMapping[lastHash].index = index;
        }
        hashList.pop();
        delete hashMapping[_hash];
        emit HashDeleted(_hash, msg.sender);
    }

    function addOutgoingLink(bytes32 _fromHash, bytes32 _toHash) external
        hashExists(_fromHash)
        hashExists(_toHash)
        onlyHashOwner(_fromHash)
    {
        require(_fromHash != _toHash, "Cannot link hash to itself");
        require(hashMapping[_fromHash].state == HashState.ACTIVE, "Source hash is not active");
        require(hashMapping[_toHash].state == HashState.ACTIVE, "Target hash is not active");
        require(!_linkExists(_fromHash, _toHash), "Link already exists");
        require(!_wouldCreateCycle(_fromHash, _toHash), "Link would create a cycle");

        outgoingLinksList[_fromHash].push(_toHash);
        incomingLinksList[_toHash].push(_fromHash);
        emit LinkAdded(_fromHash, _toHash);
    }

    function readOutgoingLinks(bytes32 _hash) external view
        hashExists(_hash)
        returns (bytes32[] memory)
    {
        return outgoingLinksList[_hash];
    }

    function deleteOutgoingLink(bytes32 _fromHash, bytes32 _toHash) external
        hashExists(_fromHash)
        onlyHashOwner(_fromHash)
    {        
        require(_linkExists(_fromHash, _toHash), "Link does not exist");
        _removeFromArray(outgoingLinksList[_fromHash], _toHash);
        _removeFromArray(incomingLinksList[_toHash], _fromHash);   
        emit LinkDeleted(_fromHash, _toHash);
    }

    function _linkExists(bytes32 _fromHash, bytes32 _toHash) internal view returns (bool) {
        bytes32[] memory outgoing = outgoingLinksList[_fromHash];
        for (uint256 i = 0; i < outgoing.length; i++) {
            if (outgoing[i] == _toHash) {
                return true;
            }
        }
        return false;
    }

    function _removeFromArray(bytes32[] storage _array, bytes32 _element) internal {
        for (uint256 i = 0; i < _array.length; i++) {
            if (_array[i] == _element) {
                _array[i] = _array[_array.length - 1];
                _array.pop();
                break;
            }
        }
    }

    function _wouldCreateCycle(bytes32 _fromHash, bytes32 _toHash) internal view returns (bool) {
        bytes32[] memory stack = new bytes32[](hashList.length);
        bool[] memory visited = new bool[](hashList.length);
        uint256 stackSize = 0;

        stack[stackSize++] = _toHash;
        while (stackSize > 0) {
            bytes32 current = stack[--stackSize];
            if (current == _fromHash) {
                return true;
            
            }    
            uint256 currentIndex = hashMapping[current].index;
            if (visited[currentIndex]) {
                continue;
            }
            visited[currentIndex] = true;
            
            bytes32[] memory outgoing = outgoingLinksList[current];
            for (uint256 i = 0; i < outgoing.length; i++) {
                bytes32 nextHash = outgoing[i];
                if (hashMapping[nextHash].state == HashState.ACTIVE) {
                    uint256 nextIndex = hashMapping[nextHash].index;
                    if (!visited[nextIndex] && stackSize < stack.length) {
                        stack[stackSize++] = nextHash;
                    }
                }
            }
        }
        
        return false;
    }

}