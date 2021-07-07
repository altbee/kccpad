# core-contracts

Deployment Instructions:

1. duplicate `.env.example` and rename to `.env`
2. copy and paste your MNEMONIC key into `.env` file
3. deploy: `npx hardhat run scripts/deployMoonBear.ts --network bsct`

(this will deploy contract to the bsc testnet; to deploy on mainnet, just change bsct to bsc)

To verify contract: `npx hardhat verify --network bsct <address>`

