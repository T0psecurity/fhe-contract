// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity >=0.8.13 <0.9.0;

import "fhevm/abstracts/EIP712WithModifier.sol";
import "fhevm/lib/TFHE.sol";

contract CardDealer is EIP712WithModifier {
    // used for output authorization
    bytes32 private DOMAIN_SEPARATOR;
    mapping(address => Card) public decryptedCards;
    mapping (address => euint8) internal encryptedCards;

    enum Suit { Hearts, Diamonds, Clubs, Spades }
    enum Value { Two, Three, Four, Five, Six, Seven, Eight, Nine, Ten, Jack, Queen, King, Ace }

    struct Card {
        Suit suit;
        Value value;
    }

    
    constructor() EIP712WithModifier("Authorization token", "1") {
    }

    function getCard() public {
        encryptedCards[msg.sender] = TFHE.randEuint8();
    }

    // EIP 712 signature is required to prove that the user is requesting to view his/her own card
    // card is decrypted then re-encrypted using a publicKey provided by the user client to make sure that RPC cannot peek. 
    // The user can decrypt their card with the respective privateKey (stored on client)
    function viewCard(bytes32 publicKey, bytes calldata signature) public view onlySignedPublicKey(publicKey, signature) returns (bytes memory) {
        return TFHE.reencrypt(encryptedCards[msg.sender], publicKey, 0);
    }

    function revealCard() public {
        // Require user to have a hidden card 
        TFHE.isInitialized(encryptedCards[msg.sender]);

        uint8 decryptedCard = TFHE.decrypt(encryptedCards[msg.sender]);
        // Use modulo to get a number between 0 and 51
        uint8 cardIndex = decryptedCard % 52;
        // Determine the suit and value of the card

        Suit cardSuit = Suit(cardIndex / 13);
        Value cardValue = Value(cardIndex % 13);
        decryptedCards[msg.sender] = Card(cardSuit, cardValue);
    }
}