import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { network } from "hardhat";

const id = "0x4f4e4f5355535f4d4f4e41445f44524f505f3030303030303030303030303030";
const digest = "0x1d9f0d2a2e10e3580481170dc38f3dce11399ee6d26c6621dbb3dc401b3c7adf";
const noRecipient = "0x0000000000000000000000000000000000000000";

async function expectCustomError(action: Promise<unknown>, name: string) {
  await assert.rejects(action, (error: unknown) =>
    error instanceof Error && error.message.includes(name),
  );
}

describe("NoSusMonadDrops", () => {
  async function deployDropContract() {
    const { viem } = await network.getOrCreate();
    const [sender, recipient, stranger] = await viem.getWalletClients();
    const drops = await viem.deployContract("NoSusMonadDrops");
    return { viem, sender, recipient, stranger, drops };
  }

  it("seals a ciphertext digest and exposes the initial receipt", async () => {
    const { drops, sender, viem } = await deployDropContract();
    const publicClient = await viem.getPublicClient();
    const now = BigInt((await publicClient.getBlock()).timestamp);
    const expiry = now + 3600n;

    await drops.write.seal([id, digest, noRecipient, expiry]);

    const receipt = await drops.read.receiptOf([id]);
    assert.equal(receipt.sender.toLowerCase(), sender.account.address.toLowerCase());
    assert.equal(receipt.ciphertextDigest, digest);
    assert.equal(receipt.opener, noRecipient);
    assert.equal(await drops.read.canDecrypt([id, noRecipient]), false);
    assert.equal(await drops.read.canDecrypt([id, sender.account.address]), false);
    const sealedEvents = await drops.getEvents.Sealed({ id }, { fromBlock: 0n });
    assert.equal(sealedEvents.length, 1);
    assert.equal(sealedEvents[0].args.sender?.toLowerCase(), sender.account.address.toLowerCase());
  });

  it("rejects duplicate IDs and zero ciphertext digests", async () => {
    const { drops } = await deployDropContract();

    await drops.write.seal([id, digest, noRecipient, 0n]);
    await expectCustomError(drops.write.seal([id, digest, noRecipient, 0n]), "DropAlreadyExists");
    await expectCustomError(
      drops.write.seal([`${id.slice(0, -1)}1`, `0x${"0".repeat(64)}`, noRecipient, 0n]),
      "InvalidCiphertextDigest",
    );
  });

  it("allows only the named recipient to acknowledge once", async () => {
    const { drops, recipient, stranger } = await deployDropContract();
    await drops.write.seal([id, digest, recipient.account.address, 0n]);
    assert.equal(await drops.read.canDecrypt([id, recipient.account.address]), false);

    await expectCustomError(
      drops.write.acknowledgeOpen([id], { account: stranger.account }),
      "RecipientOnly",
    );

    await drops.write.acknowledgeOpen([id], { account: recipient.account });
    assert.equal(await drops.read.canDecrypt([id, recipient.account.address]), true);
    assert.equal(await drops.read.canDecrypt([id, stranger.account.address]), false);
    const openedEvents = await drops.getEvents.OpenAcknowledged(
      { opener: recipient.account.address },
      { fromBlock: 0n },
    );
    assert.equal(openedEvents.length, 1);
    assert.equal(openedEvents[0].args.id, id);
    await expectCustomError(
      drops.write.acknowledgeOpen([id], { account: recipient.account }),
      "DropAlreadyOpened",
    );
  });

  it("refuses an expired drop", async () => {
    const { drops, sender, viem } = await deployDropContract();
    const publicClient = await viem.getPublicClient();
    const now = BigInt((await publicClient.getBlock()).timestamp);

    await drops.write.seal([id, digest, noRecipient, now + 60n]);
    await publicClient.request({
      method: "evm_increaseTime",
      params: [61],
    });
    await publicClient.request({ method: "evm_mine", params: [] });

    await expectCustomError(drops.write.acknowledgeOpen([id]), "DropExpired");
    assert.equal(await drops.read.canDecrypt([id, sender.account.address]), false);
  });

  it("stops decryption after expiry even if already acknowledged", async () => {
    const { drops, recipient, viem } = await deployDropContract();
    const publicClient = await viem.getPublicClient();
    const now = BigInt((await publicClient.getBlock()).timestamp);

    await drops.write.seal([id, digest, recipient.account.address, now + 60n]);
    await drops.write.acknowledgeOpen([id], { account: recipient.account });
    assert.equal(await drops.read.canDecrypt([id, recipient.account.address]), true);

    await publicClient.request({
      method: "evm_increaseTime",
      params: [61],
    });
    await publicClient.request({ method: "evm_mine", params: [] });

    assert.equal(await drops.read.canDecrypt([id, recipient.account.address]), false);
  });

  it("treats the exact expiry timestamp as expired", async () => {
    const { drops, recipient, viem } = await deployDropContract();
    const publicClient = await viem.getPublicClient();
    const now = BigInt((await publicClient.getBlock()).timestamp);
    const expiry = now + 60n;

    await drops.write.seal([id, digest, recipient.account.address, expiry]);
    await publicClient.request({
      method: "evm_increaseTime",
      params: [60],
    });
    await publicClient.request({ method: "evm_mine", params: [] });

    await expectCustomError(drops.write.acknowledgeOpen([id], { account: recipient.account }), "DropExpired");
    assert.equal(await drops.read.canDecrypt([id, recipient.account.address]), false);
  });
});
