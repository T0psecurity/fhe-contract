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

interface IInterchainExecuteRouter {

    function callRemote(
        uint32 _destination,
        address _to,
        uint256 _value,
        bytes calldata _data,
        bytes calldata _callback
    ) external returns (bytes32);

    function getRemoteInterchainAccount(uint32 _destination, address _owner)
        external
        view
        returns (address);

}

interface HiddenCard {
    function returnCard(address user) external returns (uint8);
}

contract Card {

    uint32 DestinationDomain;
    address hiddencard;
    address iexRouter;
    bytes32 messageId;
    uint8 card;
    address inco_contract;

    function initialize(uint32 _DestinationDomain, address _hiddencard, address _iexRouter, address _inco_contract) public {
        DestinationDomain = _DestinationDomain;
        hiddencard = _hiddencard;
        iexRouter = _iexRouter;
        inco_contract = _inco_contract;
    }

    function CardGet(address user) public {
        HiddenCard _Hiddencard = HiddenCard(hiddencard);

        // uint32 _label = 32;
        bytes memory _callback = abi.encodePacked(this.cardReceive.selector);

        messageId = IInterchainExecuteRouter(iexRouter).callRemote(
            DestinationDomain,
            address(_Hiddencard),
            0,
            abi.encodeCall(_Hiddencard.returnCard, (user)),
            _callback
        );
    }

    function getICA(address _contract) public view returns(address) {
        return IInterchainExecuteRouter(iexRouter).getRemoteInterchainAccount(DestinationDomain, _contract);
    }

    function cardReceive(uint8 _card) external {
        card = _card;
    }

    function receiveCard(uint8 _card) external {
        require(inco_contract == msg.sender, "not right inco contract");
        card = _card;
    }

    function CardView() public view returns(uint8) {
        return card;
    }

    function IncoContractView() public view returns(address) {
        return inco_contract;
    }

}