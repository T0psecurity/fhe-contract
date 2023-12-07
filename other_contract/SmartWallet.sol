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

interface TOTP {
    function validateTOTP(uint256 _encryptedTOTP, uint256 timestamp) external view returns (bool, uint256);
}

contract SmartWallet {

    uint32 ethereumDomain;
    uint256 lastTOTP = 1;
    address totp;
    address iqsRouter;
    bytes32 messageId;

    function initialize(uint32 _ethereumDomain, address _totp, address _iqsRouter) public {
        ethereumDomain = _ethereumDomain;
        totp = _totp;
        iqsRouter = _iqsRouter;
    }

    function execute() public view returns (bool) {
        require(lastTOTP + 3600 < block.timestamp, "Need OTP");
        return true;
    }

    function calltimestamp(uint256 secretKey) public {
        TOTP _validateTOTP = TOTP(totp);

        // uint32 _label = 32;
        bytes memory _callback = abi.encodePacked(this.receiveOTP.selector);
        // bytes memory _callback = abi.encodePacked(msg.sender);
        uint256 blocktimestamp = block.timestamp;
        uint256 _encryptedTOTP = blocktimestamp % 100000;
        _encryptedTOTP = _encryptedTOTP * secretKey;
        messageId = IInterchainQueryRouter(iqsRouter).query(
            ethereumDomain,
            address(_validateTOTP),
            abi.encodeCall(_validateTOTP.validateTOTP, (_encryptedTOTP, blocktimestamp)),
            _callback
        );
    }

    function receiveOTP(bool flag) public{
        require(msg.sender == iqsRouter, "only iqsRouter");
        // (bool, timestamp) = message..
        if (flag) {
            lastTOTP = block.timestamp;
        } else {
            lastTOTP = lastTOTP;
        }
    }

    function lastTOTPView() public view returns(uint256, uint256) {
        return (lastTOTP, block.timestamp);
    }
}