# Dazu - Remittance Proof of Concept for Permissionless Hackathon

## Important

This is a fork of the demo project shared by https://github.com/hazardcookie/Band-Oracle-Foundry-Workshop?tab=readme-ov-file

Also check docs here - https://github.com/maximedgr/xrpl-evm-quickstart-hardhat


## Installation instructions

1. Clone the repository
2. Run `npm i` to install the necessary dependencies
3. Create a `.env` file at the root of the project and add the following line: `DEV_PRIVATE_KEY=your_dev_private_key`.  
   To obtain this private key, simply export it from your MetaMask wallet.
3. Compile the project
  ```
  npx hardhat compile
  ```
4. Test run the project
  ```
  npx hardhat test
  ```
5. Deploy the contracts
  ```
  npx hardhat run scripts/deploy.ts --network XRPL_EVM_Sidechain_Devnet
  ```

## Wallets & Accounts

I have created 4 different accounts so I can properly manage the use-case and test it out:

* PL_DAZU_Treasury - this is the main dazu treasury which holds the money we've created and are managing in our wallets
* PL_USA_User - this is a user in the US who wants to send USD or receive USD
* PL_USA_LP - a user in the US who is deposited USD into the pool and getting the money from them
* PL_EG_User - this is a user in Egypt who wants to send EGP abroad or receive EGP in Egypt
* PL_EG_LP - This is a liquidity pool in the US.

We can split the users into:
* Stakers
* Transactors

## Liqudiity Pools

I need a liquidity pool which holds all the tokens


## Verify an account

```
// This is the example
npx hardhat verify --network XRPL_EVM_Sidechain_Devnet DEPLOYED_CONTRACT_ADDRESS "Constructor argument 1"

// USDz
npx hardhat verify --network XRPL_EVM_Sidechain_Devnet --contract contracts/currencies/USDz.sol:USDz 0x6B5EA1E2cA488349EdEAF00d7cD38f8990D3e0C1
// EGPz
npx hardhat verify --network XRPL_EVM_Sidechain_Devnet --contract contracts/currencies/EGPz.sol:EGPz 0xb7ac9229F6B9e0797f719315625ae71eF381A3e9
// ExchangeRate
npx hardhat verify --network XRPL_EVM_Sidechain_Devnet 0xE9d52030CA900697E9337dD3B08cBbC16E2A33eC
// Multicurrencystaking
npx hardhat verify --network XRPL_EVM_Sidechain_Devnet 0x4CC329Fe26540fec97006Cdd54A85d9940491F9E  0xE9d52030CA900697E9337dD3B08cBbC16E2A33eC
```

## Public contract IDs

USDz:                           0x6B5EA1E2cA488349EdEAF00d7cD38f8990D3e0C1
EGPz:                           0xb7ac9229F6B9e0797f719315625ae71eF381A3e9
IExchangeRate:                  0xE9d52030CA900697E9337dD3B08cBbC16E2A33eC
MultiCurrencyStakingProtocol:   0x4CC329Fe26540fec97006Cdd54A85d9940491F9E

