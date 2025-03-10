pragma solidity 0.8.19;

import "./interfaces/IControl.sol";
import "./interfaces/IHYDT.sol";

import "./libraries/DataFetcher.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/SafeETH.sol";

import "./utils/Context.sol";

contract InitialMintV2 is Context {

    /* ========== STATE VARIABLES ========== */

    /// @dev Fixed time duration variables.
    uint128 private constant THREE_MONTHS_TIME = 7776000;
    uint128 private constant ONE_DAY_TIME = 86400;

    /// @notice The address of the Pancake Factory.
    address public constant PANCAKE_FACTORY = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;

    /// @notice The address of the Wrapped BNB token.
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    /// @notice The address of the relevant stable token.
    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;

    /// @notice The total limit of USD allowed for purchasing HYDT with over the course of initial minting.
    uint128 public constant INITIAL_MINT_LIMIT = 30000000 * 1e18;
    /// @notice The daily limit of USD allowed for purchasing HYDT with during initial minting.
    uint128 public constant DAILY_INITIAL_MINT_LIMIT = 700000 * 1e18;

    /// @notice The address of the primary stable token.
    IHYDT public HYDT;
    /// @notice The address of the BNB reserve.
    address public RESERVE;

    /// @dev Storage of values regarding purchases of HYDT during initial minting.
    InitialMintValues private _initialMints;
    InitialMintValues private _dailyInitialMints;

    /// @dev Initialization variables.
    address private immutable _initializer;
    bool private _isInitialized;

    /* ========== STORAGE ========== */

    struct InitialMintValues {
        uint256 startTime;
        uint256 endTime;
        uint256 amount;
    }

    /* ========== EVENTS ========== */

    event InitialMint(address indexed user, uint256 amountBNB, uint256 amountHYDT, uint256 callingPrice);

    /* ========== CONSTRUCTOR ========== */

    constructor() {
        _initializer = _msgSender();
    }

    /* ========== INITIALIZE ========== */

    /**
     * @notice Initializes external dependencies and state variables.
     * @dev This function can only be called once.
     * @param control_ The address of the `Control` contract.
     * @param hydt_ The address of the `HYDT` contract.
     * @param reserve_ The address of the `Reserve` contract.
     * @param initialMintStartTime_ The unix timestamp at which initial minting will begin.
     */
    function initialize(address control_, address hydt_, address reserve_, uint256 initialMintStartTime_) external {
        require(_msgSender() == _initializer, "InitialMint: caller is not the initializer");
        require(!_isInitialized, "InitialMint: already initialized");

        require(control_ != address(0), "InitialMint: invalid Control address");
        require(hydt_ != address(0), "InitialMint: invalid HYDT address");
        require(reserve_ != address(0), "InitialMint: invalid Reserve address");
        HYDT = IHYDT(hydt_);
        RESERVE = reserve_;

        _initialMints.startTime = initialMintStartTime_;
        // _initialMints.endTime = 0;
        (, , _initialMints.amount) = IControl(control_).getInitialMints();

        _dailyInitialMints.startTime = initialMintStartTime_;
        _dailyInitialMints.endTime = initialMintStartTime_ + ONE_DAY_TIME;
        // _dailyInitialMints.amount = 0;

        _isInitialized = true;
    }

    /* ========== FUNCTIONS ========== */

    /**
     * @notice Gets total values for initial minting.
     * @return startTime The unix timestamp which denotes the start of initial minting.
     * @return amountUSD The amount in USD that has been transacted via inital minting in total.
     */
    function getInitialMints() external view returns (uint256 startTime, uint256 amountUSD) {
        startTime = _initialMints.startTime;
        amountUSD = _initialMints.amount;
    }

    /**
     * @notice Gets daily values for initial minting.
     * @return startTime The unix timestamp which denotes the start of the day.
     * @return endTime The unix timestamp which denotes the end of the day.
     * @return amountUSD The amount in USD that has been transacted via inital minting in said day.
     */
    function getDailyInitialMints() external view returns (uint256 startTime, uint256 endTime, uint256 amountUSD) {
        startTime = _dailyInitialMints.startTime;
        endTime = _dailyInitialMints.endTime;
        amountUSD = _dailyInitialMints.amount;

        if (block.timestamp > _dailyInitialMints.endTime) {
            (startTime, endTime) =
                _getNextDailyInitialMintTime(_dailyInitialMints.startTime, _dailyInitialMints.endTime);
            amountUSD = 0;
        }
    }

    /**
     * @dev Gets the start and end times for the next iteration of daily initial mints.
     */
    function _getNextDailyInitialMintTime(uint256 startTime, uint256 endTime) internal view returns (uint256, uint256) {
        uint256 numberOfDays = (block.timestamp - startTime) / ONE_DAY_TIME;
        return (
            startTime + (numberOfDays * ONE_DAY_TIME),
            endTime + (numberOfDays * ONE_DAY_TIME)
        );
    }

    /**
     * @notice Gets current HYDT price corresponding to the preferred pair.
     */
    function getCurrentPrice() public view returns (uint256) {
        address[] memory path = new address[](3);
        path[0] = address(HYDT);
        path[1] = WBNB;
        path[2] = USDT;
        uint256 amountIn = 1 * 1e18;
        uint256 price = DataFetcher.quoteRouted(PANCAKE_FACTORY, amountIn, path);
        return price;
    }

    /**
     * @notice Used to mint HYDT in return for BNB. All transfers will be made at 1 HYDT per USD at current BNB/USD rates.
     */
    function initialMint() external payable {
        require(msg.value > 0, "InitialMint: insufficient BNB amount");
        InitialMintValues storage initialMints = _initialMints;
        InitialMintValues storage dailyInitialMints = _dailyInitialMints;

        require(block.timestamp > initialMints.startTime, "InitialMint: initial mint not yet started");

        if (block.timestamp > dailyInitialMints.endTime) {
            (dailyInitialMints.startTime, dailyInitialMints.endTime) =
                _getNextDailyInitialMintTime(dailyInitialMints.startTime, dailyInitialMints.endTime);
            dailyInitialMints.amount = 0;
        }
        uint256 amount = DataFetcher.quote(PANCAKE_FACTORY, msg.value, WBNB, USDT);

        require(
            INITIAL_MINT_LIMIT >=
            initialMints.amount + amount,
            "InitialMint: invalid amount considering initial mint limit"
        );
        require(
            DAILY_INITIAL_MINT_LIMIT >=
            dailyInitialMints.amount + amount,
            "InitialMint: invalid amount considering daily initial mint limit"
        );
        initialMints.amount += amount;
        dailyInitialMints.amount += amount;
        SafeETH.safeTransferETH(RESERVE, msg.value);
        HYDT.mint(_msgSender(), amount);

        emit InitialMint(_msgSender(), msg.value, amount, 1 * 1e18);
    }
}
pragma solidity 0.8.19;

