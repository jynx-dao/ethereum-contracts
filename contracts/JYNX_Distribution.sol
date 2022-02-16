//SPDX-License-Identifier: MIT
pragma solidity >=0.8.1;

import "./lib/Ownable.sol";
import "./JYNX.sol";
import "./JynxPro_Bridge.sol";
import "./lib/ERC20.sol";

contract JYNX_Distribution is Ownable {

  JynxPro_Bridge public jynx_pro_bridge;
  JYNX public jynx_token;
  ERC20 public dai;

  bool public initialized;
  uint256 public treasury;
  uint256 public network_pool;
  uint256 public community_pool;
  uint256 public treasury_claimed = 0;
  uint256 public network_pool_claimed = 0;

  mapping(uint8 => mapping(address => uint256)) public claimed_tokens;
  mapping(uint8 => mapping(address => uint256)) public user_allocations;
  mapping(uint8 => Distribution) public distribution_events;
  uint8 public distribution_count = 0;

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

  /// @notice check if contract is initialized
  modifier onlyInitialized() {
      require(initialized, "contract must be initialized");
      _;
  }

  /// @notice Deploys the distribution contract
  /// @param dai_address DAI contract address
  constructor(
    address dai_address
  ) {
    initialized = false;
    dai = ERC20(dai_address);
  }

  /// @notice Initialize the contract
  /// @param jynx_token_address the JYNX token contract
  /// @param jynx_bridge_address the Jynx network bridge
  /// @param _treasury treasury tokens
  /// @param _network_pool tokens managed by the Jynx network
  /// @param _community_pool tokens available for community distribution
  function initialize(
    address jynx_token_address,
    address jynx_bridge_address,
    uint256 _treasury,
    uint256 _network_pool,
    uint256 _community_pool
  ) public onlyOwner {
    require(!initialized, "already initialized");
    jynx_pro_bridge = JynxPro_Bridge(jynx_bridge_address);
    jynx_token = JYNX(jynx_token_address);
    uint256 jynx_balance = jynx_token.balanceOf(address(this));
    require(_community_pool + _treasury + _network_pool == jynx_balance,
      "must allocate all tokens");
    community_pool = _community_pool;
    network_pool = _network_pool;
    treasury = _treasury;
    initialized = true;
  }

  /// @notice Create a token distribution event
  /// @param total_tokens tokens available to purchase
  /// @param start_date opening timestamp
  /// @param end_date closing timestamp
  /// @param usd_rate the USD price of JYNX
  /// @param cliff_timestamp the cliff applied to vesting
  /// @param vesting_duration linear vesting duration
  function create_distribution(
    uint256 total_tokens,
    uint256 start_date,
    uint256 end_date,
    uint256 usd_rate,
    uint256 cliff_timestamp,
    uint256 vesting_duration
  ) public onlyOwner onlyInitialized {
    require(end_date > start_date, "cannot end before starting");
    require(total_tokens <= community_pool, "not enough tokens left");
    distribution_events[distribution_count] = Distribution(total_tokens, 0, start_date,
      end_date, usd_rate, cliff_timestamp, vesting_duration, false);
    community_pool -= total_tokens;
    distribution_count++;
  }

  /// @notice Buy tokens from a distribution event
  /// @param id the distribution identifier
  /// @param amount DAI to spend
  function buy_tokens(
    uint8 id,
    uint256 amount
  ) public onlyInitialized {
    require(distribution_events[id].start_date < block.timestamp, "distribution not started");
    require(distribution_events[id].end_date > block.timestamp, "distribution ended");
    require(distribution_events[id].total_tokens - distribution_events[id].tokens_sold > 0, "sold out");
    uint256 token_amount = amount / distribution_events[id].usd_rate;
    user_allocations[id][msg.sender] += token_amount;
    distribution_events[id].tokens_sold += token_amount;
    dai.transferFrom(msg.sender, address(this), amount);
  }

  /// @notice Reclaim unsold tokens in a distribution event (send them back to community bucket)
  /// @param id the distribution identifier
  function reclaim_unsold_tokens(
    uint8 id
  ) public onlyInitialized {
    require(distribution_events[id].end_date < block.timestamp, "distribution has not ended");
    require(!distribution_events[id].reclaimed, "unsold tokens already reclaimed");
    uint256 unsold_tokens = distribution_events[id].total_tokens - distribution_events[id].tokens_sold;
    community_pool += unsold_tokens;
    distribution_events[id].reclaimed = true;
  }

  /// @notice Update the contract address for DAI
  /// @param dai_address DAI contract address
  function update_dai_address(
    address dai_address
  ) public onlyOwner onlyInitialized {
    dai = ERC20(dai_address);
  }

  /// @notice Allows the owner to claim any ERC20 tokens except JYNX
  /// @param erc20_address contract addresses
  /// @param amount amount to claim
  /// @param destination recipient wallet
  function redeem_erc20(
    address erc20_address,
    uint256 amount,
    address destination
  ) public onlyOwner onlyInitialized {
    require(erc20_address != address(jynx_token), "cannot redeem JYNX");
    uint256 balance = ERC20(erc20_address).balanceOf(address(this));
    require(balance >= amount, "insufficient balance");
    ERC20(erc20_address).transfer(destination, amount);
  }

  /// @notice Calculates the tokens available for redemption for given user and distribution
  /// @param id the distribution identifier
  /// @param user the user address
  /// @return tokens available for redemption
  function get_available_tokens_for_distribution(
    uint8 id,
    address user
  ) public view returns(uint256) {
    if(distribution_events[id].end_date > block.timestamp) {
      return 0;
    }
    if(distribution_events[id].cliff_timestamp > block.timestamp) {
      return 0;
    }
    uint256 cliff = distribution_events[id].cliff_timestamp;
    uint256 duration = distribution_events[id].vesting_duration;
    uint256 vesting_end = cliff + duration;
    uint256 available_tokens = user_allocations[id][user] - claimed_tokens[id][user];
    if(block.timestamp < vesting_end) {
      uint256 seconds_since_cliff = block.timestamp - cliff;
      uint256 vested_ratio = (seconds_since_cliff * 1000000) / duration;
      uint256 vested_tokens = (user_allocations[id][user] * vested_ratio) / 1000000;
      available_tokens = vested_tokens - claimed_tokens[id][user];
    }
    return available_tokens;
  }

  /// @notice Calculates the tokens available for redemption from a 5-year vesting schedule
  /// @param total_balance the total tokens in the schedule
  /// @param claimed_balance the tokens already claimed
  /// @return tokens available for redemption
  function get_available_tokens_5y_vesting(
    uint256 total_balance,
    uint256 claimed_balance
  ) public view returns (uint256) {
    if(distribution_count == 0) {
      return 0;
    }
    if(distribution_events[0].end_date > block.timestamp) {
      return 0;
    }
    uint256 cliff = distribution_events[0].end_date + (86400 * 180);
    uint256 duration = 86400 * 365 * 5;
    uint256 vesting_end = cliff + duration;
    uint256 available_tokens = total_balance - claimed_balance;
    if(block.timestamp < vesting_end) {
      uint256 seconds_since_cliff = block.timestamp - cliff;
      uint256 vested_ratio = (seconds_since_cliff * 1000000) / duration;
      uint256 vested_tokens = (total_balance * vested_ratio) / 1000000;
      available_tokens = vested_tokens - claimed_balance;
    }
    return available_tokens;
  }

  /// @notice Claims tokens from a distribution event
  /// @param id the distribution identifier
  function claim_tokens_for_distribution(
    uint8 id
  ) public onlyInitialized {
    uint256 available_tokens = get_available_tokens_for_distribution(id, msg.sender);
    claimed_tokens[id][msg.sender] += available_tokens;
    jynx_token.transfer(msg.sender, available_tokens);
  }

  /// @notice Allows the owner to claim vested treasury tokens
  function claim_treasury_tokens() onlyOwner public onlyInitialized {
    uint256 available_tokens = get_available_tokens_5y_vesting(treasury, treasury_claimed);
    treasury_claimed += available_tokens;
    jynx_token.transfer(owner(), available_tokens);
  }

  /// @notice Allows the Jynx network to claim vested network tokens
  function claim_network_tokens() public onlyInitialized {
    require(msg.sender == address(jynx_pro_bridge), "only bridge can claim network tokens");
    uint256 available_tokens = get_available_tokens_5y_vesting(network_pool, network_pool_claimed);
    network_pool_claimed += available_tokens;
    jynx_token.transfer(address(jynx_pro_bridge), available_tokens);
  }
}
