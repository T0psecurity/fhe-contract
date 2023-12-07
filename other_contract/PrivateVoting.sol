// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.13 <0.9.0;

interface IInterchainQueryRouter {

    function query(
        uint32 _destination,
        address _to,
        bytes memory _data,
        bytes memory _callback
    ) external returns (bytes32);

}

interface Voting {
    function castVoteRemote(uint256 proposalId, bytes calldata encryptedVoteCount, bytes calldata encryptedChoice, bytes calldata signature) external;
}

contract PrivateVoting {
    uint32 constant ethereumDomain = 9000;
    address constant voting = 0x09bce27F2394Ae91049636566acFE7DceFb40CE3;
    address constant iqsRouter = 0x3c91A95Cb8D32933Bffc273Aaa6Fb57473438D6f;
    bytes32 messageId;
    uint8 inFavorCount;
    uint8 againstCount;

    modifier onlyCallback() {
        require(msg.sender == iqsRouter);
        _;
    }

    function receiveVotingState(address user, uint8 _inFavorCount, uint8 _againstCount) onlyCallback() external {
        inFavorCount = _inFavorCount;
        againstCount = _againstCount;
    }

    function viewVotingState() view public returns (uint8, uint8){
        return (inFavorCount, againstCount);
    }

    function calltimestamp(uint256 proposalId, bytes calldata encryptedVoteCount, bytes calldata encyptedChoice, bytes calldata signature) public {
        Voting _voting = Voting(voting);

        // uint32 _label = 32;
        bytes memory _callback = abi.encodePacked(this.receiveVotingState.selector, msg.sender);
        // bytes memory _callback = abi.encodePacked(msg.sender);

        messageId = IInterchainQueryRouter(iqsRouter).query(
            ethereumDomain,
            address(_voting),
            abi.encodeCall(_voting.castVoteRemote, (_encryptedTOTP, block.timestamp)),
            _callback
        );
    }

}