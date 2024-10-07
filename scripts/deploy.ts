import { ethers } from "hardhat";

async function main() {
  // Deploy the Lock contract
  console.log("Start deployment...");

  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log(`Account balance: ` + balance);
  // Rest of your deployment code...

  const USDz = await ethers.getContractFactory("USDz");
  const USD = await USDz.deploy();

  console.log("Deployment completed...");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
