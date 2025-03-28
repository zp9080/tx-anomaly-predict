pragma solidity ^0.7.4;

import "./utils/SafeMath.sol";
import "./utils/Ownable.sol";
import "./ERC20/ERC20.sol";

/**
 * @title COVER token contract
 * @author crypto-pumpkin@github
 */
contract COVER is Ownable, ERC20 {
  using SafeMath for uint256;

  bool private isReleased;
  address public blacksmith; // mining contract
  address public migrator; // migration contract
  uint256 public constant START_TIME = 1605830400; // 11/20/2020 12am UTC

  constructor () ERC20("Cover Protocol", "COVER") {
    // mint 1 token to create pool2
    _mint(0x2f80E5163A7A774038753593010173322eA6f9fe, 1e18);
  }

  function mint(address _account, uint256 _amount) public {
    require(isReleased, "$COVER: not released");
    require(msg.sender == migrator || msg.sender == blacksmith, "$COVER: caller not migrator or Blacksmith");

    _mint(_account, _amount);
  }

  function setBlacksmith(address _newBlacksmith) external returns (bool) {
    require(msg.sender == blacksmith, "$COVER: caller not blacksmith");

    blacksmith = _newBlacksmith;
    return true;
  }

  function setMigrator(address _newMigrator) external returns (bool) {
    require(msg.sender == migrator, "$COVER: caller not migrator");

    migrator = _newMigrator;
    return true;
  }

  /// @notice called once and only by owner
  function release(address _treasury, address _vestor, address _blacksmith, address _migrator) external onlyOwner {
    require(block.timestamp >= START_TIME, "$COVER: not started");
    require(isReleased == false, "$COVER: already released");

    isReleased = true;

    blacksmith = _blacksmith;
    migrator = _migrator;
    _mint(_treasury, 950e18);
    _mint(_vestor, 10800e18);
  }
}
pragma solidity ^0.7.4;

import "./ERC20/IERC20.sol";
import "./ERC20/SafeERC20.sol";
import "./utils/SafeMath.sol";
import "./utils/Ownable.sol";
import "./utils/ReentrancyGuard.sol";
import "./interfaces/ICOVER.sol";
import "./interfaces/IBlacksmith.sol";

/**
 * @title COVER token shield mining contract
 * @author crypto-pumpkin@github
 */
