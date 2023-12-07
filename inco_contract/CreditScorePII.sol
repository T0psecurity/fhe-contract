// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity >=0.8.13 <0.9.0;

import "fhevm/abstracts/EIP712WithModifier.sol";
import "fhevm/lib/TFHE.sol";

contract CreditScorePII is EIP712WithModifier {
    // used for output authorization
    bytes32 private DOMAIN_SEPARATOR;
    address public trustedAgent;
    mapping(address => euint8) internal creditScores;
    
    constructor() EIP712WithModifier("Authorization token", "1") {
        trustedAgent = msg.sender;
    }

    modifier onlyAgent {
        require(msg.sender == trustedAgent);
        _;
    }

    function store(address user, bytes calldata encryptedCreditScore) external onlyAgent {
        creditScores[user] = TFHE.asEuint8(encryptedCreditScore);
    }

    function isUserScoreAbove700(address user) external view returns (bool) {
        ebool isAbove700Encrypted = TFHE.gt(creditScores[user], TFHE.asEuint8(700));
        return TFHE.decrypt(isAbove700Encrypted);
        // TODO: send the decrypted boolean back to basename contract on Base via general messaging protocol
    }

    // EIP 712 signature is required to prove that the user is requesting to view his/her own credit score
    // Credit score is decrypted then re-encrypted using a publicKey provided by the user client to make sure that RPC cannot peek. 
    // The user can decrypt their credit score with the respective privateKey (stored on client)
    function viewOwnScore(bytes32 publicKey, bytes calldata signature) public view onlySignedPublicKey(publicKey, signature) returns (bytes memory) {
        return TFHE.reencrypt(creditScores[msg.sender], publicKey, 0);
    }
}