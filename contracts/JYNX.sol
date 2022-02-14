//SPDX-License-Identifier: MIT
pragma solidity >=0.8.1;

import "./lib/ERC20.sol";
import "./lib/ERC20Detailed.sol";
import "./lib/Ownable.sol";
import "./lib/SafeMath.sol";

contract JYNX is Ownable, ERC20Detailed, ERC20 {

    using SafeMath for uint256;
    constructor (
      string memory _name,
      string memory _symbol,
      uint8 _decimals,
      uint256 total_supply_whole_tokens) ERC20Detailed(_name, _symbol, _decimals) {
        uint256 to_mint = total_supply_whole_tokens * (10**uint256(_decimals));
        _totalSupply = to_mint;
        _balances[address(this)] = to_mint;
        emit Transfer(address(0), address(this), to_mint);
    }

    function issue(address account, uint256 value) public onlyOwner {
        _transfer(address(this), account, value);
    }
  }
