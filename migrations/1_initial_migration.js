const Migrations = artifacts.require("Migrations");
const JYNX = artifacts.require("JYNX");
const JynxPro_Bridge = artifacts.require("JynxPro_Bridge");

module.exports = async function (deployer) {
  deployer.deploy(Migrations);
  await deployer.deploy(JYNX, "Jynx DAO", "JYNX", 18, 1000000000);
  await deployer.deploy(JynxPro_Bridge, JYNX.address, 670);
};
