const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("VotingPlatform", (m) => {
  const Voting = m.contract("VotingPlatform");

  return { Voting };
});