contract Blacksmith is Ownable, IBlacksmith, ReentrancyGuard {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  ICOVER public cover;
  address public governance;
  address public treasury;
  /// @notice Total 17k COVER in 1st 6 mths. TODO: update to 246e18 after 6 months from 1605830400 (11/20/2020 12am UTC)
  uint256 public weeklyTotal = 654e18;
  uint256 public totalWeight; // total weight for all pools
  uint256 public constant START_TIME = 1605830400; // 11/20/2020 12am UTC
  uint256 public constant WEEK = 7 days;
  uint256 private constant CAL_MULTIPLIER = 1e12; // help calculate rewards/bonus PerToken only. 1e12 will allow meaningful $1 deposit in a $1bn pool
  address[] public poolList;
  mapping(address => Pool) public pools; // lpToken => Pool
  mapping(address => BonusToken) public bonusTokens; // lpToken => BonusToken
  // bonusToken => 1 (allowed), allow anyone to use the bonus token to run a bonus program on any pool
  mapping(address => uint8) public allowBonusTokens;
  // lpToken => Miner address => Miner data
  mapping(address => mapping(address => Miner)) public miners;

  modifier onlyGovernance() {
    require(msg.sender == governance, "Blacksmith: caller not governance");
    _;
  }

  constructor (address _coverAddress, address _governance, address _treasury) {
    cover = ICOVER(_coverAddress);
    governance = _governance;
    treasury = _treasury;
  }

  function getPoolList() external view override returns (address[] memory) {
    return poolList;
  }

  function viewMined(address _lpToken, address _miner)
   external view override returns (uint256 _minedCOVER, uint256 _minedBonus)
  {
    Pool memory pool = pools[_lpToken];
    Miner memory miner = miners[_lpToken][_miner];
    uint256 lpTotal = IERC20(_lpToken).balanceOf(address(this));
    if (miner.amount > 0 && lpTotal > 0) {
      uint256 coverRewards = _calculateCoverRewardsForPeriod(pool);
      uint256 accRewardsPerToken = pool.accRewardsPerToken.add(coverRewards.div(lpTotal));
      _minedCOVER = miner.amount.mul(accRewardsPerToken).div(CAL_MULTIPLIER).sub(miner.rewardWriteoff);

      BonusToken memory bonusToken = bonusTokens[_lpToken];
      if (bonusToken.startTime < block.timestamp && bonusToken.totalBonus > 0) {
        uint256 bonus = _calculateBonusForPeriod(bonusToken);
        uint256 accBonusPerToken = bonusToken.accBonusPerToken.add(bonus.div(lpTotal));
        _minedBonus = miner.amount.mul(accBonusPerToken).div(CAL_MULTIPLIER).sub(miner.bonusWriteoff);
      }
    }
    return (_minedCOVER, _minedBonus);
  }

  /// @notice update pool's rewards & bonus per staked token till current block timestamp
  function updatePool(address _lpToken) public override {
    Pool storage pool = pools[_lpToken];
    if (block.timestamp <= pool.lastUpdatedAt) return;
    uint256 lpTotal = IERC20(_lpToken).balanceOf(address(this));
    if (lpTotal == 0) {
      pool.lastUpdatedAt = block.timestamp;
      return;
    }
    // update COVER rewards for pool
    uint256 coverRewards = _calculateCoverRewardsForPeriod(pool);
    pool.accRewardsPerToken = pool.accRewardsPerToken.add(coverRewards.div(lpTotal));
    pool.lastUpdatedAt = block.timestamp;
    // update bonus token rewards if exist for pool
    BonusToken storage bonusToken = bonusTokens[_lpToken];
    if (bonusToken.lastUpdatedAt < bonusToken.endTime && bonusToken.startTime < block.timestamp) {
      uint256 bonus = _calculateBonusForPeriod(bonusToken);
      bonusToken.accBonusPerToken = bonusToken.accBonusPerToken.add(bonus.div(lpTotal));
      bonusToken.lastUpdatedAt = block.timestamp <= bonusToken.endTime ? block.timestamp : bonusToken.endTime;
    }
  }

  function claimRewards(address _lpToken) public override {
    updatePool(_lpToken);

    Pool memory pool = pools[_lpToken];
    Miner storage miner = miners[_lpToken][msg.sender];
    BonusToken memory bonusToken = bonusTokens[_lpToken];

    _claimCoverRewards(pool, miner);
    _claimBonus(bonusToken, miner);
    // update writeoff to match current acc rewards & bonus per token
    miner.rewardWriteoff = miner.amount.mul(pool.accRewardsPerToken).div(CAL_MULTIPLIER);
    miner.bonusWriteoff = miner.amount.mul(bonusToken.accBonusPerToken).div(CAL_MULTIPLIER);
  }

  function claimRewardsForPools(address[] calldata _lpTokens) external override {
    for (uint256 i = 0; i < _lpTokens.length; i++) {
      claimRewards(_lpTokens[i]);
    }
  }

  function deposit(address _lpToken, uint256 _amount) external override {
    require(block.timestamp >= START_TIME , "Blacksmith: not started");
    require(_amount > 0, "Blacksmith: amount is 0");
    Pool memory pool = pools[_lpToken];
    require(pool.lastUpdatedAt > 0, "Blacksmith: pool does not exists");
    require(IERC20(_lpToken).balanceOf(msg.sender) >= _amount, "Blacksmith: insufficient balance");
    updatePool(_lpToken);

    Miner storage miner = miners[_lpToken][msg.sender];
    BonusToken memory bonusToken = bonusTokens[_lpToken];
    _claimCoverRewards(pool, miner);
    _claimBonus(bonusToken, miner);

    miner.amount = miner.amount.add(_amount);
    // update writeoff to match current acc rewards/bonus per token
    miner.rewardWriteoff = miner.amount.mul(pool.accRewardsPerToken).div(CAL_MULTIPLIER);
    miner.bonusWriteoff = miner.amount.mul(bonusToken.accBonusPerToken).div(CAL_MULTIPLIER);

    IERC20(_lpToken).safeTransferFrom(msg.sender, address(this), _amount);
    emit Deposit(msg.sender, _lpToken, _amount);
  }

  function withdraw(address _lpToken, uint256 _amount) external override {
    require(_amount > 0, "Blacksmith: amount is 0");
    Miner storage miner = miners[_lpToken][msg.sender];
    require(miner.amount >= _amount, "Blacksmith: insufficient balance");
    updatePool(_lpToken);

    Pool memory pool = pools[_lpToken];
    BonusToken memory bonusToken = bonusTokens[_lpToken];
    _claimCoverRewards(pool, miner);
    _claimBonus(bonusToken, miner);

    miner.amount = miner.amount.sub(_amount);
    // update writeoff to match current acc rewards/bonus per token
    miner.rewardWriteoff = miner.amount.mul(pool.accRewardsPerToken).div(CAL_MULTIPLIER);
    miner.bonusWriteoff = miner.amount.mul(bonusToken.accBonusPerToken).div(CAL_MULTIPLIER);

    _safeTransfer(_lpToken, _amount);
    emit Withdraw(msg.sender, _lpToken, _amount);
  }

  /// @notice withdraw all without rewards
  function emergencyWithdraw(address _lpToken) external override {
    Miner storage miner = miners[_lpToken][msg.sender];
    uint256 amount = miner.amount;
    require(miner.amount > 0, "Blacksmith: insufficient balance");
    miner.amount = 0;
    miner.rewardWriteoff = 0;
    _safeTransfer(_lpToken, amount);
    emit Withdraw(msg.sender, _lpToken, amount);
  }

  /// @notice update pool weights
  function updatePoolWeights(address[] calldata _lpTokens, uint256[] calldata _weights) public override onlyGovernance {
    for (uint256 i = 0; i < _lpTokens.length; i++) {
      Pool storage pool = pools[_lpTokens[i]];
      if (pool.lastUpdatedAt > 0) {
        totalWeight = totalWeight.add(_weights[i]).sub(pool.weight);
        pool.weight = _weights[i];
      }
    }
  }

  /// @notice add a new pool for shield mining
  function addPool(address _lpToken, uint256 _weight) public override onlyOwner {
    Pool memory pool = pools[_lpToken];
    require(pool.lastUpdatedAt == 0, "Blacksmith: pool exists");
    pools[_lpToken] = Pool({
      weight: _weight,
      accRewardsPerToken: 0,
      lastUpdatedAt: block.timestamp
    });
    totalWeight = totalWeight.add(_weight);
    poolList.push(_lpToken);
  }

  /// @notice add new pools for shield mining
  function addPools(address[] calldata _lpTokens, uint256[] calldata _weights) external override onlyOwner {
    require(_lpTokens.length == _weights.length, "Blacksmith: size don't match");
    for (uint256 i = 0; i < _lpTokens.length; i++) {
     addPool(_lpTokens[i], _weights[i]);
    }
  }

  /// @notice only statusCode 1 will enable the bonusToken to allow partners to set their program
  function updateBonusTokenStatus(address _bonusToken, uint8 _status) external override onlyOwner {
    require(_status != 0, "Blacksmith: status cannot be 0");
    require(pools[_bonusToken].lastUpdatedAt == 0, "Blacksmith: lpToken is not allowed");
    allowBonusTokens[_bonusToken] = _status;
  }

  /// @notice always assign the same startTime and endTime for both CLAIM and NOCLAIM pool, one bonusToken can be used for only one set of CLAIM and NOCLAIM pools
  function addBonusToken(
    address _lpToken,
    address _bonusToken,
    uint256 _startTime,
    uint256 _endTime,
    uint256 _totalBonus
  ) external override {
    IERC20 bonusToken = IERC20(_bonusToken);
    require(pools[_lpToken].lastUpdatedAt != 0, "Blacksmith: pool does NOT exist");
    require(allowBonusTokens[_bonusToken] == 1, "Blacksmith: bonusToken not allowed");

    BonusToken memory currentBonusToken = bonusTokens[_lpToken];
    if (currentBonusToken.totalBonus != 0) {
      require(currentBonusToken.endTime.add(WEEK) < block.timestamp, "Blacksmith: last bonus period hasn't ended");
      require(IERC20(currentBonusToken.addr).balanceOf(address(this)) == 0, "Blacksmith: last bonus not all claimed");
    }

    require(_startTime >= block.timestamp && _endTime > _startTime, "Blacksmith: messed up timeline");
    require(_totalBonus > 0 && bonusToken.balanceOf(msg.sender) >= _totalBonus, "Blacksmith: incorrect total rewards");

    uint256 balanceBefore = bonusToken.balanceOf(address(this));
    bonusToken.safeTransferFrom(msg.sender, address(this), _totalBonus);
    uint256 balanceAfter = bonusToken.balanceOf(address(this));
    require(balanceAfter > balanceBefore, "Blacksmith: incorrect total rewards");

    bonusTokens[_lpToken] = BonusToken({
      addr: _bonusToken,
      startTime: _startTime,
      endTime: _endTime,
      totalBonus: balanceAfter.sub(balanceBefore),
      accBonusPerToken: 0,
      lastUpdatedAt: _startTime
    });
  }

  /// @notice collect dust to treasury
  function collectDust(address _token) external override {
    Pool memory pool = pools[_token];
    require(pool.lastUpdatedAt == 0, "Blacksmith: lpToken, not allowed");
    require(allowBonusTokens[_token] == 0, "Blacksmith: bonusToken, not allowed");

    IERC20 token = IERC20(_token);
    uint256 amount = token.balanceOf(address(this));
    require(amount > 0, "Blacksmith: 0 to collect");

    if (_token == address(0)) { // token address(0) == ETH
      payable(treasury).transfer(amount);
    } else {
      token.safeTransfer(treasury, amount);
    }
  }

  /// @notice collect bonus token dust to treasury
  function collectBonusDust(address _lpToken) external override {
    BonusToken memory bonusToken = bonusTokens[_lpToken];
    require(bonusToken.endTime.add(WEEK) < block.timestamp, "Blacksmith: bonusToken, not ready");

    IERC20 token = IERC20(bonusToken.addr);
    uint256 amount = token.balanceOf(address(this));
    require(amount > 0, "Blacksmith: 0 to collect");
    token.safeTransfer(treasury, amount);
  }

  /// @notice update all pools before update weekly total, otherwise, there will a small (more so for pools with less user interactions) rewards mess up for each pool
  function updateWeeklyTotal(uint256 _weeklyTotal) external override onlyGovernance {
    weeklyTotal = _weeklyTotal;
  }

  /// @notice use start and end to avoid gas limit in one call
  function updatePools(uint256 _start, uint256 _end) external override {
    address[] memory poolListCopy = poolList;
    for (uint256 i = _start; i < _end; i++) {
      updatePool(poolListCopy[i]);
    }
  }

  /// @notice transfer minting rights to new blacksmith
  function transferMintingRights(address _newAddress) external override onlyGovernance {
    cover.setBlacksmith(_newAddress);
  }

  function _calculateCoverRewardsForPeriod(Pool memory _pool) internal view returns (uint256) {
    uint256 timePassed = block.timestamp.sub(_pool.lastUpdatedAt);
    return weeklyTotal.mul(CAL_MULTIPLIER).mul(timePassed).mul(_pool.weight).div(totalWeight).div(WEEK);
  }

  function _calculateBonusForPeriod(BonusToken memory _bonusToken) internal view returns (uint256) {
    if (_bonusToken.endTime == _bonusToken.lastUpdatedAt) return 0;

    uint256 calTime = block.timestamp > _bonusToken.endTime ? _bonusToken.endTime : block.timestamp;
    uint256 timePassed = calTime.sub(_bonusToken.lastUpdatedAt);
    uint256 totalDuration = _bonusToken.endTime.sub(_bonusToken.startTime);
    return _bonusToken.totalBonus.mul(CAL_MULTIPLIER).mul(timePassed).div(totalDuration);
  }

  /// @notice tranfer upto what the contract has
  function _safeTransfer(address _token, uint256 _amount) private nonReentrant {
    IERC20 token = IERC20(_token);
    uint256 balance = token.balanceOf(address(this));
    if (balance > _amount) {
      token.safeTransfer(msg.sender, _amount);
    } else if (balance > 0) {
      token.safeTransfer(msg.sender, balance);
    }
  }

  function _claimCoverRewards(Pool memory pool, Miner memory miner) private nonReentrant {
    if (miner.amount > 0) {
      uint256 minedSinceLastUpdate = miner.amount.mul(pool.accRewardsPerToken).div(CAL_MULTIPLIER).sub(miner.rewardWriteoff);
      if (minedSinceLastUpdate > 0) {
        cover.mint(msg.sender, minedSinceLastUpdate); // mint COVER tokens to miner
      }
    }
  }

  function _claimBonus(BonusToken memory bonusToken, Miner memory miner) private {
    if (bonusToken.totalBonus > 0 && miner.amount > 0 && bonusToken.startTime < block.timestamp) {
      uint256 bonusSinceLastUpdate = miner.amount.mul(bonusToken.accBonusPerToken).div(CAL_MULTIPLIER).sub(miner.bonusWriteoff);
      if (bonusSinceLastUpdate > 0) {
        _safeTransfer(bonusToken.addr, bonusSinceLastUpdate); // transfer bonus tokens to miner
      }
    }
  }
}
pragma solidity ^0.7.4;

