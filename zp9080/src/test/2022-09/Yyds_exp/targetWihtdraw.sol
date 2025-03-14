pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol



pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
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

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol



pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function decimals() external view returns (uint8);
}

// File: @openzeppelin/contracts/math/SafeMath.sol



pragma solidity >=0.6.0 <0.8.0;

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
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     * 
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

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
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
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
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
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
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
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
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
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
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
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
        require(b > 0, errorMessage);
        return a % b;
    }
}

// File: @openzeppelin/contracts/utils/Address.sol



pragma solidity >=0.6.2 <0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
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
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
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
        return functionCallWithValue(target, data, 0, errorMessage);
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
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
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

// File: @openzeppelin/contracts/token/ERC20/SafeERC20.sol



pragma solidity >=0.6.0 <0.8.0;




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

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}


// pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

// pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}



// pragma solidity >=0.6.2;

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}



interface Relationship {
    struct Player {
        uint256 id;
        address[] directRecommendAddress;
        address referrer;
        uint256 totalNumberOfSubordinates;
        uint256 totalConsumptionOfSubordinates;
    }

    function getReferralRelationship(address _user) external view returns(Player memory);
    function updateReferralRelationship(address user, address referrer) external ;

    function undatePlayerInfo(address user,Player memory player) external;
}



interface management {

    function usdtAddress() external view returns (address);
    function yydsAddress() external view returns (address);
    function consumptionReturnPool() external view returns (address);
    function nodeRwardPool() external view returns (address);  
    function uniswapV2Router() external view returns (address);  
    function merchantFactory() external view returns (address);  
    function pair() external view returns (address);  
    function relationshipAddress() external view returns (address);  
   
}

interface merchantFactory {
    struct Merchant {
        address merchantAddress;
    }


    function merchantInfo(address) external view returns (Merchant memory);

    function isMerchantContract(address) external view returns (bool);
   
}


pragma solidity >=0.6.0 <0.8.0;

