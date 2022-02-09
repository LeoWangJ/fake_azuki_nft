const hre = require("hardhat");

async function main() {
  const Leozuki = await hre.ethers.getContractFactory("Leozuki");
  const leozuki = await Leozuki.deploy();

  await leozuki.deployed();

  console.log("Leozuki deployed to:", leozuki.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
