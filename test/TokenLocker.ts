import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { deployContract, solidity } from "ethereum-waffle";
import hre from "hardhat";
import chai from "chai";

import { TokenLocker } from "../typechain/TokenLocker";
import { TestToken } from "../typechain/TestToken";

import {
  ether,
  wei,
  advanceTimeAndBlock,
  MAX_UINT_256,
  ZERO_ADDRESS,
  ONE,
  getLatestBlockTimestamp,
  ZERO,
} from "./utils";

const { expect } = chai;

chai.use(solidity);

describe("Token Locker", () => {
  let owner: SignerWithAddress;
  let testUser1: SignerWithAddress;
  let testUser2: SignerWithAddress;
  let testUser3: SignerWithAddress;

  let lockToken1: TestToken;
  let lockToken2: TestToken;

  let lockToken1Address: string;
  let lockToken2Address: string;

  let tokenLocker: TokenLocker;
  let tokenLockerAddress: string;

  let currentTimestamp: number;

  before(async () => {
    const signers: SignerWithAddress[] = await hre.ethers.getSigners();

    owner = signers[0];
    testUser1 = signers[1];
    testUser2 = signers[2];
    testUser3 = signers[3];

    const TestTokenArtifact = await hre.artifacts.readArtifact("TestToken");

    lockToken1 = <TestToken>await deployContract(owner, TestTokenArtifact);
    lockToken2 = <TestToken>await deployContract(owner, TestTokenArtifact);

    lockToken1Address = lockToken1.address;
    lockToken2Address = lockToken2.address;

    const TokenLockerArtifact = await hre.artifacts.readArtifact("TokenLocker");
    tokenLocker = <TokenLocker>await deployContract(owner, TokenLockerArtifact);
    tokenLockerAddress = tokenLocker.address;

    // approve token transfer
    await lockToken1.approve(tokenLockerAddress, MAX_UINT_256);
    await lockToken2.approve(tokenLockerAddress, MAX_UINT_256);

    currentTimestamp = await getLatestBlockTimestamp();
  });

  describe("lockTokens", () => {
    it("Try lockTokens from other address", async function () {
      await expect(
        tokenLocker
          .connect(testUser1)
          .lockTokens(lockToken1Address, testUser1.address, wei("100"), wei("50"), ether("100"), currentTimestamp + 20),
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Try lockTokens with ZERO token", async function () {
      await expect(
        tokenLocker.lockTokens(
          ZERO_ADDRESS,
          testUser1.address,
          wei("100"),
          wei("50"),
          ether("100"),
          currentTimestamp + 20,
        ),
      ).to.be.revertedWith("Invalid Token");
    });

    it("Try lockTokens with past cliffTime", async function () {
      await expect(
        tokenLocker.lockTokens(
          lockToken1Address,
          testUser1.address,
          wei("100"),
          wei("50"),
          ether("100"),
          currentTimestamp,
        ),
      ).to.be.revertedWith("CliffTime should be greater than current time");
    });

    it("Try lockTokens with zero periodicity", async function () {
      await expect(
        tokenLocker.lockTokens(
          lockToken1Address,
          testUser1.address,
          wei("100"),
          wei("0"),
          ether("100"),
          currentTimestamp + 20,
        ),
      ).to.be.revertedWith("Periodicity should be greater than zero");
    });

    it("Try lockTokens with duration < periodicity", async function () {
      await expect(
        tokenLocker.lockTokens(
          lockToken1Address,
          testUser1.address,
          wei("40"),
          wei("50"),
          ether("100"),
          currentTimestamp + 20,
        ),
      ).to.be.revertedWith("Duration should be greater than periodicity");
    });

    it("Try lockTokens with duration that is not fully divided by periodicity", async function () {
      await expect(
        tokenLocker.lockTokens(
          lockToken1Address,
          testUser1.address,
          wei("70"),
          wei("50"),
          ether("100"),
          currentTimestamp + 20,
        ),
      ).to.be.revertedWith("Duration should be divided by periodicity completely");
    });

    it("Try lockTokens with zero amount", async function () {
      await expect(
        tokenLocker.lockTokens(
          lockToken1Address,
          testUser1.address,
          wei("100"),
          wei("50"),
          ether("0"),
          currentTimestamp + 20,
        ),
      ).to.be.revertedWith("Amount should be greater than zero");
    });

    it("Try lockTokens with invalid beneficiary address", async function () {
      await expect(
        tokenLocker.lockTokens(
          lockToken1Address,
          ZERO_ADDRESS,
          wei("100"),
          wei("50"),
          ether("100"),
          currentTimestamp + 20,
        ),
      ).to.be.revertedWith("Beneficiary can't be zero address");
    });

    it("Lock Token", async function () {
      await tokenLocker.lockTokens(
        lockToken1Address,
        testUser1.address,
        wei("100"),
        wei("50"),
        ether("100"),
        currentTimestamp + 20,
      );
    });

    it("check values of lockId 0", async function () {
      const totalLockCount = await tokenLocker.lockCount();
      const lockInfo = await tokenLocker.lockInfos(0);

      expect(totalLockCount).to.equal(ONE);
      expect(lockInfo[0]).to.equal(lockToken1Address);
      expect(lockInfo[1]).to.equal(testUser1.address);
      expect(lockInfo[2]).to.equal(wei("100"));
      expect(lockInfo[3]).to.equal(wei("50"));
      expect(lockInfo[4]).to.equal(ether("100"));
      expect(lockInfo[5]).to.equal(wei(currentTimestamp + 20));
      expect(lockInfo[6]).to.equal(wei("0"));
    });
  });

  describe("batchLockTokens", function () {
    it("try batchLockTokens with other user", async function () {
      await expect(
        tokenLocker
          .connect(testUser1)
          .batchLockTokens(
            [lockToken2Address],
            [testUser2.address],
            [wei("90")],
            [wei("30")],
            [ether("100")],
            [wei("20")],
          ),
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("try batchLockTokens with different param counts", async function () {
      await expect(
        tokenLocker.batchLockTokens(
          [lockToken2Address],
          [testUser2.address],
          [wei("90")],
          [wei("30")],
          [ether("100")],
          [wei("20"), wei("20")],
        ),
      ).to.be.revertedWith("Invalid params");
    });

    it("lock tokens for testing", async function () {
      await tokenLocker.batchLockTokens(
        [lockToken2Address, lockToken1Address, lockToken2Address, lockToken2Address],
        [testUser2.address, testUser3.address, testUser1.address, testUser3.address],
        [wei("90"), wei("80"), wei("60"), wei("40")],
        [wei("30"), wei("40"), wei("30"), wei("20")],
        [ether("90"), ether("100"), ether("80"), ether("60")],
        [
          wei(currentTimestamp + 30),
          wei(currentTimestamp + 40),
          wei(currentTimestamp + 40),
          wei(currentTimestamp + 50),
        ],
      );
    });
  });

  describe("Check values of each lockId", function () {
    it("check states", async function () {
      expect(await tokenLocker.lockCount()).to.equal(wei(5));
    });

    it("check lockId0", async function () {
      expect(await tokenLocker.getAvailableAmount(0)).to.equal(ZERO);

      const lockInfo = await tokenLocker.lockInfos(0);
      expect(lockInfo[0]).to.equal(lockToken1Address);
      expect(lockInfo[1]).to.equal(testUser1.address);
      expect(lockInfo[2]).to.equal(wei("100"));
      expect(lockInfo[3]).to.equal(wei("50"));
      expect(lockInfo[4]).to.equal(ether("100"));
      expect(lockInfo[5]).to.equal(wei(currentTimestamp + 20));
      expect(lockInfo[6]).to.equal(ZERO);
    });

    it("check lockId1", async function () {
      expect(await tokenLocker.getAvailableAmount(1)).to.equal(ZERO);

      const lockInfo = await tokenLocker.lockInfos(1);
      expect(lockInfo[0]).to.equal(lockToken2Address);
      expect(lockInfo[1]).to.equal(testUser2.address);
      expect(lockInfo[2]).to.equal(wei("90"));
      expect(lockInfo[3]).to.equal(wei("30"));
      expect(lockInfo[4]).to.equal(ether("90"));
      expect(lockInfo[5]).to.equal(wei(currentTimestamp + 30));
      expect(lockInfo[6]).to.equal(ZERO);
    });

    it("check lockId2", async function () {
      expect(await tokenLocker.getAvailableAmount(2)).to.equal(ZERO);

      const lockInfo = await tokenLocker.lockInfos(2);
      expect(lockInfo[0]).to.equal(lockToken1Address);
      expect(lockInfo[1]).to.equal(testUser3.address);
      expect(lockInfo[2]).to.equal(wei("80"));
      expect(lockInfo[3]).to.equal(wei("40"));
      expect(lockInfo[4]).to.equal(ether("100"));
      expect(lockInfo[5]).to.equal(wei(currentTimestamp + 40));
      expect(lockInfo[6]).to.equal(ZERO);
    });

    it("check lockId3", async function () {
      expect(await tokenLocker.getAvailableAmount(3)).to.equal(ZERO);

      const lockInfo = await tokenLocker.lockInfos(3);
      expect(lockInfo[0]).to.equal(lockToken2Address);
      expect(lockInfo[1]).to.equal(testUser1.address);
      expect(lockInfo[2]).to.equal(wei("60"));
      expect(lockInfo[3]).to.equal(wei("30"));
      expect(lockInfo[4]).to.equal(ether("80"));
      expect(lockInfo[5]).to.equal(wei(currentTimestamp + 40));
      expect(lockInfo[6]).to.equal(ZERO);
    });

    it("check lockId4", async function () {
      expect(await tokenLocker.getAvailableAmount(4)).to.equal(ZERO);

      const lockInfo = await tokenLocker.lockInfos(4);
      expect(lockInfo[0]).to.equal(lockToken2Address);
      expect(lockInfo[1]).to.equal(testUser3.address);
      expect(lockInfo[2]).to.equal(wei("40"));
      expect(lockInfo[3]).to.equal(wei("20"));
      expect(lockInfo[4]).to.equal(ether("60"));
      expect(lockInfo[5]).to.equal(wei(currentTimestamp + 50));
      expect(lockInfo[6]).to.equal(ZERO);
    });
  });

  describe("Advance 20 time and release", function () {
    it("Advance 20 time", async function () {
      await advanceTimeAndBlock(20);
    });

    it("check releasable amounts", async function () {
      expect(await tokenLocker.getAvailableAmount(0)).to.equal(ether("50"));
      expect(await tokenLocker.getAvailableAmount(1)).to.equal(ZERO);
      expect(await tokenLocker.getAvailableAmount(2)).to.equal(ZERO);
      expect(await tokenLocker.getAvailableAmount(3)).to.equal(ZERO);
      expect(await tokenLocker.getAvailableAmount(4)).to.equal(ZERO);
    });

    it("release from testUser1", async function () {
      await tokenLocker.connect(testUser1).releaseAllAvailableTokens();
    });

    it("check balance of testUser1", async function () {
      expect(await lockToken1.balanceOf(testUser1.address)).to.equal(ether("50"));
    });

    it("check balance of testUser1", async function () {
      expect(await tokenLocker.getAvailableAmount(0)).to.equal(ZERO);
    });
  });

  describe("Advance 30 time and check", function () {
    it("Advance 30 time", async function () {
      await advanceTimeAndBlock(30);
    });

    it("check releasable amounts", async function () {
      expect(await tokenLocker.getAvailableAmount(0)).to.equal(ZERO);
      expect(await tokenLocker.getAvailableAmount(1)).to.equal(ether("30"));
      expect(await tokenLocker.getAvailableAmount(2)).to.equal(ether("50"));
      expect(await tokenLocker.getAvailableAmount(3)).to.equal(ether("40"));
      expect(await tokenLocker.getAvailableAmount(4)).to.equal(ether("30"));
    });
  });

  describe("Advance 5 time and check", function () {
    it("Advance 5 time", async function () {
      await advanceTimeAndBlock(5);
    });

    it("check releasable amounts", async function () {
      expect(await tokenLocker.getAvailableAmount(0)).to.equal(ZERO);
      expect(await tokenLocker.getAvailableAmount(1)).to.equal(ether("30"));
      expect(await tokenLocker.getAvailableAmount(2)).to.equal(ether("50"));
      expect(await tokenLocker.getAvailableAmount(3)).to.equal(ether("40"));
      expect(await tokenLocker.getAvailableAmount(4)).to.equal(ether("30"));
    });
  });

  describe("Advance 35 time and check", function () {
    it("Advance 35 time", async function () {
      await advanceTimeAndBlock(35);
    });

    it("check releasable amounts", async function () {
      expect(await tokenLocker.getAvailableAmount(0)).to.equal(ether("50"));
      expect(await tokenLocker.getAvailableAmount(1)).to.equal(ether("90"));
      expect(await tokenLocker.getAvailableAmount(2)).to.equal(ether("100"));
      expect(await tokenLocker.getAvailableAmount(3)).to.equal(ether("80"));
      expect(await tokenLocker.getAvailableAmount(4)).to.equal(ether("60"));
    });
  });

  describe("do Release", function () {
    it("releaseAllAvailableTokens", async function () {
      await tokenLocker.connect(testUser1).releaseAllAvailableTokens();
    });

    it("releaseAllAvailableTokensToBeneficiary", async function () {
      await expect(
        tokenLocker.connect(testUser1).releaseAllAvailableTokensToBeneficiary(testUser2.address),
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await tokenLocker.releaseAllAvailableTokensToBeneficiary(testUser2.address);
    });

    it("batchReleaseAllAvailableTokensToBeneficiaries", async function () {
      await expect(
        tokenLocker
          .connect(testUser1)
          .batchReleaseAllAvailableTokensToBeneficiaries([testUser1.address, testUser3.address]),
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await tokenLocker.batchReleaseAllAvailableTokensToBeneficiaries([testUser1.address, testUser3.address]);
    });
  });

  describe("check tokenLocker info and accounts balance", function () {
    it("check tokenLocker info", async function () {
      expect(await lockToken1.balanceOf(tokenLockerAddress)).to.equal(ZERO);
      expect(await lockToken2.balanceOf(tokenLockerAddress)).to.equal(ZERO);
    });

    it("check lockId0", async function () {
      expect(await tokenLocker.getAvailableAmount(0)).to.equal(ZERO);

      const lockInfo = await tokenLocker.lockInfos(0);
      expect(lockInfo[6]).to.equal(ether("100"));
    });

    it("check lockId1", async function () {
      expect(await tokenLocker.getAvailableAmount(1)).to.equal(ZERO);

      const lockInfo = await tokenLocker.lockInfos(1);
      expect(lockInfo[6]).to.equal(ether("90"));
    });

    it("check lockId2", async function () {
      expect(await tokenLocker.getAvailableAmount(2)).to.equal(ZERO);

      const lockInfo = await tokenLocker.lockInfos(2);
      expect(lockInfo[6]).to.equal(ether("100"));
    });

    it("check lockId3", async function () {
      expect(await tokenLocker.getAvailableAmount(3)).to.equal(ZERO);

      const lockInfo = await tokenLocker.lockInfos(3);
      expect(lockInfo[6]).to.equal(ether("80"));
    });

    it("check lockId4", async function () {
      expect(await tokenLocker.getAvailableAmount(4)).to.equal(ZERO);

      const lockInfo = await tokenLocker.lockInfos(4);
      expect(lockInfo[6]).to.equal(ether("60"));
    });

    it("check user balances", async function () {
      expect(await lockToken1.balanceOf(testUser1.address)).to.equal(ether("100"));
      expect(await lockToken2.balanceOf(testUser1.address)).to.equal(ether("80"));
      expect(await lockToken2.balanceOf(testUser2.address)).to.equal(ether("90"));
      expect(await lockToken1.balanceOf(testUser3.address)).to.equal(ether("100"));
      expect(await lockToken2.balanceOf(testUser3.address)).to.equal(ether("60"));
    });
  });
});