contract consumptionReturnPool is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct ConsumerInfo {
        uint256 orderId;
        uint256 amount; 
        uint256 returnTime;
        uint256 returnCount;
        uint256 remainingAmount;
        ReturnHistory[] returnHistory;
    }
    struct MerchantInfo {
        uint256 orderId;
        uint256 amount;
        uint256 returnTime;
        uint256 returnCount;
        uint256 remainingAmount;
        ReturnHistory[] returnHistory;
    }

    struct ReferralRewardInfo{
        uint256 orderId;
        uint256 amount;
        uint256 returnTime;
        uint256 returnCount;
        uint256 remainingAmount;
    }

     struct ReturnHistory{ 
        uint256 returnTime;
        uint256 returnRatio;
    }

    struct Statistics{
        uint256 totalConsumption;
        uint256 extractedConsumerReturn;
        uint256 extractedMerchantReturn;
        uint256 extractedReferralReward;
    }

    mapping(address=>bool) public merchantContractList;

    mapping(address=>ConsumerInfo[]) public consumers;
    mapping(address=>Statistics) public statisticsByUser;
    mapping(address=>ReferralRewardInfo[]) public users;
    mapping(address=>MerchantInfo[]) public merchants;

    uint256 public totalSales;
    uint256 public consumptionTimes;
    uint256 public totalConsumerReturn;
    uint256 public totalMerchantReturn;
    uint256 public totalReferralReturn;

    modifier onlyMerchantContract() { 
        require(merchantFactory(management(managementAddress).merchantFactory()).isMerchantContract(msg.sender)==true, "Ownable: caller is not the merchantContract");
        _;
    }

    modifier onlyMerchantFactory() {
        require(msg.sender==management(managementAddress).merchantFactory(), "Ownable: caller is not the merchantContract");
        _;
    }

    address public managementAddress;

    function  setManagementAddress(address _managementAddress) public onlyOwner{
        managementAddress=_managementAddress;
    }

    constructor() public {}

    function addReturn(uint256 _orderId,address _consumer,address _merchant,uint256 _amount) public onlyMerchantContract(){
        consumptionTimes+=1;
        totalSales=totalSales.add(_amount);
        statisticsByUser[_consumer].totalConsumption=statisticsByUser[_consumer].totalConsumption.add(_amount);

        require(consumers[_consumer].length<5000,"The number of consumption has reached the upper limit, please change the account");
        require(merchants[_merchant].length<5000,"The number of merchant has reached the upper limit, please change the account");

        uint256 returnTime=block.timestamp+(86400-block.timestamp%86400)-28800;
        addReferralReward(_orderId,_consumer,_merchant,_amount.mul(10).div(100),returnTime);
        ConsumerInfo storage consumerInfo;
        consumerInfo.orderId=_orderId;
        consumerInfo.amount=_amount;
        consumerInfo.returnTime=returnTime;
        consumerInfo.returnCount=0;
        consumerInfo.remainingAmount=_amount;
        consumers[_consumer].push(consumerInfo);
        MerchantInfo storage merchantInfo;
        merchantInfo.orderId=_orderId;
        merchantInfo.amount=_amount.mul(13).div(100);
        merchantInfo.returnTime=returnTime;
        merchantInfo.returnCount=0;
        merchantInfo.remainingAmount=_amount.mul(13).div(100);
        merchants[_merchant].push(merchantInfo);
    }

    function addReferralReward(uint256 _orderId,address _consumer,address _merchant,uint256 _amount,uint256 _returnTime) private {
        address consumerReferrer=Relationship(management(managementAddress).relationshipAddress()).getReferralRelationship(_consumer).referrer; 
        address merchantReferrer=Relationship(management(managementAddress).relationshipAddress()).getReferralRelationship(_merchant).referrer; 
        ReferralRewardInfo memory referralRewardInfo;
        referralRewardInfo.orderId=_orderId;
        referralRewardInfo.amount=_amount;
        referralRewardInfo.returnTime=_returnTime;
        referralRewardInfo.returnCount=0;
        referralRewardInfo.remainingAmount=_amount;

        users[consumerReferrer].push(referralRewardInfo);
        users[merchantReferrer].push(referralRewardInfo);
    }



    function getReturnAmountByConsumer(address _consumer) public view returns(uint256){
        uint256 returnAmount;

        for (uint i=0;i<consumers[_consumer].length;i++){
            ConsumerInfo storage consumerInfo=consumers[_consumer][i];
            if (consumerInfo.returnTime>block.timestamp){
                continue;
            }
            uint256 returnCount=1;

            if (block.timestamp>consumerInfo.returnTime){
            returnCount=returnCount.add((block.timestamp-consumerInfo.returnTime).div(24 hours));
            }
            if (consumerInfo.amount.mul(5).div(10000).mul(returnCount)>consumerInfo.remainingAmount){
             returnAmount=returnAmount.add(consumerInfo.remainingAmount);
            }else{
              returnAmount=returnAmount.add(consumerInfo.amount.mul(5).div(10000).mul(returnCount));
            }
        }
        return returnAmount;
    }

    function getReturnAmountByMerchant(address _merchant) public view returns(uint256 ){
        uint256 returnAmount;

        for (uint i=0;i<merchants[_merchant].length;i++){
            MerchantInfo storage merchantInfo=merchants[_merchant][i];
            if (merchantInfo.returnTime>block.timestamp){
                continue;
            }
            uint256 returnCount=1;
            
            if (block.timestamp>merchantInfo.returnTime){
            returnCount=returnCount.add((block.timestamp-merchantInfo.returnTime).div(24 hours));
            }
            if (merchantInfo.amount.mul(5).div(10000).mul(returnCount)>merchantInfo.remainingAmount){
             returnAmount=returnAmount.add(merchantInfo.remainingAmount);
            }else{
              returnAmount=returnAmount.add(merchantInfo.amount.mul(5).div(10000).mul(returnCount));
            }
        }
        return returnAmount;
    }

    function getReturnAmountByReferral(address _user) public view returns(uint256 ){
        uint256 returnAmount;

        for (uint i=0;i<users[_user].length;i++){
            ReferralRewardInfo storage referralRewardInfo=users[_user][i];
            if (referralRewardInfo.returnTime>block.timestamp){
                continue;
            }
            uint256 returnCount=1;
            
            if (block.timestamp>referralRewardInfo.returnTime){
            returnCount=returnCount.add((block.timestamp-referralRewardInfo.returnTime).div(24 hours));
            }
            if (referralRewardInfo.amount.mul(5).div(10000).mul(returnCount)>referralRewardInfo.remainingAmount){
             returnAmount=returnAmount.add(referralRewardInfo.remainingAmount);
            }else{
              returnAmount=returnAmount.add(referralRewardInfo.amount.mul(5).div(10000).mul(returnCount));
            }
        }
 
        return returnAmount;
    }


    function withdrawReturnAmountByConsumer() public {
        uint256 totalReturnAmount;
        for (uint i=0;i<consumers[msg.sender].length;i++){
            ConsumerInfo storage consumerInfo=consumers[msg.sender][i];
            uint256 returnCount=1;
            uint256 returnAmount;
            if (consumerInfo.returnTime>block.timestamp){
                continue;
            }
            if (block.timestamp>consumerInfo.returnTime){
             returnCount=returnCount.add((block.timestamp-consumerInfo.returnTime).div(24 hours));
            }
            if (consumerInfo.amount.mul(5).div(10000).mul(returnCount)>consumerInfo.remainingAmount){
             returnAmount=consumerInfo.remainingAmount;
            }else{
              returnAmount=consumerInfo.amount.mul(5).div(10000).mul(returnCount);
            }
            totalReturnAmount=totalReturnAmount.add(returnAmount);
            consumerInfo.remainingAmount=consumerInfo.remainingAmount.sub(returnAmount);
            consumerInfo.returnTime=consumerInfo.returnTime.add(24 hours*returnCount);
            consumerInfo.returnHistory.push(ReturnHistory({returnTime:block.timestamp,returnRatio:returnAmount}));
        }
        require(totalReturnAmount>0,"totalReturnAmount err");
        uint256 priceOfUSDT=getPriceOfUSDT();
        uint256 yydsAmount=totalReturnAmount.mul(10**18).div(priceOfUSDT);

        IERC20(management(managementAddress).yydsAddress()).safeTransfer(
                            msg.sender,
                            yydsAmount
        );
        statisticsByUser[msg.sender].extractedConsumerReturn=statisticsByUser[msg.sender].extractedConsumerReturn.add(totalReturnAmount);
        totalConsumerReturn=totalConsumerReturn.add(totalReturnAmount);
    }

    function withdrawReturnAmountByReferral() public {

        uint256 totalReturnAmount;

        for (uint i=0;i<users[msg.sender].length;i++){
            ReferralRewardInfo storage referralRewardInfo=users[msg.sender][i];
            uint256 returnCount=1;
            uint256 returnAmount;
            if (referralRewardInfo.returnTime>block.timestamp){
                continue;
            }
            if (block.timestamp>referralRewardInfo.returnTime){
             returnCount=returnCount.add((block.timestamp-referralRewardInfo.returnTime).div(24 hours));
            }
            if (referralRewardInfo.amount.mul(5).div(10000).mul(returnCount)>referralRewardInfo.remainingAmount){
             returnAmount=referralRewardInfo.remainingAmount;
            }else{
              returnAmount=referralRewardInfo.amount.mul(5).div(10000).mul(returnCount);
            }
            totalReturnAmount=totalReturnAmount.add(returnAmount);
            referralRewardInfo.remainingAmount=referralRewardInfo.remainingAmount.sub(returnAmount);
            referralRewardInfo.returnTime=referralRewardInfo.returnTime.add(24 hours*returnCount);
        }
        require(totalReturnAmount>0,"totalReturnAmount err");

        uint256 priceOfUSDT=getPriceOfUSDT();
        uint256 yydsAmount=totalReturnAmount.mul(10**18).div(priceOfUSDT);

        IERC20(management(managementAddress).yydsAddress()).safeTransfer(
                            msg.sender,
                            yydsAmount
        );
        statisticsByUser[msg.sender].extractedReferralReward=statisticsByUser[msg.sender].extractedReferralReward.add(totalReturnAmount);
        totalReferralReturn=totalReferralReturn.add(totalReturnAmount);

    }
    function withdrawReturnAmountByMerchant() public {
        uint256 totalReturnAmount;
        for (uint i=0;i<merchants[msg.sender].length;i++){
            MerchantInfo storage merchantInfo=merchants[msg.sender][i];
            uint256 returnCount=1;
            uint256 returnAmount;
            if (merchantInfo.returnTime>block.timestamp){
                continue;
            }
            if (block.timestamp>merchantInfo.returnTime){
             returnCount=returnCount.add((block.timestamp-merchantInfo.returnTime).div(24 hours));
            }
            if (merchantInfo.amount.mul(5).div(10000).mul(returnCount)>merchantInfo.remainingAmount){
             returnAmount=merchantInfo.remainingAmount;
            }else{
              returnAmount=merchantInfo.amount.mul(5).div(10000).mul(returnCount);
            }
            totalReturnAmount=totalReturnAmount.add(returnAmount);
            merchantInfo.remainingAmount=merchantInfo.remainingAmount.sub(returnAmount);
            merchantInfo.returnTime=merchantInfo.returnTime.add(24 hours*returnCount);
            merchantInfo.returnHistory.push(ReturnHistory({returnTime:block.timestamp,returnRatio:returnAmount}));
        }
        require(totalReturnAmount>0,"totalReturnAmount err");

        uint256 priceOfUSDT=getPriceOfUSDT();
        uint256 yydsAmount=totalReturnAmount.mul(10**18).div(priceOfUSDT);

        IERC20(management(managementAddress).yydsAddress()).safeTransfer(
                            msg.sender,
                            yydsAmount
        );
        statisticsByUser[msg.sender].extractedMerchantReturn=statisticsByUser[msg.sender].extractedMerchantReturn.add(totalReturnAmount);
        totalMerchantReturn=totalMerchantReturn.add(totalReturnAmount);
    }

    function  getPriceOfUSDT() public view returns (uint256 price){
        uint256 balancePath1= IERC20(management(managementAddress).usdtAddress()).balanceOf(management(managementAddress).pair());
        uint256 balancePath2= IERC20(management(managementAddress).yydsAddress()).balanceOf(management(managementAddress).pair());
        uint256 path1Decimals=IERC20(management(managementAddress).usdtAddress()).decimals();
        uint256 path2Decimals=IERC20(management(managementAddress).yydsAddress()).decimals();
        price=(balancePath1/10**path1Decimals*10**18)/(balancePath2/10**path2Decimals);
    }

     receive() external payable {}
}
