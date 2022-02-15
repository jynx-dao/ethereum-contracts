//SPDX-License-Identifier: MIT
pragma solidity >=0.8.1;

import "./lib/ERC20.sol";
import "./JYNX.sol";

contract JynxPro_Bridge {

  event AddSigner(address signer, uint256 nonce);
  event RemoveSigner(address signer, uint256 nonce);
  event AddAsset(address asset, uint256 nonce);
  event RemoveAsset(address asset, uint256 nonce);
  event DepositAsset(address user, address asset, uint256 amount);
  event WithdrawAsset(address user, address asset, uint256 amount, uint256 nonce);
  event AddStake(address user, uint256 amount, bytes32 jynx_key);
  event RemoveStake(address user, uint256 amount, bytes32 jynx_key);

  struct Withdrawal {
    address destination;
    uint256 amount;
    address asset_address;
  }

  JYNX public jynx_token;

  mapping(address => uint256) public user_total_stake;
  mapping(address => mapping(bytes32 => uint256)) public user_stake;
  mapping(address => bool) public assets;
  mapping(address => bool) public signers;
  mapping(uint256 => bool) public used_nonces;
  mapping(bytes32 => mapping(address => bool)) has_signed;

  uint256 public signer_count = 0;
  uint16 public signing_threshold;

  constructor(
    address jynx_token_address,
    uint16 _signing_threshold
  ) {
    jynx_token = JYNX(jynx_token_address);
    signing_threshold = _signing_threshold;
    signers[msg.sender] = true;
    signer_count++;
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
    require(!signers[_signer], "User is already a signer");
    bytes memory message = abi.encode(_signer, _nonce, "add_signer");
    require(verify_signatures(_signatures, message, _nonce), "Signature invalid");
    signers[_signer] = true;
    signer_count++;
    AddSigner(_signer, _nonce);
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
    require(signers[_signer], "User is not a signer");
    bytes memory message = abi.encode(_signer, _nonce, "remove_signer");
    require(verify_signatures(_signatures, message, _nonce), "Signature invalid");
    signers[_signer] = false;
    signer_count--;
    RemoveSigner(_signer, _nonce);
  }

  /// @notice Adds an asset to the bridge
  /// @param _address the ERC20 token address
  /// @param _nonce prevent replay attacks
  /// @param _signatures signed message
  function add_asset(
    address _address,
    uint256 _nonce,
    bytes memory _signatures
  ) public {
    bytes memory message = abi.encode(_address, _nonce, "add_asset");
    require(verify_signatures(_signatures, message, _nonce), "Signature invalid");
    require(!assets[_address], "Asset already exists");
    assets[_address] = true;
    AddAsset(_address, _nonce);
  }

  /// @notice Disables an asset on the bridge
  /// @param _address the ERC20 token address
  /// @param _nonce prevent replay attacks
  /// @param _signatures signed message
  function remove_asset(
    address _address,
    uint256 _nonce,
    bytes memory _signatures
  ) public {
    bytes memory message = abi.encode(_address, _nonce, "remove_asset");
    require(verify_signatures(_signatures, message, _nonce), "Signature invalid");
    assets[_address] = false;
    RemoveAsset(_address, _nonce);
  }

  /// @notice Deposit asset to the bridge
  /// @param _address the ERC20 token address
  /// @param _amount the deposit amount
  function deposit_asset(
    address _address,
    uint256 _amount
  ) public {
    require(assets[_address], "Deposits not enabled for this asset");
    ERC20(_address).transferFrom(msg.sender, address(this), _amount);
    DepositAsset(msg.sender, _address, _amount);
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
    require(verify_signatures(_signatures, message, _nonce), "Signature invalid");
    for(uint256 i=0; i<_withdrawals.length; i++) {
      ERC20(_withdrawals[i].asset_address).transferFrom(address(this),
        _withdrawals[i].destination, _withdrawals[i].amount);
      WithdrawAsset(msg.sender, _withdrawals[i].asset_address, _withdrawals[i].amount, _nonce);
    }
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
    AddStake(msg.sender, _amount, _jynx_key);
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
    RemoveStake(msg.sender, _amount, _jynx_key);
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
}
