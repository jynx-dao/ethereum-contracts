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

  mapping(uint8 => mapping(address => uint256)) public user_allocations;
  mapping(uint8 => TokenSale) public token_sales;
  uint8 token_sale_count = 0;

  struct TokenSale {
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
    token_sales[token_sale_count] = TokenSale(total_tokens, 0, start_date,
      end_date, usd_rate, cliff_timestamp, vesting_duration, false);
    community_pool -= total_tokens;
    token_sale_count++;
  }

  function buy_tokens(
    uint8 id,
    uint256 amount
  ) public {
    require(token_sales[id].start_date < block.timestamp, "token sale not started");
    require(token_sales[id].end_date > block.timestamp, "token sale ended");
    require(token_sales[id].total_tokens - token_sales[id].tokens_sold > 0, "sold out");
    dai.transferFrom(msg.sender, address(this), amount);
    uint256 token_amount = amount / token_sales[id].usd_rate;
    user_allocations[id][msg.sender] += token_amount;
  }

  function reclaim_unsold_tokens(
    uint8 id
  ) public {
    require(token_sales[id].end_date < block.timestamp, "token sale has not ended");
    require(!token_sales[id].reclaimed, "unsold tokens already reclaimed");
    uint256 unsold_tokens = token_sales[id].total_tokens - token_sales[id].tokens_sold;
    community_pool += unsold_tokens;
    token_sales[id].reclaimed = true;
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
}
