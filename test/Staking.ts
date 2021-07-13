import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { deployContract, solidity } from "ethereum-waffle";
import hre from "hardhat";
import chai from "chai";

import { Staking } from "../typechain/Staking";
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
  getLatestBlockNumber,
  advanceBlock,
  ONE_DAY_IN_SECONDS,
  ONE_DAY_SECONDS,
} from "./utils";

const { expect } = chai;

chai.use(solidity);

describe("Staking", () => {
  let owner: SignerWithAddress;
  let testUser1: SignerWithAddress;
  let testUser2: SignerWithAddress;
  let testUser3: SignerWithAddress;

  let testToken: TestToken;

  let currentTimestamp: number;
  let currentBlockNumber: number;

  let staking: Staking;

  before(async () => {
    const signers: SignerWithAddress[] = await hre.ethers.getSigners();

    owner = signers[0];
    testUser1 = signers[1];
    testUser2 = signers[2];
    testUser3 = signers[3];

    const TestTokenArtifact = await hre.artifacts.readArtifact("TestToken");

    testToken = <TestToken>await deployContract(owner, TestTokenArtifact);

    const StakingArtifact = await hre.artifacts.readArtifact("Staking");
    staking = <Staking>await deployContract(owner, StakingArtifact);

    currentTimestamp = await getLatestBlockTimestamp();
    currentBlockNumber = await getLatestBlockNumber();

    // send test tokens
    await testToken.transfer(testUser1.address, ether("10000"));
    await testToken.transfer(testUser2.address, ether("10000"));
    await testToken.transfer(testUser3.address, ether("10000"));

    // send reward tokens
    await testToken.transfer(staking.address, ether("1000000"));

    // approve
    await testToken.connect(testUser1).approve(staking.address, MAX_UINT_256);
    await testToken.connect(testUser2).approve(staking.address, MAX_UINT_256);
    await testToken.connect(testUser3).approve(staking.address, MAX_UINT_256);
  });

  describe("call setToken and startStaking", function () {
    it("call setToken", async function () {
      await expect(staking.connect(testUser1).setToken(testToken.address)).to.be.revertedWith(
        "Ownable: caller is not the owner",
      );

      await expect(staking.setToken(ZERO_ADDRESS)).to.be.revertedWith("Invalid Token Address");

      await staking.setToken(testToken.address);

      await expect(staking.setToken(testToken.address)).to.be.revertedWith("Token already set!");
    });

    it("start Staking", async function () {
      await expect(staking.connect(testUser1).startStaking(currentBlockNumber)).to.be.revertedWith(
        "Ownable: caller is not the owner",
      );

      await staking.startStaking(currentBlockNumber);

      await expect(staking.startStaking(currentBlockNumber)).to.be.revertedWith("Staking already started");
    });

    it("check poolInfo", async function () {
      const poolInfo = await staking.poolInfo(0);
      expect(poolInfo[0]).to.equal(wei(1000));
      expect(poolInfo[1]).to.equal(wei(currentBlockNumber));
      expect(poolInfo[2]).to.equal(wei(0));
      expect(poolInfo[3]).to.equal(wei(0));
      expect(poolInfo[4]).to.equal(wei(0));
      expect(poolInfo[5]).to.equal(wei(30 * 24 * 60 * 60));
    });
  });

  describe("deposit some tokens", function () {
    it("deposit with invalid poolId", async function () {
      await expect(staking.deposit(1, ether("100"))).to.be.revertedWith("Pool does not exist");
    });

    it("deposit from testUser1", async function () {
      await staking.connect(testUser1).deposit(0, ether("100"));
    });

    it("check Pool Info", async function () {
      const poolInfo = await staking.poolInfo(0);
      const latestBlockNumber = await getLatestBlockNumber();
      expect(poolInfo[0]).to.equal(wei(1000));
      expect(poolInfo[1]).to.equal(wei(latestBlockNumber));
      expect(poolInfo[2]).to.equal(wei(0));
      expect(poolInfo[3]).to.equal(ether("100"));
      expect(poolInfo[4]).to.equal(wei(0));
      expect(poolInfo[5]).to.equal(wei(30 * 24 * 60 * 60));
    });

    it("check testUser1 Info", async function () {
      const userInfo = await staking.userInfo(0, testUser1.address);
      expect(userInfo[0]).to.equal(ether("100"));
      expect(userInfo[1]).to.equal(wei("0"));
      expect(userInfo[2]).to.equal(wei("0"));
      const latestTimeStamp = await getLatestBlockTimestamp();
      expect(userInfo[3]).to.equal(wei(latestTimeStamp));
    });

    it("Advance time", async function () {
      await advanceBlock();
      await advanceBlock();
      await advanceBlock();
      await advanceBlock();
      await advanceTimeAndBlock(ONE_DAY_SECONDS);
    });

    it("check pendingRewards of testUser1", async function () {
      expect(await staking.pendingRewards(0, testUser1.address)).to.equal(ether("5"));
    });

    it("deposit from testUser2", async function () {
      await staking.connect(testUser2).deposit(0, ether("400"));
    });

    it("check Pool Info", async function () {
      const poolInfo = await staking.poolInfo(0);
      const latestBlockNumber = await getLatestBlockNumber();
      expect(poolInfo[0]).to.equal(wei(1000));
      expect(poolInfo[1]).to.equal(wei(latestBlockNumber));
      expect(poolInfo[2]).to.equal(wei("60000000000")); // 6ether * 10**12 / 100ether
      expect(poolInfo[3]).to.equal(ether("500"));
      expect(poolInfo[4]).to.equal(ether(6));
      expect(poolInfo[5]).to.equal(wei(30 * 24 * 60 * 60));
    });

    it("check testUser1 Info", async function () {
      const userInfo = await staking.userInfo(0, testUser1.address);
      expect(userInfo[0]).to.equal(ether("100"));
      expect(userInfo[1]).to.equal(wei("0"));
      expect(userInfo[2]).to.equal(wei("0"));
    });

    it("check testUser2 Info", async function () {
      const userInfo = await staking.userInfo(0, testUser2.address);
      expect(userInfo[0]).to.equal(ether("400"));
      expect(userInfo[1]).to.equal(ether("24")); // rewardDebt = 400 * 0.06
      expect(userInfo[2]).to.equal(wei("0"));
      const latestTimeStamp = await getLatestBlockTimestamp();
      expect(userInfo[3]).to.equal(wei(latestTimeStamp));
    });

    it("Advance time", async function () {
      await advanceBlock();
      await advanceBlock();
      await advanceBlock();
      await advanceBlock();
      await advanceTimeAndBlock(ONE_DAY_SECONDS);
    });

    it("check pendingRewards", async function () {
      expect(await staking.pendingRewards(0, testUser1.address)).to.equal(ether("7"));
      expect(await staking.pendingRewards(0, testUser2.address)).to.equal(ether("4"));
    });

    it("deposit from testUser1", async function () {
      await staking.connect(testUser3).deposit(0, ether("500"));
    });

    it("check Pool Info", async function () {
      const poolInfo = await staking.poolInfo(0);
      const latestBlockNumber = await getLatestBlockNumber();
      expect(poolInfo[0]).to.equal(wei(1000));
      expect(poolInfo[1]).to.equal(wei(latestBlockNumber));
      expect(poolInfo[2]).to.equal(wei("72000000000")); // 6ether * 10**12 / 100ether
      expect(poolInfo[3]).to.equal(ether("1000"));
      expect(poolInfo[4]).to.equal(ether(12));
      expect(poolInfo[5]).to.equal(wei(30 * 24 * 60 * 60));
    });

    it("check testUser3 Info", async function () {
      const userInfo = await staking.userInfo(0, testUser3.address);
      expect(userInfo[0]).to.equal(ether("500"));
      expect(userInfo[1]).to.equal(ether("36")); // rewardDebt = 500 * 0.072
      expect(userInfo[2]).to.equal(wei("0"));
      const latestTimeStamp = await getLatestBlockTimestamp();
      expect(userInfo[3]).to.equal(wei(latestTimeStamp));
    });

    it("claim Rewards from testUser1", async function () {
      await expect(staking.connect(testUser1).claim(1)).to.be.revertedWith("Pool does not exist");
      await staking.connect(testUser1).claim(0);
    });

    it("check testUser1 Info", async function () {
      const userInfo = await staking.userInfo(0, testUser1.address);
      expect(userInfo[0]).to.equal(ether("100"));
      expect(userInfo[1]).to.equal(wei("0"));
      expect(userInfo[2]).to.equal(wei("0"));
      const latestTimeStamp = await getLatestBlockTimestamp();
      expect(userInfo[3]).to.equal(wei(latestTimeStamp));
    });

    it("Advance time", async function () {
      await advanceBlock();
      await advanceBlock();
      await advanceBlock();
      await advanceBlock();
      await advanceTimeAndBlock(ONE_DAY_SECONDS);
    });

    it("check pendingRewards", async function () {});

    it("check getDepositedAmount", async function () {
      expect(await staking.getDepositedAmount(testUser1.address)).to.equal(ether("100"));
      expect(await staking.getDepositedAmount(testUser2.address)).to.equal(ether("400"));
      expect(await staking.getDepositedAmount(testUser3.address)).to.equal(ether("500"));
    });
  });
});