/**
 * @title Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function totalSupply() external view returns (uint256);
}
pragma solidity ^0.7.4;

import "./IERC20.sol";
import "../utils/SafeMath.sol";
import "../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}
pragma solidity ^0.7.4;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}
pragma solidity ^0.7.4;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 * @author crypto-pumpkin@github
 *
 * By initialization, the owner account will be the one that called initializeOwner. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev COVER: Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}
pragma solidity ^0.7.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor () {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}
pragma solidity ^0.7.4;

import "../ERC20/IERC20.sol";

/**
 * @title Interface of COVER
 * @author crypto-pumpkin@github
 */
interface ICOVER is IERC20 {
  function mint(address _account, uint256 _amount) external;
  function setBlacksmith(address _newBlacksmith) external returns (bool);
  function setMigrator(address _newMigrator) external returns (bool);
}
pragma solidity ^0.7.4;

/**
 * @title Interface of COVER shield mining contract Blacksmith
 * @author crypto-pumpkin@github
 */
interface IBlacksmith {
  struct Miner {
    uint256 amount;
    uint256 rewardWriteoff; // the amount of COVER tokens to write off when calculate rewards from last update
    uint256 bonusWriteoff; // the amount of bonus tokens to write off when calculate rewards from last update
  }

  struct Pool {
    uint256 weight; // the allocation weight for pool
    uint256 accRewardsPerToken; // accumulated COVER to the lastUpdated Time
    uint256 lastUpdatedAt; // last accumulated rewards update timestamp
  }

