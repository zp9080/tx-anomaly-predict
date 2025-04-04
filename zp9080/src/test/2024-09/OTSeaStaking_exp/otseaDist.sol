pragma solidity =0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/libraries/OTSeaErrors.sol";
import "contracts/token/OTSeaStaking.sol";

/**
 * @notice OTSea ETH revenue distributor
 * @dev This contract collects revenue (in ETH) from v1 token fees and from the platform and distributes to stakes
 * periodically.
 *
 * The minimum distribution period between distributions is set in the contract by the minInterval variable. By default
 * this is set to 6 days 23 hours and 59 minutes, this is so that a CRON job can call this function approximately
 * every 7 days.
 *
 * To avoid this contract being fully centralized, any user can call the distribute() function (provided the minimum
 * period has been met), meaning that revenue can always be paid to stakers.
 */
contract OTSeaRevenueDistributor is Ownable {
    uint256 private constant MINIMUM_DISTRIBUTION = 0.0001 ether;
    uint256 private constant MINIMUM_STAKE = 1 ether;
    uint24 private constant MIN_EPOCH_TIME = 1 days;
    uint24 private constant MAX_EPOCH_TIME = 30 days;
    uint24 public minInterval = 7 days - 1 minutes;
    OTSeaStaking public stakingContract;

    error AlreadyInitialized();
    error NotInitialized();

    event Initialized(address stakingContract);
    event MinDistributionIntervalUpdated(uint24 time);

    /// @param _multiSigAdmin Multi-sig admin
    constructor(address _multiSigAdmin) Ownable(_multiSigAdmin) {}

    /**
     * @notice Initialize the contract
     * @param _stakingContract Staking contract
     */
    function initialize(OTSeaStaking _stakingContract) external onlyOwner {
        if (isInitialized()) revert AlreadyInitialized();
        if (address(_stakingContract) == address(0)) revert OTSeaErrors.InvalidAddress();
        stakingContract = _stakingContract;
        emit Initialized(address(_stakingContract));
    }

    /**
     * @notice Set the minimum interval between distributions
     * @param _time Minimum duration between distributions (in seconds, with a range between 1 - 30 days)
     */
    function setMinDistributionInterval(uint24 _time) external onlyOwner {
        if (_time < MIN_EPOCH_TIME || MAX_EPOCH_TIME < _time) revert OTSeaErrors.InvalidAmount();
        minInterval = _time;
        emit MinDistributionIntervalUpdated(_time);
    }

    /**
     * @notice Distribute all ETH in this contract to stakers in the stakingContract contract
     * @dev Anyone can call distribute after the first epoch has been ended by the owner, therefore a
     * minimum time interval is enforced
     */
    function distribute() external {
        if (!isInitialized()) revert NotInitialized();
        (uint32 epochNumber, OTSeaStaking.Epoch memory epoch) = stakingContract.getCurrentEpoch();
        if (epochNumber == 1) {
            if (msg.sender != stakingContract.owner()) revert OTSeaErrors.Unauthorized();
        } else if (block.timestamp < epoch.startedAt + minInterval) {
            revert OTSeaErrors.NotAvailable();
        }
        uint256 balance = address(this).balance;
        if (balance < MINIMUM_DISTRIBUTION || epoch.totalStake < MINIMUM_STAKE) {
            stakingContract.skipEpoch();
        } else {
            stakingContract.distribute{value: balance}();
        }
    }

    /**
     * @notice Check if the contract is initialized
     * @return bool true if initialized, false if not
     */
    function isInitialized() public view returns (bool) {
        return address(stakingContract) != address(0);
    }

    receive() external payable {}
}
pragma solidity ^0.8.20;

import {Context} from "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
pragma solidity ^0.8.20;

