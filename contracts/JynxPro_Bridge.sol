//SPDX-License-Identifier: MIT
pragma solidity >=0.8.1;

import "./lib/ERC20.sol";
import "./JYNX.sol";

contract JynxPro_Bridge {

  // TODO - need to add events

  struct Withdrawal {
    address destination;
    uint256 amount;
    address asset_address;
  }

  struct Asset {
    uint256 withdraw_limit;
    bool enabled;
  }

  JYNX public jynx_token;

  mapping(address => uint256) public user_total_stake;
  mapping(address => mapping(bytes32 => uint256)) public user_stake;
  mapping(address => Asset) public assets;
  mapping(address => bool) public signers;
  mapping(uint256 => bool) public used_nonces;
  mapping(bytes32 => mapping(address => bool)) has_signed;
  
  uint256 public signer_count = 0;
  uint16 public signing_threshold = 670;

  constructor(
    address jynx_token_address
  ) {
    jynx_token = JYNX(jynx_token_address);
  }

  /// @notice Add a new signer to the bridge
  /// @param _signer the address of the signer
  /// @param _nonce prevent replay attacks
  /// @param _signatures signed message
  function add_signer(
    address _signer,
    uint256 _nonce,
    bytes memory _signatures
  ) public {
    require(!signers[_signer], "User is already a signer.");
    bytes memory message = abi.encode(_signer, _nonce, "add_signer");
    require(verify_signatures(_signatures, message, _nonce), "Signature invalid.");
    signers[_signer] = true;
    signer_count += 1;
  }

  /// @notice Remove an existing signer from the bridge
  /// @param _signer the address of the signer
  /// @param _nonce prevent replay attacks
  /// @param _signatures signed message
  function remove_signer(
    address _signer,
    uint256 _nonce,
    bytes memory _signatures
  ) public {
    require(signers[_signer], "User is not a signer.");
    bytes memory message = abi.encode(_signer, _nonce, "remove_signer");
    require(verify_signatures(_signatures, message, _nonce), "Signature invalid.");
    signers[_signer] = false;
    signer_count -= 1;
  }

  /// @notice Verifies signatures
  /// @param _signatures the concatenated signature
  /// @param _message the message that was signed
  /// @param _nonce the one-time nonce used to prevent replay attacks
  /// @return Returns true if signatures are valid
  function verify_signatures(
    bytes memory _signatures,
    bytes memory _message,
    uint256 _nonce
  ) public returns(bool) {
      require(_signatures.length % 65 == 0, "bad signature length");
      require(!used_nonces[_nonce], "nonce used");
      uint8 count = 0;
      bytes32 message_hash = keccak256(abi.encode(_message, msg.sender));
      for(uint256 i = 32; i < _signatures.length + 32; i+= 65){
          bytes32 r;
          bytes32 s;
          uint8 v;
          assembly {
              r := mload(add(_signatures, i))
              s := mload(add(_signatures, add(i, 32)))
              v := byte(0, mload(add(_signatures, add(i, 64))))
          }
          require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "mallable sig error");
          if (v < 27) v += 27;
          address addr = ecrecover(message_hash, v, r, s);
          if(signers[addr] && !has_signed[message_hash][addr]){
              count++;
          }
      }
      used_nonces[_nonce] = true;
      return ((uint256(count) * 1000) / (uint256(signer_count))) > signing_threshold;
  }

  /// @notice Adds an asset to the bridge
  /// @param _address the ERC20 token address
  /// @param _withdraw_limit instant withdrawal limit
  /// @param _nonce prevent replay attacks
  /// @param _signatures signed message
  function add_asset(
    address _address,
    uint256 _withdraw_limit,
    uint256 _nonce,
    bytes memory _signatures
  ) public {
    bytes memory message = abi.encode(_address, _withdraw_limit, _nonce, "add_asset");
    require(verify_signatures(_signatures, message, _nonce), "Signature invalid.");
    require(!assets[_address].enabled, "Asset already exists");
    assets[_address] = Asset(_withdraw_limit, true);
  }

  /// @notice Disables an asset on the bridge
  /// @param _address the ERC20 token address
  /// @param _nonce prevent replay attacks
  /// @param _signatures signed message
  function disable_asset(
    address _address,
    uint256 _nonce,
    bytes memory _signatures
  ) public {
    bytes memory message = abi.encode(_address, _nonce, "disable_asset");
    require(verify_signatures(_signatures, message, _nonce), "Signature invalid.");
    assets[_address].enabled = false;
  }

  /// @notice Enables an asset on the bridge
  /// @param _address the ERC20 token address
  /// @param _nonce prevent replay attacks
  /// @param _signatures signed message
  function enable_asset(
    address _address,
    uint256 _nonce,
    bytes memory _signatures
  ) public {
    bytes memory message = abi.encode(_address, _nonce, "enable_asset");
    require(verify_signatures(_signatures, message, _nonce), "Signature invalid.");
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

  /// @notice Stake tokens
  /// @param _amount the amount
  /// @param _jynx_key the Jynx network key
  function add_stake(
    uint256 _amount,
    bytes32 _jynx_key
  ) public {
    user_stake[msg.sender][_jynx_key] += _amount;
    user_total_stake[msg.sender] += _amount;
    jynx_token.transferFrom(msg.sender, address(this), _amount);
  }

  /// @notice Unstake tokens
  /// @param _amount the amount
  /// @param _jynx_key the Jynx network key
  function remove_stake(
    uint256 _amount,
    bytes32 _jynx_key
  ) public {
    require(user_stake[msg.sender][_jynx_key] >= _amount, "Not enough stake");
    user_stake[msg.sender][_jynx_key] -= _amount;
    user_total_stake[msg.sender] -= _amount;
    jynx_token.transferFrom(address(this), msg.sender, _amount);
  }

  /// @notice Withdraw an asset from the bridge
  /// @param _withdrawals batch of withdrawals
  /// @param _nonce prevent replay attacks
  /// @param _signatures signed message
  function withdraw_assets(
    Withdrawal[] memory _withdrawals,
    uint256 _nonce,
    bytes memory _signatures
  ) public {
    bytes memory message = abi.encode(_withdrawals, _nonce, "withdraw_assets");
    require(verify_signatures(_signatures, message, _nonce), "Signature invalid.");
    for(uint256 i=0; i<_withdrawals.length; i++) {
      ERC20(_withdrawals[i].asset_address).transferFrom(address(this),
        _withdrawals[i].destination, _withdrawals[i].amount);
    }
  }
}
