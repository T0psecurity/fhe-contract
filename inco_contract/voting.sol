// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity >=0.8.13 <0.9.0;

import "fhevm/lib/TFHE.sol";
import "fhevm/abstracts/EIP712WithModifier.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Voting is EIP712WithModifier {

    // EIP-712 domain separator
    bytes32 private constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId)"
    );
    bytes32 public constant STRUCT_TYPEHASH = keccak256("Struct(uint256 proposalId,bytes encryptedCount,bytes encryptedChoice)");
    bytes32 public DOMAIN_SEPARATOR;

    address public MAILBOX_ADDRESS;

   // A mapping from address to an encrypted balance.
    struct EncryptedVote {
        euint8 encryptedVoteCount;
        euint8 encryptedChoice;
        bool initialized;
    }
    mapping(address => EncryptedVote) internal encryptedVotes;
    mapping(address => bool) internal hasVoted;
    euint8 public inFavorCountEncrypted;
    euint8 public againstCountEncrypted;
    address public owner;
    address public voter;
    uint8 public inFavorCount;
    uint8 public againstCount;

    constructor() EIP712WithModifier("Authorization token", "1") {
        inFavorCountEncrypted = TFHE.asEuint8(0);
        againstCountEncrypted = TFHE.asEuint8(0);
        inFavorCount = 0;
        againstCount = 0;
        owner = msg.sender;
        DOMAIN_SEPARATOR = keccak256(abi.encode(
        EIP712DOMAIN_TYPEHASH,
        keccak256("SNAPSHOT"),
        keccak256("1"),
        uint256(9000)
        ));
        MAILBOX_ADDRESS = 0xbbEfdB6a9d869a30428f0F4db72f650163cFA020;
    }

    modifier OnlyOwner {
        require(msg.sender == owner, "Only Owner");
        _;
    }

    // encryptedChoice can be 0 (against) or 1 (in favor)
    function _castVote(address voterAddress, uint256 proposalId, bytes calldata encryptedVoteCount, bytes calldata encryptedChoice) internal {
        // require(!encryptedVotes[voterAddress].initialized, "Already voted");
        // uint256 encryptedVoteCount = IStorageProof.getTokenAmount(voterAddress, "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984");
        // TFHE.req(TFHE.gt(TFHE.asEuint8(tokenAmount), encryptedVoteCount));
        encryptedVotes[voterAddress] = EncryptedVote(TFHE.asEuint8(encryptedVoteCount), TFHE.asEuint8(encryptedChoice), true);

        ebool choice = TFHE.eq(TFHE.asEuint8(1), TFHE.asEuint8(encryptedChoice));
        euint8 inFavorCountToCast = TFHE.cmux(choice, TFHE.asEuint8(encryptedVoteCount), TFHE.asEuint8(0));
        euint8 againstCountToCast = TFHE.cmux(choice, TFHE.asEuint8(0), TFHE.asEuint8(encryptedVoteCount));
        inFavorCountEncrypted = TFHE.add(inFavorCountEncrypted, inFavorCountToCast);
        againstCountEncrypted = TFHE.add(againstCountEncrypted, againstCountToCast);
    }

    function castVote(uint256 proposalId, bytes calldata encryptedVoteCount, bytes calldata encryptedChoice) public {
        _castVote(msg.sender, proposalId, encryptedVoteCount, encryptedChoice);
    }

    function castVoteRemote() public {
        require(msg.sender == MAILBOX_ADDRESS, "Only Mailbox");
        // receive message from Mailbox
        // message package includes: voterAddress, proposalID, encryptedVoteCount, encryptedChoice
        // _castVote(voterAddress, proposalId, encryptedVoteCount, encryptedChoice);
    }

    function castVoteEIP712(uint256 proposalId, bytes calldata encryptedVoteCount, bytes calldata encryptedChoice, bytes calldata signature) public {
        address voterAddress = verifyAndExtract(proposalId, encryptedVoteCount, encryptedChoice, signature);
        _castVote(voterAddress, proposalId, encryptedVoteCount, encryptedChoice);
    }

    // Function to verify the EIP-712 signature and extract fields
    function verifyAndExtract(uint256 proposalId, bytes calldata encryptedVoteCount, bytes calldata encryptedChoice, bytes memory signature) public returns (address) {
        // Prepare the EIP-712 message hash
        bytes32 messageHash = keccak256(abi.encodePacked(
        "\x19\x01",
        DOMAIN_SEPARATOR,
        keccak256(abi.encode(
            STRUCT_TYPEHASH,
            proposalId,
            keccak256(encryptedVoteCount),
            keccak256(encryptedChoice)
        ))
        ));

        address recoveredSigner = ECDSA.recover(messageHash, signature);
        require(recoveredSigner != address(0), "Invalid signature");
        voter = recoveredSigner;

        return recoveredSigner;
    }

    function revealResult() public OnlyOwner {
        inFavorCount = TFHE.decrypt(inFavorCountEncrypted);
        againstCount = TFHE.decrypt(againstCountEncrypted);
    }

    function sendVoteResultToChain() public {
        // TODO: Send result back to EVM chain through general messaging protocol
    }
    
    // EIP 712 signature is required to prove that the user is requesting to view his/her own credit score
    // Information is decrypted then re-encrypted using a publicKey provided by the user client to make sure that RPC cannot peek. 
    // The user can decrypt their credit score with the respective privateKey (stored on client)
    function viewOwnVoteCount(bytes32 publicKey, bytes calldata signature) public view onlySignedPublicKey(publicKey, signature) returns (bytes memory) {
        return TFHE.reencrypt(encryptedVotes[msg.sender].encryptedVoteCount, publicKey, 0);
    }

    function viewOwnVoteChoice(bytes32 publicKey, bytes calldata signature) public view onlySignedPublicKey(publicKey, signature) returns (bytes memory) {
        return TFHE.reencrypt(encryptedVotes[msg.sender].encryptedChoice, publicKey, 0);
    }
}