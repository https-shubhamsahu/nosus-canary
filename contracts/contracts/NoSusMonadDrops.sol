// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title NoSusMonadDrops
/// @notice A Monad-testnet receipt for an encrypted drop. The contract never receives content,
/// encryption keys, salts, filenames, or private storage locations.
contract NoSusMonadDrops {
    struct Drop {
        address sender;
        address recipient;
        address opener;
        bytes32 ciphertextDigest;
        uint64 sealedAt;
        uint64 openedAt;
        uint64 expiresAt;
    }

    mapping(bytes32 id => Drop) private drops;

    error DropAlreadyExists();
    error DropDoesNotExist();
    error DropAlreadyOpened();
    error DropExpired();
    error InvalidCiphertextDigest();
    error InvalidExpiry();
    error RecipientOnly();

    event Sealed(
        bytes32 indexed id,
        address indexed sender,
        address indexed recipient,
        bytes32 ciphertextDigest,
        uint64 expiresAt
    );
    event OpenAcknowledged(
        bytes32 indexed id,
        address indexed opener,
        uint64 openedAt
    );

    function seal(
        bytes32 id,
        bytes32 ciphertextDigest,
        address recipient,
        uint64 expiresAt
    ) external {
        if (drops[id].sender != address(0)) revert DropAlreadyExists();
        if (ciphertextDigest == bytes32(0)) revert InvalidCiphertextDigest();
        if (expiresAt != 0 && expiresAt <= block.timestamp) revert InvalidExpiry();

        uint64 sealedAt = uint64(block.timestamp);
        drops[id] = Drop({
            sender: msg.sender,
            recipient: recipient,
            opener: address(0),
            ciphertextDigest: ciphertextDigest,
            sealedAt: sealedAt,
            openedAt: 0,
            expiresAt: expiresAt
        });

        emit Sealed(id, msg.sender, recipient, ciphertextDigest, expiresAt);
    }

    function acknowledgeOpen(bytes32 id) external {
        Drop storage drop = drops[id];
        if (drop.sender == address(0)) revert DropDoesNotExist();
        if (drop.opener != address(0)) revert DropAlreadyOpened();
        if (drop.expiresAt != 0 && block.timestamp > drop.expiresAt) revert DropExpired();
        if (drop.recipient != address(0) && drop.recipient != msg.sender) {
            revert RecipientOnly();
        }

        uint64 openedAt = uint64(block.timestamp);
        drop.opener = msg.sender;
        drop.openedAt = openedAt;

        emit OpenAcknowledged(id, msg.sender, openedAt);
    }

    function canDecrypt(bytes32 id, address account) external view returns (bool) {
        Drop memory drop = drops[id];
        if (drop.sender == address(0) || drop.opener != account) return false;
        if (drop.expiresAt != 0 && block.timestamp > drop.expiresAt) return false;
        return true;
    }

    function receiptOf(bytes32 id) external view returns (Drop memory) {
        Drop memory drop = drops[id];
        if (drop.sender == address(0)) revert DropDoesNotExist();
        return drop;
    }
}
