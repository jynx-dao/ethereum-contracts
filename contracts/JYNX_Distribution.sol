//SPDX-License-Identifier: MIT
pragma solidity >=0.8.1;

import "./lib/Ownable.sol";
import "./JYNX.sol";
import "./lib/ERC20.sol";

contract JYNX_Distribution is Ownable {

  JYNX public jynx_token;
  ERC20 public dai;

  bool public initialized;
  uint256 public treasury;
  uint256 public network_pool;
  uint256 public community_pool;

  mapping(uint8 => mapping(address => uint256)) public claimed_tokens;
  mapping(uint8 => mapping(address => uint256)) public user_allocations;
  mapping(uint8 => Distribution) public distribution_events;
  uint8 distribution_count = 0;

  struct Distribution {
    uint256 total_tokens;
    uint256 tokens_sold;
    uint256 start_date;
    uint256 end_date;
    uint256 usd_rate;
    uint256 cliff_timestamp;
    uint256 vesting_duration;
    bool reclaimed;
  }

  constructor(
    address dai_address
  ) {
    initialized = false;
    dai = ERC20(dai_address);
  }

  function initialize(
    address jynx_token_address,
    uint256 _treasury,
    uint256 _network_pool,
    uint256 _community_pool
  ) public onlyOwner {
    require(!initialized, "already initialized");
    jynx_token = JYNX(jynx_token_address);
    uint256 jynx_balance = jynx_token.balanceOf(address(this));
    require(_community_pool + _treasury + _network_pool == jynx_balance,
      "must allocate all tokens");
    require(jynx_balance == jynx_token.totalSupply(),
      "total supply of JYNX must be held by contract");
    community_pool = _community_pool;
    network_pool = _network_pool;
    treasury = _treasury;
    initialized = true;
  }

  function create_token_sale(
    uint256 total_tokens,
    uint256 start_date,
    uint256 end_date,
    uint256 usd_rate,
    uint256 cliff_timestamp,
    uint256 vesting_duration
  ) public onlyOwner {
    require(end_date > start_date, "cannot end before starting");
    require(total_tokens <= community_pool, "not enough tokens left");
    distribution_events[distribution_count] = Distribution(total_tokens, 0, start_date,
      end_date, usd_rate, cliff_timestamp, vesting_duration, false);
    community_pool -= total_tokens;
    distribution_count++;
  }

  function buy_tokens(
    uint8 id,
    uint256 amount
  ) public {
    require(distribution_events[id].start_date < block.timestamp, "token sale not started");
    require(distribution_events[id].end_date > block.timestamp, "token sale ended");
    require(distribution_events[id].total_tokens - distribution_events[id].tokens_sold > 0, "sold out");
    uint256 token_amount = amount / distribution_events[id].usd_rate;
    user_allocations[id][msg.sender] += token_amount;
    dai.transferFrom(msg.sender, address(this), amount);
  }

  function reclaim_unsold_tokens(
    uint8 id
  ) public {
    require(distribution_events[id].end_date < block.timestamp, "token sale has not ended");
    require(!distribution_events[id].reclaimed, "unsold tokens already reclaimed");
    uint256 unsold_tokens = distribution_events[id].total_tokens - distribution_events[id].tokens_sold;
    community_pool += unsold_tokens;
    distribution_events[id].reclaimed = true;
  }

  function update_dai_address(
    address dai_address
  ) public onlyOwner {
    dai = ERC20(dai_address);
  }

  function redeem_erc20(
    address erc20_address,
    uint256 amount,
    address destination
  ) public onlyOwner {
    require(erc20_address != address(jynx_token), "cannot redeem JYNX");
    uint256 balance = ERC20(erc20_address).balanceOf(address(this));
    require(balance >= amount, "insufficient balance");
    ERC20(erc20_address).transfer(destination, amount);
  }

  function claim_tokens(
    uint8 id
  ) public {
    require(distribution_events[id].end_date < block.timestamp, "token sale has not ended");
    require(distribution_events[id].cliff_timestamp < block.timestamp, "cliff is not in the past");
    uint256 fully_vested_timestamp = distribution_events[id].cliff_timestamp + distribution_events[id].vesting_duration;
    uint256 available_tokens = 0;
    if(block.timestamp > fully_vested_timestamp) {
      available_tokens = user_allocations[id][msg.sender] - claimed_tokens[id][msg.sender];
    } else {
      uint256 seconds_since_cliff = block.timestamp - distribution_events[id].cliff_timestamp;
      uint256 vested_ratio = (seconds_since_cliff * 1000000) / distribution_events[id].vesting_duration;
      uint256 vested_tokens = (user_allocations[id][msg.sender] * vested_ratio) / 1000000;
      available_tokens = vested_tokens - claimed_tokens[id][msg.sender];
    }
    claimed_tokens[id][msg.sender] += available_tokens;
    jynx_token.transfer(msg.sender, available_tokens);
  }

  function get_claimed_tokens(
    uint8 id,
    address user
  ) public view returns(uint256) {
    return claimed_tokens[id][user];
  }

  function get_unclaimed_tokens(
    uint8 id,
    address user
  ) public view returns(uint256) {
    return user_allocations[id][user] - get_claimed_tokens(id, user);
  }
}
