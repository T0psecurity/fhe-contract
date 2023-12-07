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


contract MoneyMarket {
    uint32 ethereumDomain;
    address score;
    address iqsRouter;
    bytes32 messageId;
    mapping(uint256 => bool) whitelistedUser;

    modifier onlyCallback() {
        require(msg.sender == iqsRouter);
        _;
    }

	function initialize(uint32 _ethereumDomain, address _score, address _iqsRouter) public {
        ethereumDomain = _ethereumDomain;
        score = _score;
        iqsRouter = _iqsRouter;
    }

    function writeWhitelistedUser(address user, bool status) onlyCallback() external {
        whitelistedUser[uint256(uint160(user))] = status;
    }

    function whitelist(address user) public view returns (bool){
        return whitelistedUser[uint256(uint160(user))];
    }

    function verifyUser(address user) public payable returns (bytes32) {
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
