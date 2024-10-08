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


  // Deploy ExchangeRateOracle contract
  const ExchangeRateOracle = await ethers.getContractFactory("ExchangeRateOracle");
  const exchangeRateOracle = await ExchangeRateOracle.deploy();
  await exchangeRateOracle.waitForDeployment();
  console.log(`ExchangeRateOracle deployed to: ${exchangeRateOracle.target}`);

  // Deploy MultiCurrencyStakingProtocol with the ExchangeRateOracle address
  const MultiCurrencyStakingProtocol = await ethers.getContractFactory("MultiCurrencyStakingProtocol");
  const stakingProtocol = await MultiCurrencyStakingProtocol.deploy(exchangeRateOracle.target);
  await stakingProtocol.waitForDeployment();
  console.log(`MultiCurrencyStakingProtocol deployed to: ${stakingProtocol.target}`);

  // Now, create two ERC20 tokens: USDz and EGPz
  const USDz = await ethers.getContractFactory("USDz"); // Assuming you have a contract for USDz token
  const usdToken = await USDz.deploy();
  await usdToken.waitForDeployment();
  console.log(`USDz deployed to: ${usdToken.target}`);

  const EGPz = await ethers.getContractFactory("EGPz"); // Assuming you have a contract for EGPz token
  const egpToken = await EGPz.deploy();
  await egpToken.waitForDeployment();
  console.log(`EGPz deployed to: ${egpToken.target}`);

  // TODO there's a prbolem here

  // Add USDz to the protocol with ISO code "USD" and set fee tier 1 (0.25%)
  const addUSDCurrencyTx = await stakingProtocol.addCurrency(
    usdToken.target,        // Address of the USDz token
    "USD",                  // ISO currency code
    10,                    // Transaction fee in basis points (1%)
    0                       // FeeTier.Tier1 (0.25%)
  );
  await addUSDCurrencyTx.wait();
  console.log("USDz added to the staking protocol with Tier1 (0.25% fee)");

  // Add EGPz to the protocol with ISO code "EGP" and set fee tier 2 (0.5%)
  const addEGPCurrencyTx = await stakingProtocol.addCurrency(
    egpToken.target,        // Address of the EGPz token
    "EGP",                  // ISO currency code
    10,                    // Transaction fee in basis points (1%)
    1                       // FeeTier.Tier2 (0.5%)
  );
  await addEGPCurrencyTx.wait();
  console.log("EGPz added to the staking protocol with Tier2 (0.5% fee)");


  // const StakingPool = await ethers.getContractFactory("StakingPool");
  // const StakingPool = await StakingPool.deploy();

  console.log("Deployment completed...");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
