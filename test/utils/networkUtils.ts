import { ethers } from "hardhat";

export const getLatestBlockTimestamp = async (): Promise<number> => {
  const latestBlock = await ethers.provider.getBlock("latest");
  return latestBlock.timestamp;
};

export const getLatestBlockNumber = async (): Promise<number> => {
  const latestBlock = await ethers.provider.getBlock("latest");
  return latestBlock.number;
};
