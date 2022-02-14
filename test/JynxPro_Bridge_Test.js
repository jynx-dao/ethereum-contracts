const JynxPro_Bridge = artifacts.require("JynxPro_Bridge");

contract("JynxPro_Bridge", (accounts) => {
  it("should add signer", async () => {
    let jynx_pro_bridge = await JynxPro_Bridge.deployed();
    let message = "";
    let signatures = "";
    await jynx_pro_bridge.add_signer(accounts[1], message, signatures);
  });
});
