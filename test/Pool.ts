import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { deployContract } from "ethereum-waffle";
import hre from "hardhat";
import {Pool} from "../typechain/Pool"
import {PoolFactory} from "../typechain/PoolFactory"
import {TestToken} from "../typechain/TestToken"
import {ether, wei} from "./utils"



describe("Pool Test", () => {
    let owner: SignerWithAddress;
    let testUser1: SignerWithAddress;
    let testUser2: SignerWithAddress;
    let testUser3: SignerWithAddress;
    let testUser4: SignerWithAddress;
    let testUser5: SignerWithAddress;
    let feeRecipient: SignerWithAddress;

    let teamToken: TestToken;
    let saleToken: TestToken;
    let fundToken: TestToken;

    let kucPool: Pool;
    let tokenPool: Pool;
    let poolFactory: PoolFactory;

    const baseAmount = ether("1000");
    const feePercent = wei("100"); // 10% fee

    before(async () => {
        const signers: SignerWithAddress[] = await hre.ethers.getSigners();

        owner = signers[0];
        testUser1 = signers[1];
        testUser2 = signers[2];
        testUser3 = signers[3];
        testUser4 = signers[4];
        testUser5 = signers[5];
        feeRecipient = signers[6];

        const TestTokenArtifact = await hre.artifacts.readArtifact("TestToken");

        teamToken = <TestToken>await deployContract(owner, TestTokenArtifact);
        fundToken = <TestToken>await deployContract(owner, TestTokenArtifact);
        saleToken = <TestToken>await deployContract(owner, TestTokenArtifact);
    });

    describe("Deploy PoolFactory", function () {})

    describe("Create KUC Pool", function () {
        it("")
    })

    describe("Create Token-Buy Pool", function () {})
})