  struct BonusToken {
    address addr; // the external bonus token, like CRV
    uint256 startTime;
    uint256 endTime;
    uint256 totalBonus; // total amount to be distributed from start to end
    uint256 accBonusPerToken; // accumulated bonus to the lastUpdated Time
    uint256 lastUpdatedAt; // last accumulated bonus update timestamp
  }

  event Deposit(address indexed miner, address indexed lpToken, uint256 amount);
  event Withdraw(address indexed miner, address indexed lpToken, uint256 amount);

  // View functions
  function getPoolList() external view returns (address[] memory);
  function viewMined(address _lpToken, address _miner) external view returns (uint256 _minedCOVER, uint256 _minedBonus);
  // function minedRewards(address _lpToken, address _miner) external view returns (uint256);
  // function minedBonus(address _lpToken, address _miner) external view returns (uint256 _minedBonus, address _bonusToken);

  // User action functions
  function claimRewardsForPools(address[] calldata _lpTokens) external;
  function claimRewards(address _lpToken) external;
  function deposit(address _lpToken, uint256 _amount) external;
  function withdraw(address _lpToken, uint256 _amount) external;
  function emergencyWithdraw(address _lpToken) external;

  // Partner action functions
  function addBonusToken(address _lpToken, address _bonusToken, uint256 _startTime, uint256 _endTime, uint256 _totalBonus) external;

