//SPDX-License-Identifier: MIT
pragma solidity >=0.8.1;

import "./lib/ERC20.sol";
import "./lib/ERC20Detailed.sol";
import "./lib/SafeMath.sol";
import "./JYNX_Distribution.sol";

contract JYNX is ERC20Detailed, ERC20 {

    using SafeMath for uint256;

    constructor (
      string memory _name,
      string memory _symbol,
      uint8 _decimals,
      uint256 total_supply_whole_tokens,
      address jynx_distribution_address
    ) ERC20Detailed(_name, _symbol, _decimals) {
      require(!JYNX_Distribution(jynx_distribution_address).initialized(), "distribution already initialized");
      uint256 to_mint = total_supply_whole_tokens * (10**uint256(_decimals));
      _totalSupply = to_mint;
      _balances[jynx_distribution_address] = to_mint;
      emit Transfer(address(0), jynx_distribution_address, to_mint);
    }
  }
