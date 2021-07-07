import { network} from "hardhat"

export const advanceTime = async (time: number) =>  new Promise((resolve, reject) => {
    network.provider.send("evm_increaseTime", [time]).then(resolve).catch(reject)
});

export const advanceBlock = () =>  new Promise((resolve, reject) => {
    network.provider.send("evm_mine").then(resolve).catch(reject)
});

export const advanceTimeAndBlock = async (time: number) => {
  await advanceTime(time);
  await advanceBlock();
};

