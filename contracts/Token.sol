pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //  
  // ------------------------------------------ //

  mapping (address => mapping (address => uint256)) private _allowances;
  mapping (address => uint256) private _holderIndexes;
  mapping (address => uint256) private _withdrawableDividends;
  mapping (address => uint256) private _dividendPerTokenPaid;
  address[] private _holders;
  uint256 private _dividendPerToken;
  uint256 private constant _DIVIDEND_PRECISION = 10 ** 18;

  // IERC20

  function allowance(address owner, address spender) external view override returns (uint256) {
    return _allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    _transfer(msg.sender, to, value);
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    _allowances[msg.sender][spender] = value;
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);
    _transfer(from, to, value);
    return true;
  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0, "No Mint Amount Assigned.");

    _settleDividend(msg.sender);

    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);
    _updateHolder(msg.sender);
  }

  function burn(address payable dest) external override {
    uint256 value = balanceOf[msg.sender];
    require(value > 0, "Zero Balance To Burn.");

    _settleDividend(msg.sender);

    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(value);
    _updateHolder(msg.sender);

    (bool success, ) = dest.call{value: value}("");
    require(success, "Burn Reverted.");
  }

  // IDividends

  function getNumTokenHolders() external view override returns (uint256) {
    return _holders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    if (index == 0 || index > _holders.length) {
      return address(0);
    }

    return _holders[index - 1];
  }

  // Lazy Calculation Of Dividend To Save Gas
  function recordDividend() external payable override {
    require(msg.value > 0, "Zero Amount Assigned.");
    require(totalSupply > 0, "Zero TotalSupply To Pay.");

    _dividendPerToken = _dividendPerToken.add(msg.value.mul(_DIVIDEND_PRECISION).div(totalSupply));
  }

  // Here To Calculate Withdrawable Dividend
  function calculateWithdrawableDividend(address payee) public view returns (uint256) {
    uint256 unpaidDividendPerToken = _dividendPerToken.sub(_dividendPerTokenPaid[payee]);
    uint256 newDividend = balanceOf[payee].mul(unpaidDividendPerToken).div(_DIVIDEND_PRECISION);

    return _withdrawableDividends[payee].add(newDividend);
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return calculateWithdrawableDividend(payee);
  }

  // Only Calculate Withdrawable Dividend When User Withdraw
  function withdrawDividend(address payable dest) external override {
    uint256 value = calculateWithdrawableDividend(msg.sender);
    require(value > 0, "No Dividend To Withdraw.");

    _withdrawableDividends[msg.sender] = 0;
    _dividendPerTokenPaid[msg.sender] = _dividendPerToken;

    (bool success, ) = dest.call{value: value}("");
    require(success, "Dividend Withdraw Reverted.");
  }

  function _transfer(address from, address to, uint256 value) private {
    _settleDividend(from);
    _settleDividend(to);

    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);

    _updateHolder(from);
    _updateHolder(to);
  }

  function _settleDividend(address payee) private {
    _withdrawableDividends[payee] = calculateWithdrawableDividend(payee);
    _dividendPerTokenPaid[payee] = _dividendPerToken;
  }

  function _updateHolder(address holder) private {
    bool isHolder = _holderIndexes[holder] != 0;

    if (balanceOf[holder] > 0 && !isHolder) {
      _holders.push(holder);
      _holderIndexes[holder] = _holders.length;
      return;
    }

    if (balanceOf[holder] == 0 && isHolder) {
      uint256 holderIndex = _holderIndexes[holder] - 1;
      uint256 lastIndex = _holders.length - 1;

      if (holderIndex != lastIndex) {
        address lastHolder = _holders[lastIndex];
        _holders[holderIndex] = lastHolder;
        _holderIndexes[lastHolder] = holderIndex + 1;
      }

      _holders.pop();
      delete _holderIndexes[holder];
    }
  }
}