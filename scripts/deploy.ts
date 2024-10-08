import { ethers } from "hardhat";

async function main() {
  // Deploy the Lock contract
  console.log("Start deployment...");

  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log(`Account balance: ` + balance);

  // if (balance.eq(0)) {
  //   console.error("Insufficient funds in the deployer account.");
  //   return;
  // }

  // Deploy the USDz contract (Assuming USDz is an ERC20 token)
  const USDz = await ethers.getContractFactory("USDz");
  const usdToken = await USDz.deploy();
  await usdToken.waitForDeployment(); // Updated method
  // await usdToken.deployed();
  console.log(`USDz deployed to: ${usdToken.target}`);

  // Deploy the MultiCurrencyStakingProtocol contract
  const MultiCurrencyStakingProtocol = await ethers.getContractFactory("MultiCurrencyStakingProtocol");
  const stakingProtocol = await MultiCurrencyStakingProtocol.deploy();
  await stakingProtocol.waitForDeployment(); // Updated method
  // await stakingProtocol.deployed();
  console.log(`MultiCurrencyStakingProtocol deployed to: ${stakingProtocol.target}`);

  // const StakingPool = await ethers.getContractFactory("StakingPool");
  // const StakingPool = await StakingPool.deploy();

  console.log("Deployment completed...");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
