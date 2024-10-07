#!/bin/zsh

npx hardhat compile
npx hardhat test
npx hardhat run scripts/deploy.ts --network XRPL_EVM_Sidechain_Devnet