/**
 * @dev Standard ERC20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in EIP-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}
pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
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
     *
     * CAUTION: See Security Considerations above.
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
pragma solidity ^0.8.20;

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
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
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
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}
pragma solidity ^0.8.20;

import {IERC20} from "../IERC20.sol";
import {IERC20Permit} from "../extensions/IERC20Permit.sol";
import {Address} from "../../../utils/Address.sol";

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

    /**
     * @dev An operation with an ERC20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
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

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
}
pragma solidity ^0.8.20;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

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
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {FailedInnerCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}
pragma solidity ^0.8.20;

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

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}File 9 of 14 : IUniswapV2Router01.solpragma solidity >=0.6.2;

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
}File 10 of 14 : IUniswapV2Router02.solpragma solidity >=0.6.2;

import './IUniswapV2Router01.sol';

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
pragma solidity =0.8.20;

import "contracts/libraries/OTSeaErrors.sol";

/// @title A list helper contract
abstract contract ListHelper {
    uint16 internal constant LOOP_LIMIT = 500;
    bool internal constant ALLOW_ZERO = true;
    bool internal constant DISALLOW_ZERO = false;

    error InvalidStart();
    error InvalidEnd();
    error InvalidSequence();

    /**
     * @param _start Start
     * @param _end End
     * @param _total List total
     * @param _allowZero true - zero is a valid start or end, false - zero is an invalid start or end
     */
    modifier onlyValidSequence(
        uint256 _start,
        uint256 _end,
        uint256 _total,
        bool _allowZero
    ) {
        _checkSequence(_start, _end, _total, _allowZero);
        _;
    }

    /**
     * @param _start Start
     * @param _end End
     * @param _total Total
     * @param _allowZero true - zero is a valid start or end, false - zero is an invalid start or end
     * @dev check that a range of indexes is valid.
     */
    function _checkSequence(
        uint256 _start,
        uint256 _end,
        uint256 _total,
        bool _allowZero
    ) private pure {
        if (_allowZero) {
            if (_start >= _total) revert InvalidStart();
            if (_end >= _total) revert InvalidEnd();
        } else {
            if (_start == 0 || _start > _total) revert InvalidStart();
            if (_end == 0 || _end > _total) revert InvalidEnd();
        }
        if (_start > _end) revert InvalidStart();
        if (_end - _start + 1 > LOOP_LIMIT) revert InvalidSequence();
    }

    /// @dev _length List length
    function _validateListLength(uint256 _length) internal pure {
        if (_length == 0 || LOOP_LIMIT < _length) revert OTSeaErrors.InvalidArrayLength();
    }
}
pragma solidity =0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "contracts/libraries/OTSeaErrors.sol";

/// @title A transfer helper contract for ETH and tokens
contract TransferHelper is Context {
    using SafeERC20 for IERC20;

    /// @dev account -> Amount of ETH that failed to transfer
    mapping(address => uint256) private _maroonedETH;

    error NativeTransferFailed();

    event MaroonedETH(address account, uint256 amount);
    event MaroonedETHClaimed(address account, address receiver, uint256 amount);

    /**
     * @notice Claim marooned ETH
     * @param _receiver Address to receive the marooned ETH
     */
    function claimMaroonedETH(address _receiver) external {
        if (_receiver == address(0)) revert OTSeaErrors.InvalidAddress();
        uint256 amount = _maroonedETH[_msgSender()];
        if (amount == 0) revert OTSeaErrors.NotAvailable();
        _maroonedETH[_msgSender()] = 0;
        _transferETHOrRevert(_receiver, amount);
        emit MaroonedETHClaimed(_msgSender(), _receiver, amount);
    }

    /**
     * @notice Get the amount of marooned ETH for an account
     * @param _account Account to check
     * @return uint256 Marooned ETH
     */
    function getMaroonedETH(address _account) external view returns (uint256) {
        if (_account == address(0)) revert OTSeaErrors.InvalidAddress();
        return _maroonedETH[_account];
    }

    /**
     * @param _account Account to transfer ETH to
     * @param _amount Amount of ETH to transfer to _account
     * @dev Rather than reverting if the transfer fails, the _amount is stored for the _account to later claim
     */
    function _safeETHTransfer(address _account, uint256 _amount) internal {
        (bool success, ) = _account.call{value: _amount}("");
        if (!success) {
            _maroonedETH[_account] += _amount;
            emit MaroonedETH(_account, _amount);
        }
    }

    /**
     * @param _account Account to transfer ETH to
     * @param _amount Amount of ETH to transfer to _account
     * @dev The following will revert if the transfer fails
     */
    function _transferETHOrRevert(address _account, uint256 _amount) internal {
        (bool success, ) = _account.call{value: _amount}("");
        if (!success) revert NativeTransferFailed();
    }

    /**
     * @param _token Token to transfer into the contract from msg.sender
     * @param _amount Amount of _token to transfer
     * @return uint256 Actual amount transferred into the contract
     * @dev This function exists due to _token potentially having taxes
     */
    function _transferInTokens(IERC20 _token, uint256 _amount) internal returns (uint256) {
        uint256 balanceBefore = _token.balanceOf(address(this));
        _token.safeTransferFrom(_msgSender(), address(this), _amount);
        return _token.balanceOf(address(this)) - balanceBefore;
    }
}
pragma solidity =0.8.20;

