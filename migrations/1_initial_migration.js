const Migrations = artifacts.require("Migrations");
const JYNX = artifacts.require("JYNX");
const DAI = artifacts.require("DAI");
const JynxPro_Bridge = artifacts.require("JynxPro_Bridge");
const JYNX_Distribution = artifacts.require("JYNX_Distribution");

module.exports = async function (deployer) {
  deployer.deploy(Migrations);
  await deployer.deploy(DAI, "DAI", "DAI", 18, 10000000000);
  await deployer.deploy(JYNX_Distribution, DAI.address);
  await deployer.deploy(JYNX, "Jynx DAO", "JYNX", 18, 1000000000, JYNX_Distribution.address);
  await deployer.deploy(JynxPro_Bridge, JYNX.address, JYNX_Distribution.address, 667);
};
