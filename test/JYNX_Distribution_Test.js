const JYNX_Distribution = artifacts.require("JYNX_Distribution");
const JYNX = artifacts.require("JYNX");
const DAI = artifacts.require("DAI");
const JynxPro_Bridge = artifacts.require("JynxPro_Bridge");

const timeMachine = require('ganache-time-traveler');

contract("JYNX_Distribution", (accounts) => {

  const test_buy_tokens = async (id, amount) => {
    const jynx_distribution = await JYNX_Distribution.deployed();
    const dai = await DAI.deployed();
    amount = web3.utils.toWei(String(amount));
    await dai.issue(accounts[0], amount);
    await dai.approve(jynx_distribution.address, amount);
    await jynx_distribution.buy_tokens(id, amount);
    const allow = await jynx_distribution.user_allocations.call(id, accounts[0]);
    assert.equal(web3.utils.fromWei(allow), web3.utils.fromWei(amount));
  };

  const test_create_distribution = async (diff, amount, pool, dist_count) => {
    const jynx_distribution = await JYNX_Distribution.deployed();
    const ts = (await web3.eth.getBlock()).timestamp;
    await jynx_distribution.create_distribution(
      web3.utils.toWei(String(amount)),
      String(ts+60),
      String(ts+120+diff),
      String(1),
      String(ts+300),
      String(600)
    );
    const count = await jynx_distribution.distribution_count();
    assert.equal(count, dist_count);
    assert.equal(pool, web3.utils.fromWei(await jynx_distribution.community_pool.call()));
  };

  describe("initialize", async () => {
    const test_initialize = async (diff) => {
      const jynx_distribution = await JYNX_Distribution.deployed();
      const jynx_pro_bridge = await JynxPro_Bridge.deployed();
      const jynx_token = await JYNX.deployed();
      await jynx_distribution.initialize(
        jynx_token.address,
        jynx_pro_bridge.address,
        web3.utils.toWei("199980000"),
        web3.utils.toWei("499950000"),
        web3.utils.toWei(String(299970000 - diff))
      );
      const initialized = await jynx_distribution.initialized.call();
      assert.equal(initialized, true);
    };
    it("should fail to initialize with invalid quantities", async () => {
      try {
        await test_initialize(1000);
        assert.fail();
      } catch(e) {
        assert.equal(e.reason, "must allocate all tokens");
      }
    });
    it("should initialize contract", async () => {
      await test_initialize(0);
    });
    it("should fail to initialize with already initialized", async () => {
      try {
        await test_initialize(0);
        assert.fail();
      } catch(e) {
        assert.equal(e.reason, "already initialized");
      }
    });
  });

  describe("create_distribution", async () => {
    it("should fail to create distribution when ends before beginning", async () => {
      try {
        await test_create_distribution(-100, 100000000);
        assert.fail();
      } catch(e) {
        assert.equal(e.reason, "cannot end before starting")
      }
    });
    it("should fail to create distribution when exceeds community bucket", async () => {
      try {
        await test_create_distribution(0, 500000000);
        assert.fail();
      } catch(e) {
        assert.equal(e.reason, "not enough tokens left")
      }
    });
    it("should create distribution", async () => {
      await test_create_distribution(0, 100000000, 199970000, 1);
    });
  });

  describe("buy_tokens", async () => {
    it("should fail to buy tokens before distribution starts", async () => {
      try {
        await test_buy_tokens(0, 1000);
        assert.fail();
      } catch(e) {
        assert.equal(e.reason, "distribution not started");
      }
    });
    it("should buy tokens", async () => {
      const snapshot = (await timeMachine.takeSnapshot())['result'];
      await timeMachine.advanceTimeAndBlock(80);
      await test_buy_tokens(0, 100000000);
      await timeMachine.revertToSnapshot(snapshot);
    });
    it("should fail to buy tokens when sold out", async () => {
      const snapshot = (await timeMachine.takeSnapshot())['result'];
      await timeMachine.advanceTimeAndBlock(80);
      try {
        await test_buy_tokens(0, 100000000);
        await test_buy_tokens(0, 100);
        assert.fail();
      } catch(e) {
        assert.equal(e.reason, "sold out");
      }
      await timeMachine.revertToSnapshot(snapshot);
    });
    it("should fail to buy tokens after distribution ends", async () => {
      const snapshot = (await timeMachine.takeSnapshot())['result'];
      await timeMachine.advanceTimeAndBlock(140);
      try {
        await test_buy_tokens(0, 1000);
        assert.fail();
      } catch(e) {
        assert.equal(e.reason, "distribution ended");
      }
      await timeMachine.revertToSnapshot(snapshot);
    });
  });

  describe("reclaim_unsold_tokens", async () => {
    const test_reclaim_unsold_tokens = async (id, pool) => {
      const jynx_distribution = await JYNX_Distribution.deployed();
      await jynx_distribution.reclaim_unsold_tokens(id);
      assert.equal(pool, web3.utils.fromWei(await jynx_distribution.community_pool.call()));
    };
    it("should reclaim unsold tokens", async () => {
      const snapshot = (await timeMachine.takeSnapshot())['result'];
      await test_create_distribution(0, 100000000, 99970000, 2);
      await timeMachine.advanceTimeAndBlock(60);
      await test_buy_tokens(1, 1000);
      await timeMachine.advanceTimeAndBlock(120);
      await test_reclaim_unsold_tokens(1, 199969000);
      await timeMachine.revertToSnapshot(snapshot);
    });
    it("should not reclaim unsold tokens before distribution ends", async () => {
      const snapshot = (await timeMachine.takeSnapshot())['result'];
      await test_create_distribution(0, 100000000, 99970000, 2);
      await timeMachine.advanceTimeAndBlock(60);
      await test_buy_tokens(1, 1000);
      try {
        await test_reclaim_unsold_tokens(1, 199969000);
        assert.fail();
      } catch(e) {
        assert.equal(e.reason, "distribution has not ended");
      }
      await timeMachine.revertToSnapshot(snapshot);
    });
    it("should not reclaim unsold tokens when already reclaimed", async () => {
      const snapshot = (await timeMachine.takeSnapshot())['result'];
      await test_create_distribution(0, 100000000, 99970000, 2);
      await timeMachine.advanceTimeAndBlock(60);
      await test_buy_tokens(1, 1000);
      await timeMachine.advanceTimeAndBlock(120);
      await test_reclaim_unsold_tokens(1, 199969000);
      try {
        await test_reclaim_unsold_tokens(1, 199969000);
        assert.fail();
      } catch(e) {
        assert.equal(e.reason, "unsold tokens already reclaimed");
      }
      await timeMachine.revertToSnapshot(snapshot);
    });
  });

  describe("update_dai_address", async () => {
    it("should update DAI address", async () => {
      const dai = await DAI.deployed();
      const jynx_distribution = await JYNX_Distribution.deployed();
      await jynx_distribution.update_dai_address(dai.address);
    });
  });

  describe("redeem_erc20", async () => {
    it("should redeem erc20", async () => {
      const dai = await DAI.deployed();
      const jynx = await JYNX.deployed();
      const jynx_distribution = await JYNX_Distribution.deployed();
      await test_create_distribution(0, 100000000, 99970000, 2);
      await timeMachine.advanceTimeAndBlock(60);
      await test_buy_tokens(1, 1000);
      let balance = await dai.balanceOf(jynx_distribution.address);
      assert.equal(web3.utils.fromWei(balance), 1000);
      balance = await dai.balanceOf(accounts[0]);
      assert.equal(web3.utils.fromWei(balance), 1000);
      await jynx_distribution.redeem_erc20(dai.address, balance, accounts[0]);
      balance = await dai.balanceOf(accounts[0]);
      assert.equal(web3.utils.fromWei(balance), 2000);
    });
    it("should not redeem erc20 if JYNX", async () => {
      try {
        const jynx = await JYNX.deployed();
        const jynx_distribution = await JYNX_Distribution.deployed();
        await jynx_distribution.redeem_erc20(jynx.address, web3.utils.toWei("1000"), accounts[0]);
        assert.fail();
      } catch(e) {
        assert.equal(e.reason, "cannot redeem JYNX");
      }
    });
    it("should not redeem erc20 with insufficient balance", async () => {
      try {
        const dai = await DAI.deployed();
        const jynx_distribution = await JYNX_Distribution.deployed();
        await jynx_distribution.redeem_erc20(dai.address, web3.utils.toWei("1000"), accounts[0]);
        assert.fail();
      } catch(e) {
        assert.equal(e.reason, "insufficient balance");
      }
    });
  });

  describe("claim_tokens_for_distribution", async () => {
    it("should...", async () => {});
  });

  describe("claim_treasury_tokens", async () => {
    it("should...", async () => {});
  });

  describe("claim_network_tokens", async () => {
    it("should...", async () => {});
  });

});