  // COVER mining actions
  function updatePool(address _lpToken) external;
  function updatePools(uint256 _start, uint256 _end) external;
  /// @notice dust will be collected to COVER treasury
  function collectDust(address _token) external;
  function collectBonusDust(address _lpToken) external;

  /// @notice only dev
  function addPool(address _lpToken, uint256 _weight) external;
  function addPools(address[] calldata _lpTokens, uint256[] calldata _weights) external;
  function updateBonusTokenStatus(address _bonusToken, uint8 _status) external;

  /// @notice only governance
  function updatePoolWeights(address[] calldata _lpTokens, uint256[] calldata _weights) external;
  function updateWeeklyTotal(uint256 _weeklyTotal) external;
  function transferMintingRights(address _newAddress) external;
}
pragma solidity ^0.7.4;

library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}
pragma solidity ^0.7.4;

import "./ERC20/IERC20.sol";
import "./ERC20/SafeERC20.sol";
import "./utils/Ownable.sol";
import "./utils/SafeMath.sol";
import "./utils/MerkleProof.sol";
import "./interfaces/ICOVER.sol";
import "./interfaces/IMigrator.sol";

/**
 * @title COVER token migrator
 * @author crypto-pumpkin@github + @Kiwi
 */
contract Migrator is Ownable, IMigrator {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  IERC20 public safe2;
  ICOVER public cover;
  address public governance;
  bytes32 public immutable merkleRoot;
  uint256 public safe2Migrated; // total: 52,689.18
  uint256 public safeClaimed; // total: 2160.76
  uint256 public constant migrationCap = 54850e18;
  uint256 public constant START_TIME = 1605830400; // 11/20/2020 12am UTC
  mapping(uint256 => uint256) private claimedBitMap;

  constructor (address _governance, address _coverAddress, address _safe2, bytes32 _merkleRoot) {
    governance = _governance;
    cover = ICOVER(_coverAddress);

    require(_safe2 == 0x250a3500f48666561386832f1F1f1019b89a2699, "Migrator: safe2 address not match");
    safe2 = IERC20(_safe2);

    merkleRoot = _merkleRoot;
  }

  function isSafeClaimed(uint256 _index) public view override returns (bool) {
    uint256 claimedWordIndex = _index / 256;	
    uint256 claimedBitIndex = _index % 256;	
    uint256 claimedWord = claimedBitMap[claimedWordIndex];	
    uint256 mask = (1 << claimedBitIndex);	
    return claimedWord & mask == mask;
  }

  function migrateSafe2() external override {
    require(block.timestamp >= START_TIME, "Migrator: not started");
    uint256 safe2Balance = safe2.balanceOf(msg.sender);

    require(safe2Balance > 0, "Migrator: no safe2 balance");
    safe2.transferFrom(msg.sender, 0x000000000000000000000000000000000000dEaD, safe2Balance);
    cover.mint(msg.sender, safe2Balance);
    safe2Migrated = safe2Migrated.add(safe2Balance);
  }

  function claim(uint256 _index, uint256 _amount, bytes32[] calldata _merkleProof) external override {
    require(block.timestamp >= START_TIME, "Migrator: not started");
    require(_amount > 0, "Migrator: amount is 0");
    require(!isSafeClaimed(_index), 'Migrator: already claimed');
    require(safe2Migrated.add(safeClaimed).add(_amount) <= migrationCap, "Migrator: cap exceeded"); // SAFE2 take priority first

    // Verify the merkle proof.
    bytes32 node = keccak256(abi.encodePacked(_index, msg.sender, _amount));
    require(MerkleProof.verify(_merkleProof, merkleRoot, node), 'Migrator: invalid proof');

    // Mark it claimed and send the token.
    _setClaimed(_index);
    safeClaimed = safeClaimed.add(_amount);
    cover.mint(msg.sender, _amount);
  }

  /// @notice transfer minting right to new migrator if migrator has issues. Once all migration is done, transfer right to 0.
  function transferMintingRights(address _newAddress) external override {
    require(msg.sender == governance, "Migrator: caller not governance");
    cover.setMigrator(_newAddress);
  }

  function _setClaimed(uint256 _index) private {	
    uint256 claimedWordIndex = _index / 256;	
    uint256 claimedBitIndex = _index % 256;	
    claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);	
  }
}
pragma solidity ^0.7.4;

