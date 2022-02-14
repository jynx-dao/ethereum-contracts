//SPDX-License-Identifier: MIT
pragma solidity >=0.8.1;

import "./lib/ERC20.sol";
import "./JYNX.sol";

contract JynxPro_Bridge {

  struct Asset {
    uint256 withdraw_limit;
    bool enabled;
  }

  struct Withdrawal {
    address destination;
    uint256 amount;
    address asset_address;
    uint256 requested_timestamp;
    bool processed;
  }

  mapping(address => mapping(uint256 => Withdrawal)) public pending_withdrawals;
  mapping(address => uint256) public pending_withdrawal_count;
  mapping(address => Asset) public assets;
  mapping(address => bool) public signers;
  mapping(uint256 => bool) public used_nonces;
  mapping(address => bool) public disable_bridge_users;
  uint256 public disable_bridge_votes = 0;
  JYNX public jynx_token;
  bool public bridge_disabled = false;
  uint8 public disable_bridge_threshold;
  address public fallback_wallet;
  uint256 signer_count = 0;
  uint256 withdraw_delay;

  constructor(
    address jynx_token_address,
    uint8 _disable_bridge_threshold,
    address _fallback_wallet,
    uint256 _withdraw_delay
  ) {
    jynx_token = JYNX(jynx_token_address);
    disable_bridge_threshold = _disable_bridge_threshold;
    fallback_wallet = _fallback_wallet;
    withdraw_delay = _withdraw_delay;
  }

  // ----------------------------------------- //

  /// @notice Toggle the disabled status of the bridge
  function toggle_disabled() internal {
    uint256 threshold = (disable_bridge_votes * 100) / jynx_token.totalSupply();
    if(threshold > disable_bridge_threshold) {
      bridge_disabled = true;
    } else {
      bridge_disabled = false;
    }
  }

  /// @notice Vote to disable the bridge
  function disable_bridge() public {
    require(jynx_token.balanceOf(msg.sender) > 0, "You do not have any JYNX.");
    require(bridge_disabled, "The bridge is already disabled.");
    disable_bridge_users[msg.sender] = true;
    disable_bridge_votes += jynx_token.balanceOf(msg.sender);
    toggle_disabled();
  }

  /// @notice Vote to enable the bridge
  function enable_bridge() public {
    require(disable_bridge_users[msg.sender], "You have not disabled the bridge.");
    disable_bridge_users[msg.sender] = false;
    disable_bridge_votes -= jynx_token.balanceOf(msg.sender);
    toggle_disabled();
  }

  /// @notice Fallback mechanism to drain the bridge
  /// @param _address the fallback address
  function drain_bridge(
    address _address
  ) public {
    require(bridge_disabled, "Bridge can only be drained when disabled.");
    uint256 balance = ERC20(_address).balanceOf(_address);
    ERC20(_address).transferFrom(address(this), fallback_wallet, balance);
  }

  /// @notice Add a new signer to the bridge
  /// @param _signer the address of the signer
  /// @param _nonce prevent replay attacks
  /// @param _signature signed message
  function add_signer(
    address _signer,
    uint256 _nonce,
    bytes32 _signature
  ) public {
    require(!signers[_signer], "User is already a signer.");
    require(verify_signautre(_signature, _nonce), "Signature invalid.");
    signers[_signer] = true;
    signer_count += 1;
  }

  /// @notice Remove an existing signer from the bridge
  /// @param _signer the address of the signer
  /// @param _nonce prevent replay attacks
  /// @param _signature signed message
  function remove_signer(
    address _signer,
    uint256 _nonce,
    bytes32 _signature
  ) public {
    require(signers[_signer], "User is not a signer.");
    require(verify_signautre(_signature, _nonce), "Signature invalid.");
    signers[_signer] = false;
    signer_count -= 1;
  }

  // ----------------------------------------- //

  /// @notice Verify a signature
  /// @param _signature signed message
  /// @param _nonce prevent replay attacks
  function verify_signautre(
    bytes32 _signature,
    uint256 _nonce
  ) internal returns(bool) {
    require(!used_nonces[_nonce], "Nonce already used.");
    // TODO - verify the signature
    used_nonces[_nonce] = true;
    return true;
  }

  /// @notice Adds an asset to the bridge
  /// @param _address the ERC20 token address
  /// @param _withdraw_limit instant withdrawal limit
  /// @param _nonce prevent replay attacks
  /// @param _signature signed message
  function add_asset(
    address _address,
    uint256 _withdraw_limit,
    uint256 _nonce,
    bytes32 _signature
  ) public {
    require(verify_signautre(_signature, _nonce), "Signature invalid.");
    require(!assets[_address].enabled, "Asset already exists");
    assets[_address] = Asset(_withdraw_limit, true);
  }

  /// @notice Disables an asset on the bridge
  /// @param _address the ERC20 token address
  /// @param _nonce prevent replay attacks
  /// @param _signature signed message
  function disable_asset(
    address _address,
    uint256 _nonce,
    bytes32 _signature
  ) public {
    require(verify_signautre(_signature, _nonce), "Signature invalid.");
    assets[_address].enabled = false;
  }

  /// @notice Enables an asset on the bridge
  /// @param _address the ERC20 token address
  /// @param _nonce prevent replay attacks
  /// @param _signature signed message
  function enable_asset(
    address _address,
    uint256 _nonce,
    bytes32 _signature
  ) public {
    require(verify_signautre(_signature, _nonce), "Signature invalid.");
    assets[_address].enabled = true;
  }

  /// @notice Deposit asset to the bridge
  /// @param _address the ERC20 token address
  /// @param _amount the deposit amount
  function deposit_asset(
    address _address,
    uint256 _amount
  ) public {
    require(assets[_address].enabled, "Deposits not enabled for this asset.");
    ERC20(_address).transferFrom(msg.sender, address(this), _amount);
  }

  /// @notice Withdraw an asset from the bridge
  /// @param _destination the destination address
  /// @param _amount the withdrawal amount
  /// @param _address the ERC20 token address
  /// @param _nonce prevent replay attacks
  /// @param _signature signed message
  function withdraw_asset(
    address _destination,
    uint256 _amount,
    address _address,
    uint256 _nonce,
    bytes32 _signature
  ) public {
    require(verify_signautre(_signature, _nonce), "Signature invalid.");
    if(_amount > assets[_address].withdraw_limit) {
      pending_withdrawals[msg.sender][pending_withdrawal_count[msg.sender]+1]
        = Withdrawal(_destination, _amount, _address, block.timestamp, false);
      // TODO - queue pending withdrawal
    } else {
      ERC20(_address).transferFrom(address(this), _destination, _amount);
    }
  }

  /// @notice Claim a pending withdrawal
  /// @param id the ID of the withdrawal
  function claim_pending_withdrawal(
    uint256 id
  ) public {
    require(!pending_withdrawals[msg.sender][id].processed, "Already claimed.");
    require(pending_withdrawals[msg.sender][id].requested_timestamp
      + withdraw_delay < block.timestamp, "Cannot claim yet.");
    address asset_address = pending_withdrawals[msg.sender][id].asset_address;
    address destination = pending_withdrawals[msg.sender][id].destination;
    uint256 amount = pending_withdrawals[msg.sender][id].amount;
    ERC20(asset_address).transferFrom(address(this), destination, amount);
    pending_withdrawals[msg.sender][id].processed = true;
  }
}
