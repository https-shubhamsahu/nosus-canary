import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { network } from "hardhat";

const noteId = `0x${"11".repeat(32)}` as const;
const otherNoteId = `0x${"22".repeat(32)}` as const;
const copiesHash = "0x1d9f0d2a2e10e3580481170dc38f3dce11399ee6d26c6621dbb3dc401b3c7adf";
const readerTag = "0xaabbccddeeff00112233445566778899aabbccddeeff00112233445566778899";
const zero32 = `0x${"0".repeat(64)}` as const;

async function expectCustomError(action: Promise<unknown>, name: string) {
  await assert.rejects(action, (error: unknown) =>
    error instanceof Error && error.message.includes(name),
  );
}

describe("NoSusCanary", () => {
  async function deploy() {
    const { viem } = await network.getOrCreate();
    const [owner, relayer, stranger] = await viem.getWalletClients();
    const canary = await viem.deployContract("NoSusCanary");
    const publicClient = await viem.getPublicClient();
    const testClient = await viem.getTestClient();
    return { viem, owner, relayer, stranger, canary, publicClient, testClient };
  }

  it("makes the deployer the owner and first relayer", async () => {
    const { canary, owner } = await deploy();
    assert.equal((await canary.read.owner()).toLowerCase(), owner.account.address.toLowerCase());
    assert.equal(await canary.read.isRelayer([owner.account.address]), true);
  });

  it("lets only the owner manage relayers", async () => {
    const { canary, relayer, stranger } = await deploy();
    await expectCustomError(
      canary.write.setRelayer([stranger.account.address, true], { account: stranger.account }),
      "NotOwner",
    );
    await canary.write.setRelayer([relayer.account.address, true]);
    assert.equal(await canary.read.isRelayer([relayer.account.address]), true);
    await canary.write.setRelayer([relayer.account.address, false]);
    assert.equal(await canary.read.isRelayer([relayer.account.address]), false);
  });

  it("seals a note once and rejects bad input and strangers", async () => {
    const { canary, stranger, publicClient } = await deploy();
    const now = BigInt((await publicClient.getBlock()).timestamp);

    await expectCustomError(
      canary.write.sealNote([noteId, 20, copiesHash, 0n], { account: stranger.account }),
      "NotRelayer",
    );
    const hash = await canary.write.sealNote([noteId, 20, copiesHash, now + 3600n]);
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    console.log(`      sealNote gasUsed=${receipt.gasUsed}`);

    const note = await canary.read.noteOf([noteId]);
    assert.equal(note.copyCount, 20);
    assert.equal(note.openedCount, 0);
    assert.equal(note.copiesHash, copiesHash);
    assert.equal(note.expiresAt, now + 3600n);

    await expectCustomError(canary.write.sealNote([noteId, 20, copiesHash, 0n]), "NoteExists");
    await expectCustomError(canary.write.sealNote([zero32, 20, copiesHash, 0n]), "InvalidNote");
    await expectCustomError(canary.write.sealNote([otherNoteId, 0, copiesHash, 0n]), "InvalidNote");
    await expectCustomError(canary.write.sealNote([otherNoteId, 20, zero32, 0n]), "InvalidNote");
    await expectCustomError(canary.write.sealNote([otherNoteId, 20, copiesHash, now - 1n]), "InvalidNote");
    await expectCustomError(canary.read.noteOf([otherNoteId]), "NoteMissing");

    const events = await canary.getEvents.NoteSealed({ noteId }, { fromBlock: 0n });
    assert.equal(events.length, 1);
  });

  it("opens each copy exactly once and counts opens", async () => {
    const { canary, stranger, publicClient } = await deploy();
    await canary.write.sealNote([noteId, 3, copiesHash, 0n]);

    await expectCustomError(
      canary.write.openCopy([noteId, 0, readerTag], { account: stranger.account }),
      "NotRelayer",
    );
    const hash = await canary.write.openCopy([noteId, 0, readerTag]);
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    console.log(`      openCopy gasUsed=${receipt.gasUsed}`);

    const copy = await canary.read.copyOf([noteId, 0]);
    assert.equal(copy.readerTag, readerTag);
    assert.ok(copy.openedAt > 0n);
    assert.equal((await canary.read.noteOf([noteId])).openedCount, 1);

    await expectCustomError(canary.write.openCopy([noteId, 0, readerTag]), "CopyTaken");
    await expectCustomError(canary.write.openCopy([noteId, 3, readerTag]), "InvalidCopy");
    await expectCustomError(canary.write.openCopy([noteId, 1, zero32]), "InvalidCopy");
    await expectCustomError(canary.write.openCopy([otherNoteId, 0, readerTag]), "NoteMissing");

    const unopened = await canary.read.copyOf([noteId, 2]);
    assert.equal(unopened.openedAt, 0n);
    const events = await canary.getEvents.CopyOpened({ noteId }, { fromBlock: 0n });
    assert.equal(events.length, 1);
    assert.equal(events[0].args.copyIndex, 0);
  });

  it("refuses opens after expiry", async () => {
    const { canary, publicClient, testClient } = await deploy();
    const now = BigInt((await publicClient.getBlock()).timestamp);
    await canary.write.sealNote([noteId, 5, copiesHash, now + 60n]);
    await testClient.increaseTime({ seconds: 120 });
    await testClient.mine({ blocks: 1 });
    await expectCustomError(canary.write.openCopy([noteId, 0, readerTag]), "NoteExpired");
  });
});
