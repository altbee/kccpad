import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { deployContract } from "ethereum-waffle";
import hre from "hardhat";
import { TokenLocker } from "../typechain/TokenLocker";
import { TestToken } from "../typechain/TestToken";

import { ether, wei, advanceBlock, advanceTime, advanceTimeAndBlock } from "./utils";

describe("Token Locker", () => {
  let owner: SignerWithAddress;
  let testUser1: SignerWithAddress;
  let testUser2: SignerWithAddress;
  let testUser3: SignerWithAddress;
  let testUser4: SignerWithAddress;

  let lockToken1: TestToken;
  let lockToken2: TestToken;

  let tokenLocker: TokenLocker;

  before(async () => {
    const signers: SignerWithAddress[] = await hre.ethers.getSigners();

    owner = signers[0];
    testUser1 = signers[1];
    testUser2 = signers[2];
    testUser3 = signers[3];
    testUser4 = signers[4];

    const TestTokenArtifact = await hre.artifacts.readArtifact("TestToken");

    lockToken1 = <TestToken>await deployContract(owner, TestTokenArtifact);
    lockToken2 = <TestToken>await deployContract(owner, TestTokenArtifact);

    const TokenLockerArtifact = await hre.artifacts.readArtifact("TokenLocker");
    tokenLocker = <TokenLocker>await deployContract(owner, TokenLockerArtifact);
  });

  describe("lockTokens", () => {});
});
