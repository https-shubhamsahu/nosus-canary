// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title NoSusCanary
/// @notice Public, append-only log for NO SUS Canary notes.
/// The chain never receives note text, keys, reader names, fingerprints or
/// codewords. It stores only:
///  * per note: one hash that commits to every copy, the copy count, expiry;
///  * per opened copy: a salted reader tag and the time it was opened.
/// Only allow-listed NO SUS relayers can write, so nobody can fill a note's
/// copies with junk. The owner (deployer) manages the relayer list.
contract NoSusCanary {
    struct Note {
        uint64 sealedAt;
        uint64 expiresAt;
        uint16 copyCount;
        uint16 openedCount;
        bytes32 copiesHash;
    }

    struct Copy {
        bytes32 readerTag;
        uint64 openedAt;
    }

    address public immutable owner;
    mapping(address => bool) public isRelayer;
    mapping(bytes32 => Note) private notes;
    mapping(bytes32 => mapping(uint16 => Copy)) private copies;

    event RelayerSet(address indexed relayer, bool allowed);
    event NoteSealed(bytes32 indexed noteId, uint16 copyCount, bytes32 copiesHash, uint64 expiresAt);
    event CopyOpened(bytes32 indexed noteId, uint16 indexed copyIndex, bytes32 readerTag, uint64 openedAt);

    error NotOwner();
    error NotRelayer();
    error NoteExists();
    error NoteMissing();
    error InvalidNote();
    error InvalidCopy();
    error CopyTaken();
    error NoteExpired();

    modifier onlyRelayer() {
        if (!isRelayer[msg.sender]) revert NotRelayer();
        _;
    }

    constructor() {
        owner = msg.sender;
        isRelayer[msg.sender] = true;
        emit RelayerSet(msg.sender, true);
    }

    function setRelayer(address relayer, bool allowed) external {
        if (msg.sender != owner) revert NotOwner();
        isRelayer[relayer] = allowed;
        emit RelayerSet(relayer, allowed);
    }

    /// Commits to every copy of a note before any reader can open one.
    function sealNote(bytes32 noteId, uint16 copyCount, bytes32 copiesHash, uint64 expiresAt)
        external
        onlyRelayer
    {
        if (notes[noteId].sealedAt != 0) revert NoteExists();
        if (
            noteId == bytes32(0) || copyCount == 0 || copiesHash == bytes32(0)
                || (expiresAt != 0 && expiresAt <= block.timestamp)
        ) revert InvalidNote();

        notes[noteId] = Note({
            sealedAt: uint64(block.timestamp),
            expiresAt: expiresAt,
            copyCount: copyCount,
            openedCount: 0,
            copiesHash: copiesHash
        });
        emit NoteSealed(noteId, copyCount, copiesHash, expiresAt);
    }

    /// Records, once, which (salted, anonymous) reader received a copy.
    function openCopy(bytes32 noteId, uint16 copyIndex, bytes32 readerTag) external onlyRelayer {
        Note storage note = notes[noteId];
        if (note.sealedAt == 0) revert NoteMissing();
        if (note.expiresAt != 0 && block.timestamp >= note.expiresAt) revert NoteExpired();
        if (copyIndex >= note.copyCount || readerTag == bytes32(0)) revert InvalidCopy();

        Copy storage entry = copies[noteId][copyIndex];
        if (entry.openedAt != 0) revert CopyTaken();
        entry.readerTag = readerTag;
        entry.openedAt = uint64(block.timestamp);
        note.openedCount += 1;
        emit CopyOpened(noteId, copyIndex, readerTag, uint64(block.timestamp));
    }

    function noteOf(bytes32 noteId) external view returns (Note memory) {
        Note memory note = notes[noteId];
        if (note.sealedAt == 0) revert NoteMissing();
        return note;
    }

    /// Returns zero values for a copy nobody has opened yet.
    function copyOf(bytes32 noteId, uint16 copyIndex) external view returns (Copy memory) {
        return copies[noteId][copyIndex];
    }
}
