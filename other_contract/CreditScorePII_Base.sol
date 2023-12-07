// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.13 <0.9.0;

struct Call {
    address to;
    bytes data;
}

interface CreditScorePII {
    function isUserScoreAbove700(address user) external view returns (bool);
}

interface IInterchainQueryRouter {

    function query(
        uint32 _destination,
        address _to,
        bytes memory _data,
        bytes memory _callback
    ) external returns (bytes32);

}

interface IInterchainGasPaymaster {

    event GasPayment(
        bytes32 indexed messageId,
        uint256 gasAmount,
        uint256 payment
    );

    function payForGas(
        bytes32 _messageId,
        uint32 _destinationDomain,
        uint256 _gasAmount,
        address _refundAddress
    ) external payable;

    function quoteGasPayment(uint32 _destinationDomain, uint256 _gasAmount)
        external
        view
        returns (uint256);
}

abstract contract AbstractContract {
    function verifyUser(address user) public payable virtual returns (bytes32);
}

contract MoneyMarket is AbstractContract {
    uint32 constant ethereumDomain = 9000;
    address constant score = 0xAa3a222f42D034BC45a732827888e2C152591592;
    address constant iqsRouter = 0x3c91A95Cb8D32933Bffc273Aaa6Fb57473438D6f;
    bytes32 messageId;
    mapping(uint256 => bool) whitelistedUser;

    modifier onlyCallback() {
        require(msg.sender == iqsRouter);
        _;
    }

    function writeWhitelistedUser(address user, bool status) onlyCallback() external {
        whitelistedUser[uint256(uint160(user))] = status;
    }

    function whitelist(address user) public view returns (bool){
        return whitelistedUser[uint256(uint160(user))];
    }

    function verifyUser(address user) public payable override returns (bytes32) {
        CreditScorePII _score = CreditScorePII(score);

        bytes memory _callback = abi.encodePacked(this.writeWhitelistedUser.selector, (uint256(uint160(user))));

        messageId = IInterchainQueryRouter(iqsRouter).query(
            ethereumDomain,
            address(score),
            abi.encodeCall(_score.isUserScoreAbove700, (user)),
            _callback
        );

        return messageId;
    }

    function viewmesageId() public view returns (bytes32) {
        return messageId;
    }
}
