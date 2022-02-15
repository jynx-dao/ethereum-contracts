const JynxPro_Bridge = artifacts.require("JynxPro_Bridge");

const abi = require('ethereumjs-abi');
const crypto = require("crypto");
const ethUtil = require('ethereumjs-util');

let private_keys = {
  "0xE2dC41E809A3c82B18DDdFB0A36B5f2CFA63CF2f": Buffer.from("b219d340d8e6aacdca54cecf104e6998b21411c9858ff1d25324a98d38ed034c", "hex"),
  "0xC18Ec48d055E5649f11292C4956b5B8218F3c7D7": Buffer.from("7cc898acf8301d4a7f7ccc534b11a2556a31c37116715fe9b2b4ba25f68c121b", "hex"),
  "0xF69f5ECDc563d2092Acd75452e30820D9C729c82": Buffer.from("f060016692932fb450d1860b23f66fbfaccc14e2d0b590deec40f61294354819", "hex"),
  "0x7A626e996e661548d459Ace93d807347da090BE2": Buffer.from("5f652058103d2c58b7c431d10dfd06748766737541fca510ccf4f2e2281613ad", "hex"),
  "0x0b58aC384Aa4A33085E0C532Cd3D2b6eb4F816c7": Buffer.from("88d9e6a87e4caaeeaf9a825c81c59e949ea7fa5eb801aa0a6d4a0c4484492e59", "hex"),
  "0x4b68Bb47DC6a3EF83c6F8e022fBd2cA7373e43EE": Buffer.from("7741cbaaab69ad7ebb2c80fcb0869488c78aacddd5314a9e9585bd84e25cdd90", "hex"),
  "0xc440514cbB587918E9c1bd2336db1Dc1C11CAE53": Buffer.from("1e47d375c9cb895ec86a0106523c92117640b316909fd12880fda655af9af74b", "hex"),
  "0xE34175C384495193E8eB7AaE15969df4145822aF": Buffer.from("6f457149725d8ee5b363b38d023270ee05ca30e295a2085c479b50feb3a00927", "hex"),
  "0x55aa8aAAeEC1C7Fe124F5e25753E5120e2Cb8a01": Buffer.from("1844395cb9c6dd1cea739802c8989fbe43db51f66d179556a15642c08ff2eb70", "hex"),
  "0xF3cF472C470A4CE6bA5093568EF63F109fA520cD": Buffer.from("a1d09be632cae8f4476a2eac56abdb6826e4778116ac5787cdd22b2a15ce69e5", "hex")
};

function get_message_to_sign(
  param_types,
  params,
  nonce,
  function_name,
  sender
) {
    params.push(nonce);
    param_types.push("uint256");
    params.push(function_name);
    param_types.push("string");
    const encoded_a = abi.rawEncode(param_types, params);
    return abi.rawEncode(["bytes", "address"], [encoded_a, sender]);
}


function to_signature_string(sig){
    return "0x" + sig.r.toString('hex') + "" + sig.s.toString('hex') +""+ sig.v.toString(16);
}

contract("JynxPro_Bridge", (accounts) => {

  describe("verify_signatures", async () => {});

  describe("add_signer", async () => {
    const test_add_signer = async (signer) => {
      const jynx_pro_bridge = await JynxPro_Bridge.deployed();
      const nonce = new ethUtil.BN(crypto.randomBytes(32));
      let encoded_message = get_message_to_sign(
        ["address"],
        [signer],
        nonce,
        "add_signer",
        accounts[0]
      );
      const encoded_hash = ethUtil.keccak256(encoded_message);
      const signature = ethUtil.ecsign(encoded_hash, private_keys[accounts[0]]);
      const sig_string = to_signature_string(signature);
      await jynx_pro_bridge.add_signer(signer, nonce, sig_string, {from:accounts[0]});
      const signer_count = await jynx_pro_bridge.signer_count.call();
      const signers0 = await jynx_pro_bridge.signers.call(accounts[0]);
      const signers1 = await jynx_pro_bridge.signers.call(accounts[1]);
      assert.equal(signer_count, 2);
      assert.equal(signers0, true);
      assert.equal(signers1, true);
    }
    it("should add signer", async () => {
      await test_add_signer(accounts[1]);
    });
    it("should fail to add signer when already registered", async () => {
      try {
        await test_add_signer(accounts[1]);
      } catch(e) {
        assert.equal(e.reason, "User is already a signer");
      }
    });
    it("should fail to add signer with invalid signature", async () => {
      try {
        await test_add_signer(accounts[2]);
      } catch(e) {
        assert.equal(e.reason, "Signature invalid");
      }
    });
  });

  describe("remove_signer", async () => {
    const test_remove_signer = async (signer, valid_sig) => {
      const jynx_pro_bridge = await JynxPro_Bridge.deployed();
      const nonce = new ethUtil.BN(crypto.randomBytes(32));
      let encoded_message = get_message_to_sign(
        ["address"],
        [signer],
        nonce,
        "remove_signer",
        accounts[0]
      );
      const encoded_hash = ethUtil.keccak256(encoded_message);
      const signature = ethUtil.ecsign(encoded_hash, private_keys[accounts[0]]);
      let sig_string = to_signature_string(signature);
      if(valid_sig) {
        const signature2 = ethUtil.ecsign(encoded_hash, private_keys[accounts[1]]);
        sig_string += to_signature_string(signature2).substr(2);
      }
      await jynx_pro_bridge.remove_signer(signer, nonce, sig_string, {from:accounts[0]});
      const signer_count = await jynx_pro_bridge.signer_count.call();
      const signers0 = await jynx_pro_bridge.signers.call(accounts[0]);
      const signers1 = await jynx_pro_bridge.signers.call(accounts[1]);
      assert.equal(signer_count, 1);
      assert.equal(signers0, true);
      assert.equal(signers1, false);
    }
    it("should fail to remove signer when user is not registered", async () => {
      try {
        await test_remove_signer(accounts[2]);
        assert.fail();
      } catch(e) {
        assert.equal(e.reason, "User is not a signer");
      }
    });
    it("should fail to remove signer with invalid signature", async () => {
      try {
        await test_remove_signer(accounts[1]);
        assert.fail();
      } catch(e) {
        assert.equal(e.reason, "Signature invalid");
      }
    });
    it("should fail to remove signer with invalid signature", async () => {
      await test_remove_signer(accounts[1], true);
    });
  });

  describe("add_asset", async () => {});

  describe("disable_asset", async () => {});

  describe("enable_asset", async () => {});

  describe("deposit_asset", async () => {});

  describe("withdraw_assets", async () => {});

  describe("add_stake", async () => {});

  describe("remove_stake", async () => {});

});