interface IControl {

    function mintProgressCount() external view returns (uint256);

    function redeemProgressCount() external view returns (uint256);

    function lastExecutedMint() external view returns (uint256);

    function lastExecutedRedeem() external view returns (uint256);

    function delegateApprove(address token, address guy, bool isApproved) external;

    function getDailyInitialMints() external view returns (uint256 startTime, uint256 endTime, uint256 amountUSD);

    function getInitialMints() external view returns (uint256 startTime, uint256 endTime, uint256 amountUSD);

    function initialMint() external payable;

    function getCurrentPrice() external view returns (uint256);

    function execute(uint8 argument) external;
}
pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
pragma solidity 0.8.19;

import "./IERC20.sol";

interface IHYDT is IERC20 {

    function mint(address to, uint256 amount) external returns (bool);

    function burn(uint256 amount) external returns (bool);

    function burnFrom(address from, uint256 amount) external returns (bool);
}
pragma solidity ^0.8.0;

interface IPancakeFactory {
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
pragma solidity ^0.8.0;

interface IPancakePair {
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
pragma solidity ^0.8.1;

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
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
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
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
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
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}
pragma solidity 0.8.19;

import "../interfaces/IPancakeFactory.sol";
import "../interfaces/IPancakePair.sol";

library DataFetcher {

    function pairFor(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (address pair) {
        require(tokenA != tokenB, "DataFetcher: IDENTICAL_ADDRESSES");
        require(tokenA != address(0) && tokenB != address(0), "DataFetcher: ZERO_ADDRESS_TOKEN");
        pair = IPancakeFactory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "DataFetcher: ZERO_ADDRESS_PAIR");
    }

    function getReserves(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        address pair = pairFor(factory, tokenA, tokenB);
        address token0 = IPancakePair(pair).token0();
        (uint256 reserve0, uint256 reserve1, ) = IPancakePair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
        require(reserveA > 0 && reserveB > 0, "DataFetcher: INSUFFICIENT_LIQUIDITY");
    }

    function quote(
        address factory,
        uint256 amountA,
        address tokenA,
        address tokenB
    ) internal view returns (uint256 amountB) {
        require(amountA > 0, "DataFetcher: INSUFFICIENT_AMOUNT");
        (uint256 reserveA, uint256 reserveB) = getReserves(factory, tokenA, tokenB);
        amountB = (amountA * reserveB) / reserveA;
    }

    function quoteBatch(
        address factory,
        uint256[] memory amountsA,
        address tokenA,
        address tokenB
    ) internal view returns (uint256[] memory amountsB) {
        require(amountsA.length >= 1, "DataFetcher: INVALID_AMOUNTS_A");
        (uint256 reserveA, uint256 reserveB) = getReserves(factory, tokenA, tokenB);
        amountsB = new uint256[](amountsA.length);

        for (uint256 i = 0 ; i < amountsA.length ; i++) {
            require(amountsA[i] > 0, "DataFetcher: INSUFFICIENT_AMOUNT");
            amountsB[i] = (amountsA[i] * reserveB) / reserveA;
        }
    }

    function quoteRouted(
        address factory,
        uint256 amountA,
        address[] memory path
    ) internal view returns (uint256 amountB) {
        require(amountA > 0, "DataFetcher: INSUFFICIENT_AMOUNT");
        require(path.length >= 2, "DataFetcher: INVALID_PATH");
        uint256[] memory amounts = new uint256[](path.length);
        amounts[0] = amountA;

        for (uint256 i = 0 ; i < path.length - 1 ; i++) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = (amounts[i] * reserveOut) / reserveIn;
        }
        amountB = amounts[path.length - 1];
    }
}
pragma solidity ^0.8.0;

import "../interfaces/IERC20.sol";
import "../interfaces/IERC20Permit.sol";
import "./Address.sol";

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
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}
pragma solidity ^0.8.0;

library SafeETH {

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));

        require(success, "SafeETH::safeTransferETH: ETH transfer failed");
    }
}
pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}
