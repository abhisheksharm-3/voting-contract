require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-ignition");
require("dotenv").config();

module.exports = {
  solidity: "0.8.24",
  networks: {

    hardhat: {},
    // sepolia: {
    //   url: `https://sepolia.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
    //   accounts: [process.env.PRIVATE_KEY]
    // }
  },
  // etherscan: {
  //   apiKey: process.env.ETHERSCAN_API_KEY
  // }
};