// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity >=0.8.13 <0.9.0;
import "fhevm/lib/TFHE.sol";
import "fhevm/abstracts/EIP712WithModifier.sol";

contract TOTP is EIP712WithModifier {
    // 4 digits
    euint16 public secretKey;
    address public owner;

    constructor(bytes memory _secretKey) EIP712WithModifier("Authorization token", "1") {
        secretKey = TFHE.asEuint16(_secretKey);
        owner = msg.sender;
    }

    modifier OnlyOwner {
        require(msg.sender == owner, "Only owner");
        _;
    }

    function changeSecretKey(bytes calldata newSecretKey) OnlyOwner public {
        secretKey = TFHE.asEuint16(newSecretKey);
    }

    // Compare that the TOTP matches the secretKey x timestamp (last 5 digits)
    function validateTOTP(uint256 _encryptedTOTP, uint256 timestamp) public view returns (bool) {
        // TOTP has a validity of 200 seconds
        require(block.timestamp <= timestamp + 200, "Timestamp not within range");
        uint256 shorterTimestamp = timestamp % 100000;
        euint32 encryptedTOTP = TFHE.asEuint32(_encryptedTOTP);
        ebool isValid = TFHE.eq(encryptedTOTP, TFHE.mul(TFHE.asEuint32(shorterTimestamp), secretKey));
        return TFHE.decrypt(isValid);
    }

    // EIP 712 signature is required to prove that the user is requesting to view the secret key
    // Secret key is decrypted then re-encrypted using a publicKey provided by the user client to make sure that RPC cannot peek. 
    // The user can decrypt their secret key with the respective privateKey (stored on client)
    function viewSecretKey(bytes32 publicKey, bytes calldata signature) public view onlySignedPublicKey(publicKey, signature) returns (bytes memory) {
        return TFHE.reencrypt(secretKey, publicKey, 0);
    }
}