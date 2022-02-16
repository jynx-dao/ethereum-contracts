const JynxPro_Bridge = artifacts.require("JynxPro_Bridge");
const JYNX = artifacts.require("JYNX");

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

  describe("add_asset", async () => {
    const test_add_asset = async (signer, asset) => {
      const jynx_pro_bridge = await JynxPro_Bridge.deployed();
      const nonce = new ethUtil.BN(crypto.randomBytes(32));
      let encoded_message = get_message_to_sign(
        ["address"],
        [asset],
        nonce,
        "add_asset",
        accounts[0]
      );
      const encoded_hash = ethUtil.keccak256(encoded_message);
      const signature = ethUtil.ecsign(encoded_hash, private_keys[signer]);
      const sig_string = to_signature_string(signature);
      await jynx_pro_bridge.add_asset(asset, nonce, sig_string, {from:accounts[0]});
      const asset_valid = await jynx_pro_bridge.assets.call(asset);
      assert.equal(asset_valid, true);
    }
    it("should fail to add asset with invalid signature", async () => {
      try {
        const jynx_token = await JYNX.deployed();
        await test_add_asset(accounts[1], jynx_token.address);
        assert.fail();
      } catch(e) {
        assert.equal(e.reason, "Signature invalid");
      }
    });
    it("should add asset", async () => {
      const jynx_token = await JYNX.deployed();
      await test_add_asset(accounts[0], jynx_token.address);
      await test_add_asset(accounts[0], accounts[9]);
    });
    it("should fail to add asset when already exists", async () => {
      try {
        const jynx_token = await JYNX.deployed();
        await test_add_asset(accounts[0], jynx_token.address);
        assert.fail();
      } catch(e) {
        assert.equal(e.reason, "Asset already exists");
      }
    });
  });

  describe("remove_asset", async () => {
    const test_remove_asset = async (signer) => {
      const jynx_pro_bridge = await JynxPro_Bridge.deployed();
      const jynx_token = await JYNX.deployed();
      const nonce = new ethUtil.BN(crypto.randomBytes(32));
      let encoded_message = get_message_to_sign(
        ["address"],
        [accounts[9]],
        nonce,
        "remove_asset",
        accounts[0]
      );
      const encoded_hash = ethUtil.keccak256(encoded_message);
      const signature = ethUtil.ecsign(encoded_hash, private_keys[signer]);
      const sig_string = to_signature_string(signature);
      await jynx_pro_bridge.remove_asset(accounts[9], nonce, sig_string, {from:accounts[0]});
      const asset1_valid = await jynx_pro_bridge.assets.call(accounts[9]);
      const asset2_valid = await jynx_pro_bridge.assets.call(jynx_token.address);
      assert.equal(asset1_valid, false);
      assert.equal(asset2_valid, true);
    }
    it("should fail to remove asset with invalid signature", async () => {
      try {
        await test_remove_asset(accounts[1]);
        assert.fail();
      } catch(e) {
        assert.equal(e.reason, "Signature invalid");
      }
    });
    it("should remove asset", async () => {
      await test_remove_asset(accounts[0]);
    });
  });

  describe("deposit_asset", async () => {
    const test_deposit_asset = async (asset) => {
      const jynx_pro_bridge = await JynxPro_Bridge.deployed();
      const jynx_token = await JYNX.deployed();
      if(asset === jynx_token.address) {
        await jynx_token.issue(accounts[0], web3.utils.toWei("100000"));
        await jynx_token.approve(jynx_pro_bridge.address, web3.utils.toWei("100000"));
        const asset_valid = await jynx_pro_bridge.assets.call(jynx_token.address);
        assert.equal(asset_valid, true);
      }
      await jynx_pro_bridge.deposit_asset(asset, web3.utils.toWei("10000"), {from:accounts[0]});
      const balance = await jynx_token.balanceOf(jynx_pro_bridge.address);
      assert.equal(balance, web3.utils.toWei("10000"));
    };
    it("should deposit JYNX", async () => {
      const jynx_token = await JYNX.deployed();
      await test_deposit_asset(jynx_token.address);
    });
    it("should fail to deposit when asset not registered", async () => {
      try {
        await test_deposit_asset(accounts[9]);
        assert.fail();
      } catch(e) {
        assert.equal(e.reason, "Deposits not enabled for this asset");
      }
    });
  });

  describe("withdraw_assets", async () => {});

  describe("add_stake", async () => {
    it("should add stake", async () => {
      const jynx_pro_bridge = await JynxPro_Bridge.deployed();
      const jynx_token = await JYNX.deployed();
      const jynx_key1 = "0x02d47b3068c9ff8e25eec7c83b74eb2c61073a1862f925b644b4b234c21e83dd";
      const jynx_key2 = "0x444cb478ed767da6543376f15879ffed71c93c85d95eb79f9202ecbed54a5000";
      await jynx_pro_bridge.add_stake(web3.utils.toWei("10000"), jynx_key1, {from:accounts[0]});
      await jynx_pro_bridge.add_stake(web3.utils.toWei("10000"), jynx_key2, {from:accounts[0]});
      const total_stake = await jynx_pro_bridge.user_total_stake.call(accounts[0]);
      const key1_stake = await jynx_pro_bridge.user_stake.call(accounts[0], jynx_key1);
      const key2_stake = await jynx_pro_bridge.user_stake.call(accounts[0], jynx_key2);
      assert.equal(total_stake, web3.utils.toWei("20000"));
      assert.equal(key1_stake, web3.utils.toWei("10000"));
      assert.equal(key2_stake, web3.utils.toWei("10000"));
      const balance = await jynx_token.balanceOf(jynx_pro_bridge.address);
      assert.equal(balance, web3.utils.toWei("30000"));
    });
  });

  describe("remove_stake", async () => {
    const test_remove_stake = async (amount) => {
      const jynx_pro_bridge = await JynxPro_Bridge.deployed();
      const jynx_token = await JYNX.deployed();
      const jynx_key = "0x02d47b3068c9ff8e25eec7c83b74eb2c61073a1862f925b644b4b234c21e83dd";
      await jynx_pro_bridge.remove_stake(amount, jynx_key, {from:accounts[0]});
      const total_stake = await jynx_pro_bridge.user_total_stake.call(accounts[0]);
      const key_stake = await jynx_pro_bridge.user_stake.call(accounts[0], jynx_key);
      assert.equal(total_stake, web3.utils.toWei("19000"));
      assert.equal(key_stake, web3.utils.toWei("9000"));
      const balance = await jynx_token.balanceOf(jynx_pro_bridge.address);
      assert.equal(balance, web3.utils.toWei("29000"));
    };
    it("should fail to remove stake when not registered", async () => {
      try {
        await test_remove_stake(web3.utils.toWei("50000"));
        assert.fail();
      } catch(e) {
        assert.equal(e.reason, "Not enough stake");
      }
    });
    it("should remove stake", async () => {
      await test_remove_stake(web3.utils.toWei("1000"));
    });
  });

});