/**
 * @dev These functions deal with verification of Merkle trees (hash trees),
 */
library MerkleProof {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}
pragma solidity ^0.7.4;

/**
 * @title COVER token migrator
 * @author crypto-pumpkin@github + @Kiwi
 */
interface IMigrator {
  function isSafeClaimed(uint256 _index) external view returns (bool);
  function migrateSafe2() external;
  function claim(uint256 _index, uint256 _amount, bytes32[] calldata _merkleProof) external;

  /// @notice only governance
  function transferMintingRights(address _newAddress) external;
}
pragma solidity ^0.7.4;

import "./utils/SafeMath.sol";
import "./ERC20/SafeERC20.sol";

/**
 * @title COVER token contract
 * @author Alan
 */
contract Vesting {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant START_TIME = 1605830400; // 11/20/2020 12 AM UTC
    uint256 public constant MIDDLE_TIME = 1621468800; // 5/20/2021 12 AM UTC
    uint256 public constant END_TIME = 1637366400; // 11/20/2021 12 AM UTC

    mapping (address => uint256) private _vested;
    mapping (address => uint256) private _total;

    constructor() {
        // TODO: change addresses to team addresses
        _total[address(0x406a0c87A6bb25748252cb112a7a837e21aAcD98)] = 2700 ether;
        _total[address(0x3e677718f8665A40AC0AB044D8c008b55f277c98)] = 2700 ether;
        _total[address(0x094AD38fB69f27F6Eb0c515ad4a5BD4b9F9B2996)] = 2700 ether;
        _total[address(0xD4C8127AF1dE3Ebf8AB7449aac0fd892b70f3b45)] = 1620 ether;
        _total[address(0x82BBd2F08a59f5be1B4e719ff701e4D234c4F8db)] = 720 ether;
        _total[address(0xF00Bf178E3372C4eF6E15A1676fd770DAD2aDdfB)] = 360 ether;
        // _total[address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8)] = 2700 ether;
        // _total[address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC)] = 2700 ether;
        // _total[address(0x90F79bf6EB2c4f870365E785982E1f101E93b906)] = 2700 ether;
        // _total[address(0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65)] = 1620 ether;
        // _total[address(0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc)] = 720 ether;
        // _total[address(0x976EA74026E726554dB657fA54763abd0C3a0aa9)] = 360 ether;
    }

    function vest(IERC20 token) external {
        require(block.timestamp >= START_TIME, "Vesting: !started");
        require(_total[msg.sender] > 0, "Vesting: not team");

        uint256 toBeReleased = releasableAmount(msg.sender);
        require(toBeReleased > 0, "Vesting: all vested");

        _vested[msg.sender] = _vested[msg.sender].add(toBeReleased);
        token.safeTransfer(msg.sender, toBeReleased);
    }

    function releasableAmount(address _addr) public view returns (uint256) {
        return unlockedAmount(_addr).sub(_vested[_addr]);
    }

    function unlockedAmount(address _addr) public view returns (uint256) {
        if (block.timestamp <= MIDDLE_TIME) {
            uint256 duration = MIDDLE_TIME.sub(START_TIME);
            uint256 firstHalf = _total[_addr].mul(2).div(3);
            uint256 timePassed = block.timestamp.sub(START_TIME);
            return firstHalf.mul(timePassed).div(duration);
        } else if (block.timestamp > MIDDLE_TIME && block.timestamp <= END_TIME) {
            uint256 duration = END_TIME.sub(MIDDLE_TIME);
            uint256 firstHalf = _total[_addr].mul(2).div(3);
            uint256 secondHalf = _total[_addr].div(3);
            uint256 timePassed = block.timestamp.sub(MIDDLE_TIME);
            return firstHalf.add(secondHalf.mul(timePassed).div(duration));
        } else {
            return _total[_addr];
        }
    }

}
pragma solidity ^0.7.4;

