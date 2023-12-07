// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity >=0.8.13 <0.9.0;

import "fhevm/abstracts/EIP712WithModifier.sol";
import "fhevm/lib/TFHE.sol";

interface IInterchainAccountRouter {

    function callRemote(
        uint32 _destination,
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external returns (bytes32);

    function getRemoteInterchainAccount(uint32 _destination, address _owner)
        external
        view
        returns (address);

}

interface Card {
    function receiveCard(uint8 _card) external;
}

contract CardDealer is EIP712WithModifier {
    // used for output authorization
    bytes32 private DOMAIN_SEPARATOR;
    mapping (address => euint8) public encryptedCards;
    uint32 DestinationDomain;
    address card;
    address iacRouter;
    bytes32 messageId;
    address scroll_contract;

    constructor() EIP712WithModifier("Authorization token", "1") {
    }

    function initialize(uint32 _DestinationDomain, address _card, address _iacRouter, address _scroll_contract) public {
        DestinationDomain = _DestinationDomain;
        card = _card;
        iacRouter = _iacRouter;
        scroll_contract = _scroll_contract;
    }

    // A random encrypted uint8 is generated
    function getCard(address user) public {
        encryptedCards[user] = TFHE.randEuint8();
    }

    function viewCard(address user) external view returns (uint8) {
        return TFHE.decrypt(encryptedCards[user]);
    }

    function returnCard(address user) external view returns (uint8) {
        require(scroll_contract == msg.sender, "not right scroll contract");
        return TFHE.decrypt(encryptedCards[user]);
    }

    function sendCard(address user) public {
        Card _Card = Card(card);

        uint8 _card = TFHE.decrypt(encryptedCards[user]);

        messageId = IInterchainAccountRouter(iacRouter).callRemote(
            DestinationDomain,
            address(_Card),
            0,
            abi.encodeCall(_Card.receiveCard, (_card))
        );
    }

    function getICA(address _contract) public view returns(address) {
        return IInterchainAccountRouter(iacRouter).getRemoteInterchainAccount(DestinationDomain, _contract);
    }

    function ScrollContractView() public view returns(address) {
        return scroll_contract;
    }

    // EIP 712 signature is required to prove that the user is requesting to view his/her own card
    // card is decrypted then re-encrypted using a publicKey provided by the user client to make sure that RPC cannot peek. 
    // The user can decrypt their card with the respective privateKey (stored on client)
    function viewCard(bytes32 publicKey, bytes calldata signature) public view onlySignedPublicKey(publicKey, signature) returns (bytes memory) {
        return TFHE.reencrypt(encryptedCards[msg.sender], publicKey, 0);
    }
}