/// @title Common OTSea errors
library OTSeaErrors {
    error InvalidAmount();
    error InvalidAddress();
    error InvalidIndex(uint256 index);
    error InvalidAmountAtIndex(uint256 index);
    error InvalidAddressAtIndex(uint256 index);
    error DuplicateAddressAtIndex(uint256 index);
    error AddressNotFoundAtIndex(uint256 index);
    error Unauthorized();
    error ExpectationMismatch();
    error InvalidArrayLength();
    error InvalidFee();
    error NotAvailable();
    error InvalidPurchase();
    error InvalidETH(uint256 expected);
    error Unchanged();
}
pragma solidity =0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "contracts/helpers/ListHelper.sol";
import "contracts/helpers/TransferHelper.sol";
import "contracts/libraries/OTSeaErrors.sol";

/**
 * @title OTSea Staking Contract
 * @dev This contract enables users to stake tokens and earn rewards from v1 token fees and platform revenue.
 * It initiates a new epoch with each reward distribution. Users who stake during an epoch do not receive rewards
 * for that epoch, preventing exploitation through immediate pre-reward staking and withdrawal.
 * Similarly, users withdrawing their stake in any epoch forfeit rewards that would be distributed at the end of
 * the epoch. Rewards are calculated pro-rata based on the token amount staked in each epoch.
 *
 * If the revenue for distribution is less than 0.0001 ETH or if the total staked tokens are fewer than 1, the current
 * epoch is skipped. No rewards are distributed in this case, and the accumulated revenue is carried over to the
 * next epoch.
 */
