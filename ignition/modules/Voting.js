const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("Voting", (m) => {
  const Voting = m.contract("Voting");

  return { Voting };
});