import "../utils/SafeMath.sol";
import "./IERC20.sol";

contract ERC20 is IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

  constructor (string memory name_, string memory symbol_) {
    _name = name_;
    _symbol = symbol_;
    _decimals = 18;
  }

  function name() public view returns (string memory) {
    return _name;
  }

  function symbol() public view returns (string memory) {
    return _symbol;
  }

  function decimals() public view returns (uint8) {
    return _decimals;
  }

  function totalSupply() public view override returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account) public view override returns (uint256) {
    return _balances[account];
  }

  function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
    _transfer(msg.sender, recipient, amount);
    return true;
  }

  function allowance(address owner, address spender) public view virtual override returns (uint256) {
    return _allowances[owner][spender];
  }

  function approve(address spender, uint256 amount) public virtual override returns (bool) {
    _approve(msg.sender, spender, amount);
    return true;
  }

  function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
    return true;
  }

  function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
    _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
    return true;
  }

  function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
    _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
    return true;
  }

  function _transfer(address sender, address recipient, uint256 amount) internal virtual {
    require(sender != address(0), "ERC20: transfer from the zero address");
    require(recipient != address(0), "ERC20: transfer to the zero address");


    _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
    _balances[recipient] = _balances[recipient].add(amount);
    emit Transfer(sender, recipient, amount);
  }

  function _mint(address account, uint256 amount) internal virtual {
    require(account != address(0), "ERC20: mint to the zero address");

    _totalSupply = _totalSupply.add(amount);
    _balances[account] = _balances[account].add(amount);
    emit Transfer(address(0), account, amount);
  }

  function _approve(address owner, address spender, uint256 amount) internal virtual {
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }
}