contract OTSeaStaking is Ownable, TransferHelper, ListHelper {
    using SafeERC20 for IERC20;

    struct Deposit {
        /**
         * @dev rewardReferenceEpoch represents the reference point that rewards should be based off of.
         *  - Upon depositing it is set to the currentEpoch + 1.
         *  - Upon claiming rewards it is set to the currentEpoch
         *  - Upon withdrawing it is set to 0
         */
        uint32 rewardReferenceEpoch;
        uint88 amount;
    }

    struct Epoch {
        uint168 startedAt;
        uint88 totalStake;
        uint256 sharePerToken;
    }

    IUniswapV2Router02 private constant _router =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    uint256 private constant REWARD_PRECISION = 10e38;
    address private immutable _revenueDistributor;
    bool public isDepositingAllowed;
    uint32 private _currentEpoch = 1;
    IERC20 private _otseaERC20;
    mapping(address => Deposit[]) private _deposits;
    mapping(uint32 => Epoch) private _epochs;

    error NoRewards();
    error InvalidEpoch();
    error DepositNotFound(uint256 index);

    event Initialized(address token);
    event ToggledDepositing(bool isDepositingAllowed);
    event Deposited(address indexed account, uint256 indexed index, Deposit deposit);
    event Withdrawal(
        address indexed account,
        address indexed receiver,
        uint256[] indexes,
        uint88 amount
    );
    event Claimed(
        address indexed account,
        address indexed receiver,
        uint256[] indexes,
        uint256 amount
    );
    event Compounded(
        address indexed account,
        uint256[] indexes,
        uint256 amountSwapped,
        uint256 indexed newDepositIndex,
        Deposit deposit
    );
    event EpochEnded(uint32 indexed id, Epoch epoch, uint256 distributed);

    modifier onlyRevenueDistributor() {
        _isCallerRevenueDistributor();
        _;
    }

    /**
     * @param _multiSigAdmin Multi-sig admin
     * @param revenueDistributor_ Revenue distributor contract
     */
    constructor(address _multiSigAdmin, address revenueDistributor_) Ownable(_multiSigAdmin) {
        if (address(revenueDistributor_) == address(0)) revert OTSeaErrors.InvalidAddress();
        _revenueDistributor = revenueDistributor_;
    }

    /**
     * @notice Initialize and start the first epoch
     * @param _token Token
     */
    function initialize(IERC20 _token) external onlyOwner {
        if (address(_token) == address(0)) revert OTSeaErrors.InvalidAddress();
        if (_isInitialized()) revert OTSeaErrors.NotAvailable();
        _otseaERC20 = _token;
        _epochs[1].startedAt = uint168(block.timestamp);
        emit Initialized(address(_token));
    }

    /// @notice Toggle depositing
    function toggleDepositing() external onlyOwner {
        if (!_isInitialized()) revert OTSeaErrors.NotAvailable();
        isDepositingAllowed = !isDepositingAllowed;
        emit ToggledDepositing(isDepositingAllowed);
    }

    /// @notice Distribute ETH to stakers (only revenue distributor)
    function distribute() external payable onlyRevenueDistributor {
        uint32 currentEpoch = _currentEpoch;
        uint256 sharePerToken = (REWARD_PRECISION * msg.value) / _epochs[currentEpoch].totalStake;
        _epochs[currentEpoch].sharePerToken += sharePerToken;
        _nextEpoch();
        emit EpochEnded(currentEpoch, _epochs[currentEpoch], msg.value);
    }

    /// @notice Skip epoch (only revenue distributor)
    function skipEpoch() external onlyRevenueDistributor {
        uint32 currentEpoch = _currentEpoch;
        _nextEpoch();
        emit EpochEnded(currentEpoch, _epochs[currentEpoch], 0);
    }

    /**
     * @notice Stake OTSea tokens and earn ETH
     * @param _amount OTSea amount
     */
    function stake(uint88 _amount) external {
        if (!isDepositingAllowed) revert OTSeaErrors.NotAvailable();
        if (_amount == 0) revert OTSeaErrors.InvalidAmount();
        _checkSufficientAmount(_amount);
        /**
         * @dev current deposit index = _deposits[_msgSender()].length - 1, therefore if we add 1 to get the next index
         * it cancels out with the "-1" to just give _deposits[_msgSender()].length
         */
        Deposit memory deposit = _createDeposit(_amount);
        _otseaERC20.safeTransferFrom(_msgSender(), address(this), uint256(_amount));
        emit Deposited(_msgSender(), _deposits[_msgSender()].length - 1, deposit);
    }

    /**
     * @notice Withdraw multiple deposits as well as claim their rewards
     * @param _indexes A list of deposit IDs to withdraw
     * @param _receiver Address to receive the tokens and ETH
     */
    function withdraw(uint256[] calldata _indexes, address _receiver) external {
        if (_receiver == address(0)) revert OTSeaErrors.InvalidAddress();
        (uint88 totalAmount, uint256 totalRewards) = _withdrawMultiple(_indexes);
        if (totalRewards != 0) {
            _transferETHOrRevert(_receiver, totalRewards);
            emit Claimed(_msgSender(), _receiver, _indexes, totalRewards);
        }
        _otseaERC20.safeTransfer(_receiver, uint256(totalAmount));
        emit Withdrawal(_msgSender(), _receiver, _indexes, totalAmount);
    }

    /**
     * @notice Claim rewards for multiple deposits
     * @param _indexes A list of deposit IDs to claim
     * @param _receiver Address to receive ETH
     */
    function claim(uint256[] calldata _indexes, address _receiver) external {
        if (_receiver == address(0)) revert OTSeaErrors.InvalidAddress();
        uint256 totalRewards = _claimMultiple(_indexes);
        _transferETHOrRevert(_receiver, totalRewards);
        emit Claimed(_msgSender(), _receiver, _indexes, totalRewards);
    }

    /**
     * @notice Compound rewards by swapping ETH for tokens and creating a new deposit
     * @param _indexes A list of deposit IDs to compound
     * @param _amountToSwap Amount of rewards (ETH) to swap for tokens, left over rewards are sent to _remainderReceiver
     * @param _minTokenAmount Minimum token amount to receive when swapping _amountToSwap
     * @param _remainderReceiver Address to receive any remaining rewards (can be the zero address if amountToSwap
     * is equal to the total rewards for _indexes)
     * @dev The staking contract is exempt from buy fees making compounding fee-free
     */
    function compound(
        uint256[] calldata _indexes,
        uint256 _amountToSwap,
        uint88 _minTokenAmount,
        address _remainderReceiver
    ) external {
        if (_amountToSwap == 0 || _minTokenAmount == 0) revert OTSeaErrors.InvalidAmount();
        uint256 totalRewards = _claimMultiple(_indexes);
        if (totalRewards < _amountToSwap) revert OTSeaErrors.InvalidAmount();
        uint256 remaining = totalRewards - _amountToSwap;
        if (remaining != 0) {
            if (_remainderReceiver == address(0)) revert OTSeaErrors.InvalidAddress();
            _transferETHOrRevert(_remainderReceiver, remaining);
            emit Claimed(_msgSender(), _remainderReceiver, _indexes, remaining);
        }
        uint88 tokens = _swapETHForTokens(_amountToSwap, _minTokenAmount);
        Deposit memory deposit = _createDeposit(tokens);
        emit Compounded(
            _msgSender(),
            _indexes,
            _amountToSwap,
            _deposits[_msgSender()].length - 1,
            deposit
        );
    }

    /**
     * @notice Get details about an epoch
     * @param _epoch Epoch ID (must be greater than 0 and not greater than the current epoch + 1)
     * @return Epoch Epoch details
     */
    function getEpoch(uint32 _epoch) external view returns (Epoch memory) {
        if (_epoch == 0 || _currentEpoch + 1 < _epoch) revert InvalidEpoch();
        return _epochs[_epoch];
    }

    /**
     * @notice Get the current epoch ID and details
     * @return uint32 Epoch ID
     * @return Epoch Epoch details
     */
    function getCurrentEpoch() external view returns (uint32, Epoch memory) {
        return (_currentEpoch, _epochs[_currentEpoch]);
    }

    /**
     * @notice Get the total deposits by a user
     * @param _account Account
     * @return total Total deposits by _account
     */
    function getTotalDeposits(address _account) public view returns (uint256 total) {
        if (_account == address(0)) revert OTSeaErrors.InvalidAddress();
        return _deposits[_account].length;
    }

    /**
     * @notice Get a deposit for a user by index
     * @param _account Account
     * @param _index Index of deposit
     * @return Deposit Deposit belonging to _account at index _index
     */
    function getDeposit(address _account, uint256 _index) external view returns (Deposit memory) {
        if (getTotalDeposits(_account) <= _index) revert DepositNotFound(_index);
        return _deposits[_account][_index];
    }

    /**
     * @notice Get a list of deposits for a user in a sequence from an start index to an end index (inclusive)
     * @param _account Account
     * @param _startIndex Start deposit index
     * @param _endIndex End deposit index
     * @return deposits A list of deposits for _account within the range of _startIndex and _endIndex (inclusive)
     */
    function getDepositsInSequence(
        address _account,
        uint256 _startIndex,
        uint256 _endIndex
    )
        external
        view
        onlyValidSequence(_startIndex, _endIndex, getTotalDeposits(_account), ALLOW_ZERO)
        returns (Deposit[] memory deposits)
    {
        deposits = new Deposit[](_endIndex - _startIndex + 1);
        uint256 index;
        uint256 depositIndex = _startIndex;
        for (depositIndex; depositIndex <= _endIndex; ) {
            deposits[index] = _deposits[_account][depositIndex];
            unchecked {
                index++;
                depositIndex++;
            }
        }
        return deposits;
    }

    /**
     * @notice Get a list of deposits for a user by providing a list
     * @param _account Account
     * @param _indexes A list of deposit indexes
     * @return deposits A list of deposits for _account based on the _indexes provided
     */
    function getDepositsByList(
        address _account,
        uint256[] calldata _indexes
    ) external view returns (Deposit[] memory deposits) {
        uint256 length = _indexes.length;
        _validateListLength(length);
        uint256 total = getTotalDeposits(_account);
        deposits = new Deposit[](length);
        for (uint256 i; i < length; ) {
            if (total <= _indexes[i]) revert DepositNotFound(_indexes[i]);
            deposits[i] = _deposits[_account][_indexes[i]];
            unchecked {
                i++;
            }
        }
        return deposits;
    }

    /**
     * @notice Calculate rewards for a user
     * @param _account Account
     * @param _indexes A list of deposit indexes
     * @return rewards Total rewards for _account based on the _indexes list
     */
    function calculateRewards(
        address _account,
        uint256[] calldata _indexes
    ) external view returns (uint256 rewards) {
        uint256 length = _indexes.length;
        _validateListLength(length);
        uint256 total = getTotalDeposits(_account);
        for (uint256 i; i < length; ) {
            if (total <= _indexes[i]) revert DepositNotFound(_indexes[i]);
            rewards += _calculateRewards(_account, _indexes[i]);
            unchecked {
                i++;
            }
        }
        return rewards;
    }

    function _nextEpoch() private {
        /// @dev sets the current epoch = the current while updating state to the next one
        uint32 nextEpoch = ++_currentEpoch;
        _epochs[nextEpoch].startedAt = uint88(block.timestamp);
        _epochs[nextEpoch].sharePerToken = _epochs[nextEpoch - 1].sharePerToken;
        _epochs[nextEpoch].totalStake += _epochs[nextEpoch - 1].totalStake;
    }

    /**
     * @param _amount Amount to deposit
     * @return deposit Deposit details
     */
    function _createDeposit(uint88 _amount) private returns (Deposit memory deposit) {
        uint32 nextEpoch = _currentEpoch + 1;
        deposit = Deposit(nextEpoch, _amount);
        _deposits[_msgSender()].push(deposit);
        _epochs[nextEpoch].totalStake += _amount;
        return deposit;
    }

    /**
     * @param _indexes A list of deposit indexes
     * @return totalAmount Total amount to withdraw based on _indexes
     * @return totalRewards Total amount of rewards based on _indexes
     */
    function _withdrawMultiple(
        uint256[] calldata _indexes
    ) private returns (uint88 totalAmount, uint256 totalRewards) {
        uint256 length = _indexes.length;
        _validateListLength(length);
        uint256 total = getTotalDeposits(_msgSender());
        uint32 currentEpoch = _currentEpoch;
        for (uint256 i; i < length; ) {
            if (total <= _indexes[i]) revert DepositNotFound(_indexes[i]);
            totalRewards += _calculateRewards(_msgSender(), _indexes[i]);
            Deposit memory deposit = _deposits[_msgSender()][_indexes[i]];
            if (deposit.rewardReferenceEpoch == 0) revert OTSeaErrors.NotAvailable();
            _deposits[_msgSender()][_indexes[i]].rewardReferenceEpoch = 0;
            /**
             * @dev if the rewardReferenceEpoch is in the future, it means that the user deposited in the current
             * epoch (currentEpoch). Therefore next epoch's total stake needs to be reduced by the user's deposit.
             *
             * If the rewardReferenceEpoch is less than or equal to the currentEpoch it means that the user
             * either deposited or claimed rewards in a past epoch. Either way it means that the user's
             * deposit cannot possible be in the future therefore the current epoch's total stake needs to be reduced
             */
            _epochs[
                currentEpoch < deposit.rewardReferenceEpoch
                    ? deposit.rewardReferenceEpoch
                    : currentEpoch
            ].totalStake -= deposit.amount;
            totalAmount += deposit.amount;
            unchecked {
                i++;
            }
        }
        return (totalAmount, totalRewards);
    }

    /**
     * @param _indexes A list of deposit indexes
     * @return totalRewards Total amount of rewards based on _indexes
     */
    function _claimMultiple(uint256[] calldata _indexes) private returns (uint256 totalRewards) {
        uint256 length = _indexes.length;
        _validateListLength(length);
        uint256 total = getTotalDeposits(_msgSender());
        uint32 currentEpoch = _currentEpoch;
        for (uint256 i; i < length; ) {
            if (total <= _indexes[i]) revert DepositNotFound(_indexes[i]);
            totalRewards += _calculateRewards(_msgSender(), _indexes[i]);
            _deposits[_msgSender()][_indexes[i]].rewardReferenceEpoch = currentEpoch;
            unchecked {
                i++;
            }
        }
        if (totalRewards == 0) revert NoRewards();
        return totalRewards;
    }

    /**
     * @param _amountToSwap Amount of ETH to swap for tokens
     * @param _minTokenAmount Minimum token amount to receive when swapping _amountToSwap
     * @return uint88 Tokens received
     */
    function _swapETHForTokens(
        uint256 _amountToSwap,
        uint88 _minTokenAmount
    ) private returns (uint88) {
        address[] memory path = new address[](2);
        path[0] = _router.WETH();
        path[1] = address(_otseaERC20);
        uint256[] memory amounts = _router.swapExactETHForTokens{value: _amountToSwap}(
            uint256(_minTokenAmount),
            path,
            address(this),
            block.timestamp
        );
        return uint88(amounts[1]);
    }

    /**
     * @param _account Account
     * @param _index Deposit index belonging to _account
     * @return uint256 Rewards accumulated by _account for deposit _index
     */
    function _calculateRewards(address _account, uint256 _index) private view returns (uint256) {
        uint32 rewardReferenceEpoch = _deposits[_account][_index].rewardReferenceEpoch;
        if (rewardReferenceEpoch == 0 || _currentEpoch <= rewardReferenceEpoch) {
            return 0;
        }
        return
            (_deposits[_account][_index].amount *
                (_epochs[_currentEpoch - 1].sharePerToken -
                    _epochs[rewardReferenceEpoch - 1].sharePerToken)) / REWARD_PRECISION;
    }

    /// @param _amount Amount
    function _checkSufficientAmount(uint88 _amount) private view {
        if (_otseaERC20.balanceOf(_msgSender()) < _amount)
            revert IERC20Errors.ERC20InsufficientBalance(
                _msgSender(),
                _otseaERC20.balanceOf(_msgSender()),
                uint256(_amount)
            );
        if (_otseaERC20.allowance(_msgSender(), address(this)) < _amount)
            revert IERC20Errors.ERC20InsufficientAllowance(
                address(this),
                _otseaERC20.allowance(_msgSender(), address(this)),
                uint256(_amount)
            );
    }

    /// @return bool true if initialized, false if not
    function _isInitialized() private view returns (bool) {
        return address(_otseaERC20) != address(0);
    }

    function _isCallerRevenueDistributor() private view {
        if (_msgSender() != _revenueDistributor) revert OTSeaErrors.Unauthorized();
    }
}
