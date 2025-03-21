pragma solidity =0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "contracts/helpers/TransferHelper.sol";
import "contracts/libraries/OTSeaErrors.sol";
import "contracts/libraries/OTSeaLibrary.sol";
import "contracts/token/OTSeaMigration.sol";
import "contracts/token/OTSeaRevenueDistributor.sol";
import "contracts/token/OTSeaStaking.sol";

/**
 * @title OTSea v1 ERC20 Token Overview
 * @dev This ERC20 token, part of OTSea's v1, includes specific fees for buy/sell/transfer operations:
 * - Burn Fee: A portion of tokens from each transaction is sent to the dead address.
 * - Revenue Boost Fee: A portion of tokens from each transaction is accumulated in the contract. Once over a
 *   "swap threshold", these tokens are converted to Ethereum (ETH) during sell transactions.
 *
 * All revenue fees from the token and the platform are sent to a revenue distributor contract that periodically
 * distributes fees to stakers.
 *
 * The token is managed by a multi-signature wallet, with the following capabilities:
 * - Add Initial Liquidity: Add initial liquidity into a Uniswap V2 pool.
 * - Fee Adjustment: Alter or lower the fee percentages. Note: fee increases are not permitted.
 * - Swap Threshold Management: Update the threshold for the Revenue Boost Fee conversion into ETH, within a range
 *   of 1,000 to 100,000 tokens.
 * - Transfer Fee Toggling: Can enable or disable fees on transfer. Note that this doesn't affect buy/sell fees.
 * - Transfer Fee Whitelisting: Can exempt specific addresses from paying the transfer fees. Note that this doesn't
 *   affect buy/sell fees.
 *
 * The owner, migration contract, and staking contract are permanently exempt from transfer fees. If the ownership
 * is transferred to another wallet, the new owner also becomes transfer fee exempt. The previous owner remains transfer
 * fee exempt and the new owner can decide whether or not to remove their transfer fee exempt status.
 */
contract OTSeaERC20 is Ownable, ERC20, TransferHelper {
    IUniswapV2Router02 private constant _router =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    uint88 private constant TOTAL_SUPPLY = 100_000_000 ether;
    uint88 private constant MIN_SWAP_AT = 1_000 ether;
    uint88 private constant MAX_SWAP_AT = 100_000 ether;
    OTSeaMigration public immutable migrationContract;
    OTSeaStaking public immutable stakingContract;
    OTSeaRevenueDistributor public immutable revenueDistributor;
    bool public isTransferFeeEnabled = true;
    /// @dev Revenue boost fee is initially set to 2% of the transaction
    uint16 private _revBoostFeePercent = 200;
    /// @dev Treasury fee is initially set to 2% of the transaction
    uint16 private _treasuryFeePercent = 200;
    /// @dev Burn fee is initially set to 0% of the transaction
    uint16 private _burnFeePercent = 0;
    /// @dev Threshold at which the collected revenue boost fees are swapped to ETH and sent to the revenue distributor
    uint88 private _swapAt = 5_000 ether;
    address private _pair;
    mapping(address => bool) public isExemptFromTransferFee;

    event AddedLiquidity(address pair, uint256 token, uint256 eth);
    event FeesUpdated(uint16 revBoostFeePercent, uint16 treasuryFeePercent, uint16 burnFeePercent);
    event SwapAtUpdated(uint256 swapAt);
    event TransferFeeToggled(bool isTransferFeeEnabled);
    event TransferFeeWhitelistUpdated(address indexed account, bool whitelisted);
    event Burned(uint256 amount);
    event DistributedETHFees(uint256 revBoost, uint256 treasury);

    modifier whenFeeIsSet() {
        _checkIfFeeIsSet();
        _;
    }

    /**
     * @param _multiSigAdmin Multi-sig admin
     * @param _migrationContract Migration contract
     * @param _stakingContract Staking contract
     * @param _revenueDistributor Revenue distributor
     */
    constructor(
        address _multiSigAdmin,
        OTSeaMigration _migrationContract,
        OTSeaStaking _stakingContract,
        OTSeaRevenueDistributor _revenueDistributor
    ) ERC20("OTSea", "OTSea") Ownable(_multiSigAdmin) {
        if (
            address(_migrationContract) == address(0) ||
            address(_stakingContract) == address(0) ||
            address(_revenueDistributor) == address(0)
        ) revert OTSeaErrors.InvalidAddress();
        if (
            _migrationContract.multiSigAdmin() != _multiSigAdmin ||
            _stakingContract.owner() != _multiSigAdmin ||
            _revenueDistributor.owner() != _multiSigAdmin
        ) revert OwnableInvalidOwner(_multiSigAdmin);
        migrationContract = _migrationContract;
        stakingContract = _stakingContract;
        revenueDistributor = _revenueDistributor;
        isExemptFromTransferFee[address(_migrationContract)] = true;
        isExemptFromTransferFee[_multiSigAdmin] = true;
        isExemptFromTransferFee[address(_stakingContract)] = true;
        _mint(address(_migrationContract), TOTAL_SUPPLY);
    }

    /**
     * @notice Enter the sea
     * @param _amount Amount of OTSea to add to the initial liquidity
     */
    function enterTheSea(uint256 _amount) external payable onlyOwner {
        if (_pair != address(0)) revert OTSeaErrors.NotAvailable();
        if (_amount == 0 || msg.value == 0) revert OTSeaErrors.InvalidAmount();
        super._update(_msgSender(), address(this), _amount);
        _approve(address(this), address(_router), _amount);
        /// @dev multi-sig admin receives initial LP
        _router.addLiquidityETH{value: msg.value}(
            address(this),
            _amount,
            0,
            0,
            owner(),
            block.timestamp
        );
        address uniswapV2Pair = IUniswapV2Factory(_router.factory()).getPair(
            address(this),
            _router.WETH()
        );
        _pair = uniswapV2Pair;
        emit AddedLiquidity(_pair, _amount, msg.value);
    }

    /**
     * @notice Update the fee percents
     * @param revBoostFeePercent_ Rev boost fee percent (2 d.p. e.g. 1% = 100)
     * @param treasuryFeePercent_ Treasury fee percent (2 d.p. e.g. 1% = 100)
     * @param burnFeePercent_ Burn fee percent (2 d.p. e.g. 1% = 100)
     */
    function updateFees(
        uint16 revBoostFeePercent_,
        uint16 treasuryFeePercent_,
        uint16 burnFeePercent_
    ) external onlyOwner whenFeeIsSet {
        uint16 totalFeePercent = _getTotalFeePercent();
        uint16 newTotalFeePercent = revBoostFeePercent_ + treasuryFeePercent_ + burnFeePercent_;
        if (totalFeePercent < newTotalFeePercent) revert OTSeaErrors.InvalidFee();
        if (newTotalFeePercent == 0) {
            uint256 balance = balanceOf(address(this));
            if (balance != 0) {
                _sendToDeadAddress(address(this), balance);
            }
            delete isTransferFeeEnabled;
            delete _swapAt;
        }
        _revBoostFeePercent = revBoostFeePercent_;
        _treasuryFeePercent = treasuryFeePercent_;
        _burnFeePercent = burnFeePercent_;
        emit FeesUpdated(revBoostFeePercent_, treasuryFeePercent_, burnFeePercent_);
    }

    /**
     * @notice Update the swap at threshold at which the collected fees for rev boost and treasury get swapped for ETH
     * and distributed
     * @param _amount Amount of tokens required to trigger the swap
     */
    function updateSwapAt(uint88 _amount) external onlyOwner whenFeeIsSet {
        if (_amount < MIN_SWAP_AT || MAX_SWAP_AT < _amount) revert OTSeaErrors.InvalidAmount();
        _swapAt = _amount;
        emit SwapAtUpdated(_amount);
    }

    /// @notice Toggle transfer fee
    function toggleTransferFee() external onlyOwner whenFeeIsSet {
        isTransferFeeEnabled = !isTransferFeeEnabled;
        emit TransferFeeToggled(isTransferFeeEnabled);
    }

    /**
     * @notice Update the transfer fee whitelist
     * @param _account Account
     * @param _operation add (true) or remove (false) "account" to/from the whitelist
     */
    function updateTransferFeeWhitelist(
        address _account,
        bool _operation
    ) external onlyOwner whenFeeIsSet {
        if (_isSpecialAddress(_account)) revert OTSeaErrors.InvalidAddress();
        if (isExemptFromTransferFee[_account] == _operation) revert OTSeaErrors.Unchanged();
        _updateTransferFeeWhitelist(_account, _operation);
    }

    /**
     * @notice Get the pair address
     * @return address Pair
     */
    function getPair() external view returns (address) {
        if (_pair == address(0)) revert OTSeaErrors.NotAvailable();
        return _pair;
    }

    /**
     * @notice Get fee details
     * @return swapAt Swap at threshold where collected fees get swapped for ETH and distributed
     * @return revBoostPercent Rev boost percent
     * @return treasuryFeePercent Treasury percent
     * @return burnPercent Burn percent
     */
    function getFeeDetails()
        external
        view
        returns (
            uint256 swapAt,
            uint16 revBoostPercent,
            uint16 treasuryFeePercent,
            uint16 burnPercent
        )
    {
        return (_swapAt, _revBoostFeePercent, _treasuryFeePercent, _burnFeePercent);
    }

    /**
     * @param _from From address
     * @param _to To address
     * @param _value Value
     * @dev Overrides ERC20's _update() function in order to handle fees and disable trading prior to adding liquidity
     */
    function _update(address _from, address _to, uint256 _value) internal override {
        /**
         * @dev the following if statement works as follows:
         * - _from == address(this): makes _swapAndDistributeFees tax free
         * - _pair == address(0) && _isSpecialAddress(_from): is for when the liquidity hasn't been added yet, only
         *   special addresses are allowed to transfer
         */
        if (_from == address(this) || (_pair == address(0) && _isSpecialAddress(_from))) {
            super._update(_from, _to, _value);
            return;
        }
        if (_pair == address(0)) {
            revert OTSeaErrors.Unauthorized();
        }
        uint256 totalFee = _getTotalFeePercent();
        if (totalFee != 0) {
            if (_to == _pair && _swapAt <= balanceOf(address(this))) {
                /// @dev For sell transactions once over the threshold the contract will swap tokens for ETH
                _swapAndDistributeFees();
            }
            if (_shouldChargeFee(_from, _to)) {
                /// @dev more gas efficient passing in the totalFee than fetching it again in _takeFee()
                _value = _takeFee(totalFee, _from, _value);
            }
        }
        /// @dev buy, sell and transfers
        super._update(_from, _to, _value);
    }

    /// @param _newOwner New owner
    function _transferOwnership(address _newOwner) internal override {
        /**
         * @dev Cannot check _isSpecialAddress(_newOwner) because _transferOwnership() is called in the constructor
         * of this contract and _isSpecialAddress() contains immutable variables. Therefore we just simply only set the
         * new owner to be transfer fee exempt if it is not the zero address which is relevant if renounceOwnership()
         * is called.
         */
        if (_newOwner != address(0)) {
            _updateTransferFeeWhitelist(_newOwner, true);
        }
        super._transferOwnership(_newOwner);
    }

    /**
     * @param _totalFee Total fee
     * @param _from From address
     * @param _value Value
     * @return uint256 Value after fees
     */
    function _takeFee(uint256 _totalFee, address _from, uint256 _value) private returns (uint256) {
        /// @dev calculate fee
        uint256 fee = (_value * _totalFee) / OTSeaLibrary.PERCENT_DENOMINATOR;
        uint256 burnFee = (fee * _burnFeePercent) / _totalFee;
        if (burnFee != 0) {
            /// @dev tokens are burned immediately
            _sendToDeadAddress(_from, burnFee);
        }
        /// @dev ethFee is for the rev share boost and treasury fees (if configured)
        uint256 ethFee = fee - burnFee;
        if (ethFee != 0) {
            /// @dev tokens are stored in the contract to be later swapped for ETH
            super._update(_from, address(this), ethFee);
        }
        return _value - fee;
    }

    function _swapAndDistributeFees() private {
        /// @dev slightly cheaper in gas setting _treasuryFeePercent to a local variable
        uint256 treasuryFeePercent = _treasuryFeePercent;
        uint256 total = treasuryFeePercent + _revBoostFeePercent;
        /// @dev swaps tokens for ETH and transfers to the revenueDistributor
        uint256 eth = _swapTokensForETH();
        uint256 treasury = (eth * treasuryFeePercent) / total;
        uint256 revBoost = eth - treasury;
        if (revBoost != 0) {
            _safeETHTransfer(address(revenueDistributor), revBoost);
        }
        if (treasury != 0) {
            _safeETHTransfer(owner(), treasury);
        }
        emit DistributedETHFees(revBoost, treasury);
    }

    /// @return uint256 ETH received
    function _swapTokensForETH() private returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _router.WETH();
        /// @dev sell the _swapAt amount rather than the total balance
        uint256 amount = uint256(_swapAt);
        _approve(address(this), address(_router), amount);
        uint256 ethBalanceBefore = address(this).balance;
        _router.swapExactTokensForETH(amount, 0, path, address(this), block.timestamp);
        return address(this).balance - ethBalanceBefore;
    }

    /**
     * @param _from From address
     * @param _amount Amount of tokens to send to the dead address
     */
    function _sendToDeadAddress(address _from, uint256 _amount) private {
        super._update(_from, OTSeaLibrary.DEAD_ADDRESS, _amount);
        emit Burned(_amount);
    }

    /**
     * @param _account Account
     * @param _operation add (true) or remove (false) "account" to/from the whitelist
     */
    function _updateTransferFeeWhitelist(address _account, bool _operation) private {
        isExemptFromTransferFee[_account] = _operation;
        emit TransferFeeWhitelistUpdated(_account, _operation);
    }

    /**
     * @param _account Account
     * @return bool true if _account is a special address, false if not
     */
    function _isSpecialAddress(address _account) private view returns (bool) {
        return
            _account == address(migrationContract) ||
            _account == owner() ||
            _account == address(stakingContract) ||
            _account == address(0);
    }

    /**
     * @param _from From address
     * @param _to To address
     * @return bool true if a fee should be charged, false if not
     * @dev Checks whether a fee should be charged. The logic works as follows:
     * - Buy fees are always charged unless the buyer is the staking contract
     * - Sell fees are always charged
     * - Transfer fees are charged if the transfer fee is enabled and neither the _from nor _to address are transfer
     *   fee exempt
     */
    function _shouldChargeFee(address _from, address _to) private view returns (bool) {
        return
            (_from == _pair && _to != address(stakingContract)) ||
            _to == _pair ||
            (isTransferFeeEnabled &&
                !isExemptFromTransferFee[_from] &&
                !isExemptFromTransferFee[_to]);
    }

    function _checkIfFeeIsSet() private view {
        if (_getTotalFeePercent() == 0) revert OTSeaErrors.NotAvailable();
    }

    /// @return uint16 Total fee percent
    function _getTotalFeePercent() private view returns (uint16) {
        return _revBoostFeePercent + _treasuryFeePercent + _burnFeePercent;
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

import {IERC20} from "./IERC20.sol";
import {IERC20Metadata} from "./extensions/IERC20Metadata.sol";
import {Context} from "../../utils/Context.sol";
import {IERC20Errors} from "../../interfaces/draft-IERC6093.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 */
abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     * ```
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}
pragma solidity ^0.8.20;

import {IERC20} from "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
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
}
pragma solidity ^0.8.20;

/**
 * @dev These functions deal with verification of Merkle Tree proofs.
 *
 * The tree and the proofs can be generated using our
 * https://github.com/OpenZeppelin/merkle-tree[JavaScript library].
 * You will find a quickstart guide in the readme.
 *
 * WARNING: You should avoid using leaf values that are 64 bytes long prior to
 * hashing, or use a hash function other than keccak256 for hashing leaves.
 * This is because the concatenation of a sorted pair of internal nodes in
 * the Merkle tree could be reinterpreted as a leaf value.
 * OpenZeppelin's JavaScript library generates Merkle trees that are safe
 * against this attack out of the box.
 */
library MerkleProof {
    /**
     *@dev The multiproof provided is not valid.
     */
    error MerkleProofInvalidMultiproof();

    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    /**
     * @dev Calldata version of {verify}
     */
    function verifyCalldata(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        return processProofCalldata(proof, leaf) == root;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. When processing the proof, the pairs
     * of leafs & pre-images are assumed to be sorted.
     */
    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @dev Calldata version of {processProof}
     */
    function processProofCalldata(bytes32[] calldata proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @dev Returns true if the `leaves` can be simultaneously proven to be a part of a Merkle tree defined by
     * `root`, according to `proof` and `proofFlags` as described in {processMultiProof}.
     *
     * CAUTION: Not all Merkle trees admit multiproofs. See {processMultiProof} for details.
     */
    function multiProofVerify(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    ) internal pure returns (bool) {
        return processMultiProof(proof, proofFlags, leaves) == root;
    }

    /**
     * @dev Calldata version of {multiProofVerify}
     *
     * CAUTION: Not all Merkle trees admit multiproofs. See {processMultiProof} for details.
     */
    function multiProofVerifyCalldata(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    ) internal pure returns (bool) {
        return processMultiProofCalldata(proof, proofFlags, leaves) == root;
    }

    /**
     * @dev Returns the root of a tree reconstructed from `leaves` and sibling nodes in `proof`. The reconstruction
     * proceeds by incrementally reconstructing all inner nodes by combining a leaf/inner node with either another
     * leaf/inner node or a proof sibling node, depending on whether each `proofFlags` item is true or false
     * respectively.
     *
     * CAUTION: Not all Merkle trees admit multiproofs. To use multiproofs, it is sufficient to ensure that: 1) the tree
     * is complete (but not necessarily perfect), 2) the leaves to be proven are in the opposite order they are in the
     * tree (i.e., as seen from right to left starting at the deepest layer and continuing at the next layer).
     */
    function processMultiProof(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32[] memory leaves
    ) internal pure returns (bytes32 merkleRoot) {
        // This function rebuilds the root hash by traversing the tree up from the leaves. The root is rebuilt by
        // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
        // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
        // the Merkle tree.
        uint256 leavesLen = leaves.length;
        uint256 proofLen = proof.length;
        uint256 totalHashes = proofFlags.length;

        // Check proof validity.
        if (leavesLen + proofLen != totalHashes + 1) {
            revert MerkleProofInvalidMultiproof();
        }

        // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
        // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;
        // At each step, we compute the next hash using two values:
        // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
        //   get the next hash.
        // - depending on the flag, either another value from the "main queue" (merging branches) or an element from the
        //   `proof` array.
        for (uint256 i = 0; i < totalHashes; i++) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b = proofFlags[i]
                ? (leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++])
                : proof[proofPos++];
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            if (proofPos != proofLen) {
                revert MerkleProofInvalidMultiproof();
            }
            unchecked {
                return hashes[totalHashes - 1];
            }
        } else if (leavesLen > 0) {
            return leaves[0];
        } else {
            return proof[0];
        }
    }

    /**
     * @dev Calldata version of {processMultiProof}.
     *
     * CAUTION: Not all Merkle trees admit multiproofs. See {processMultiProof} for details.
     */
    function processMultiProofCalldata(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32[] memory leaves
    ) internal pure returns (bytes32 merkleRoot) {
        // This function rebuilds the root hash by traversing the tree up from the leaves. The root is rebuilt by
        // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
        // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
        // the Merkle tree.
        uint256 leavesLen = leaves.length;
        uint256 proofLen = proof.length;
        uint256 totalHashes = proofFlags.length;

        // Check proof validity.
        if (leavesLen + proofLen != totalHashes + 1) {
            revert MerkleProofInvalidMultiproof();
        }

        // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
        // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;
        // At each step, we compute the next hash using two values:
        // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
        //   get the next hash.
        // - depending on the flag, either another value from the "main queue" (merging branches) or an element from the
        //   `proof` array.
        for (uint256 i = 0; i < totalHashes; i++) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b = proofFlags[i]
                ? (leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++])
                : proof[proofPos++];
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            if (proofPos != proofLen) {
                revert MerkleProofInvalidMultiproof();
            }
            unchecked {
                return hashes[totalHashes - 1];
            }
        } else if (leavesLen > 0) {
            return leaves[0];
        } else {
            return proof[0];
        }
    }

    /**
     * @dev Sorts the pair (a, b) and hashes the result.
     */
    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    /**
     * @dev Implementation of keccak256(abi.encode(a, b)) that doesn't allocate or expand memory.
     */
    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}File 12 of 21 : IUniswapV2Factory.solpragma solidity >=0.5.0;

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
}File 13 of 21 : IUniswapV2Router01.solpragma solidity >=0.6.2;

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
}File 14 of 21 : IUniswapV2Router02.solpragma solidity >=0.6.2;

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

/// @title Common OTSea variables
library OTSeaLibrary {
    enum FeeType {
        Fish,
        Whale
    }

    uint16 internal constant PERCENT_DENOMINATOR = 10000;
    address internal constant DEAD_ADDRESS = address(0xdead);
}
pragma solidity =0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "contracts/helpers/ListHelper.sol";
import "contracts/helpers/TransferHelper.sol";
import "contracts/libraries/OTSeaErrors.sol";
import "contracts/libraries/OTSeaLibrary.sol";

/**
 * @notice OTSea one-way beta -> v1 migration contract
 * @dev This contract facilitates the migration from the current (beta) token to the new v1 token.
 *
 * Migration steps:
 * 1. The team coordinate whales to approve the smart contract.
 * 2. The team will take a snapshot of the holder's balances of the beta token and generate a merkle tree. From this
 * merkle tree we can get the root.
 * 3. The root is uploaded into the contract (can only be done once).
 * 4. The team uses the smart contract to sell the approved tokens in Step 1, with the aim of gathering as much ETH
 *    as possible so that it can be used to fund the v1 liquidity pool. All whales participating receive a credit as
 *    opposed to receiving the v1 token straight away.
 * 5. The team deploys and adds the v1 token address in the contract. The purpose of not deploying the v1 contract in a
 *    prior step is because Etherscan will show that the OTSea deployer has deployed a new token which could affect the
 *    amount of ETH received in Step 4 (depending on if the community sees the new token deployed).
 * 6. Upon configuring the v1 token, users can then migrate their tokens from the beta token to the v1 token using
 *    a merkle proof via the migrate() function (on the dApp). The coordinated whales that received a credit in Step 4
 *    can claim their v1 tokens via the claimCredit() function. Also the team can claim tokens for addresses that can't
 *    claim for themselves, these are known as special addresses.
 *
 * The following addresses are special address:
 * - OTSeaERC20: 0x37DA9DE38c4094e090c014325f6eF4baEB302626
 * - Dead address: 0x000000000000000000000000000000000000dEaD
 * - OTSea (platform): 0x28A2F7849f0a2BCCf1F5D246cEf5a6867A5BFa23
 * - Uniswap V2 pair (OTSea/WETH): 0xd46934919D9138d3005C1f8Db794f03E7415bAbD
 *
 * Note: Any tokens in the current (beta) OTSea (platform) contract will be claimed by the team (as per Step 6) and
 * manually transferred to the relevant order creator(s).
 */
contract OTSeaMigration is Ownable, TransferHelper, ListHelper {
    using SafeERC20 for IERC20;

    struct Migration {
        address wallet;
        /// @dev amount to migrate
        uint256 amount;
        /// @dev amount recorded on snapshot (used to reconstruct the leaf)
        uint256 snapshot;
        bytes32[] proof;
    }

    IUniswapV2Router02 private constant _router =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address private constant BETA_PAIR_ADDRESS = 0xd46934919D9138d3005C1f8Db794f03E7415bAbD;
    address private constant BETA_OTSEA_PLATFORM = 0x28A2F7849f0a2BCCf1F5D246cEf5a6867A5BFa23;
    IERC20 private constant _beta = IERC20(0x37DA9DE38c4094e090c014325f6eF4baEB302626);
    uint24 private constant MIGRATION_PERIOD = 90 days;
    address public immutable multiSigAdmin;
    IERC20 public v1;
    address public treasury;
    bool public hasLiquidityBeenExtracted;
    uint32 public migrationDeadline;
    bytes32 public merkleRoot;
    mapping(address => uint256) private _migrated;
    mapping(address => uint256) private _credit;

    error InvalidRoot();
    error InvalidProof();
    error InvalidMinETHAmount();
    error AmountExceedsSnapshot();
    error RootNotUploaded();

    event MerkleRootUploaded(bytes32 root);
    event Migrated(address indexed account, Migration migration);
    event CreditClaimed(address indexed account, uint256 credit);
    event V1TokenConfigured(address token, uint32 migrationDeadline);
    event ExtractedLiquidity(Migration[] migrations, uint256 amountSold, uint256 ethReceived);
    event SoldBetaTokens(uint256 amountSold, uint256 ethReceived);
    event ClaimedUnclaimedV1Tokens(uint256 amount);

    modifier canMigrate() {
        _checkCanMigrate();
        _;
    }

    modifier afterRootUploaded() {
        _checkRootUploaded();
        _;
    }

    /**
     * @param _multiSigAdmin Multi-sig admin
     * @param _migrationHandler Migration handler
     */
    constructor(address _multiSigAdmin, address _migrationHandler) Ownable(_migrationHandler) {
        if (_multiSigAdmin == address(0)) revert OTSeaErrors.InvalidAddress();
        multiSigAdmin = _multiSigAdmin;
    }

    /**
     * @notice Upload the merkle root, can only be uploaded once
     * @param _merkleRoot Merkle root
     */
    function uploadMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        if (_isRootUploaded()) revert OTSeaErrors.NotAvailable();
        if (_merkleRoot == bytes32(0)) revert InvalidRoot();
        merkleRoot = _merkleRoot;
        emit MerkleRootUploaded(_merkleRoot);
    }

    /**
     * @notice Extract liquidity by selling tokens from whales that have approved this contract
     * @param _migrations Migrations
     * @param _minETHAmount Minimum ETH to receive from selling
     * @dev this function can only be called once
     */
    function extractLiquidity(
        Migration[] calldata _migrations,
        uint256 _minETHAmount
    ) external onlyOwner afterRootUploaded {
        if (hasLiquidityBeenExtracted) revert OTSeaErrors.NotAvailable();
        uint256 length = _migrations.length;
        _validateListLength(length);
        if (_minETHAmount == 0) revert InvalidMinETHAmount();
        hasLiquidityBeenExtracted = true;
        uint256 betaBalanceBefore = _beta.balanceOf(address(this));
        for (uint256 i; i < length; ) {
            if (_migrations[i].wallet == address(0)) revert OTSeaErrors.InvalidAddressAtIndex(i);
            if (_credit[_migrations[i].wallet] != 0) revert OTSeaErrors.DuplicateAddressAtIndex(i);
            _validateMigration(_migrations[i]);
            _checkSufficientAmount(_migrations[i]);
            _credit[_migrations[i].wallet] = _migrations[i].amount;
            _beta.safeTransferFrom(_migrations[i].wallet, address(this), _migrations[i].amount);
            unchecked {
                i++;
            }
        }
        uint256 amountToSell = _beta.balanceOf(address(this)) - betaBalanceBefore;
        uint256 ethReceived = _sell(amountToSell, _minETHAmount);
        emit ExtractedLiquidity(_migrations, amountToSell, ethReceived);
    }

    /**
     * @notice Configure the contract to add the v1 token, doing so will allow users to migrate
     * @param _token Token Migrations
     * @dev this function can only be called once
     */
    function configureV1Token(IERC20 _token) external onlyOwner {
        /// @dev Liquidity has to have been extracted first, v1 cannot already be configured
        if (!hasLiquidityBeenExtracted || address(v1) != address(0))
            revert OTSeaErrors.NotAvailable();
        if (address(_token) == address(0)) revert OTSeaErrors.InvalidAddress();
        v1 = _token;
        /// @dev Set the deadline for migration to be 90 days after the v1 token has been configured
        migrationDeadline = uint32(block.timestamp + MIGRATION_PERIOD);
        emit V1TokenConfigured(address(_token), migrationDeadline);
    }

    /**
     * @notice Claim v1 tokens for special addresses
     * @param _specialMigrations Special migrations
     */
    function claimSpecialAddresses(
        Migration[] calldata _specialMigrations
    ) external onlyOwner canMigrate {
        uint256 length = _specialMigrations.length;
        _validateListLength(length);
        uint256 totalAmount;
        for (uint256 i; i < length; ) {
            Migration calldata migration = _specialMigrations[i];
            if (
                migration.wallet == address(_beta) ||
                migration.wallet == BETA_PAIR_ADDRESS ||
                migration.wallet == BETA_OTSEA_PLATFORM ||
                migration.wallet == OTSeaLibrary.DEAD_ADDRESS
            ) {
                _validateMigration(migration);
                _migrated[migration.wallet] += migration.amount;
                totalAmount += migration.amount;
                emit Migrated(migration.wallet, migration);
            } else {
                /// @dev revert due to _specialMigrations containing a migration for a non-special wallet
                revert OTSeaErrors.InvalidAddressAtIndex(i);
            }
            unchecked {
                i++;
            }
        }
        /// @dev special addresses do not receive their tokens and instead the multi-sig receives them
        v1.safeTransfer(multiSigAdmin, totalAmount);
    }

    /// @notice Claim v1 credit (only for users that took part in the liquidity extraction)
    function claimCredit() external canMigrate {
        uint256 credit = _credit[_msgSender()];
        if (credit == 0) revert OTSeaErrors.NotAvailable();
        _credit[_msgSender()] = 0;
        /// @dev update _migrated[_msgSender()] so that they cannot reclaim the credit amount using migrate()
        _migrated[_msgSender()] += credit;
        v1.safeTransfer(_msgSender(), credit);
        emit CreditClaimed(_msgSender(), credit);
    }

    /**
     * @notice Swap beta tokens for ETH, to be used by the owner
     * @param _amountToSell Amount of beta tokens to sell
     * @param _minETHAmount Minimum ETH to receive from selling
     */
    function sellBetaTokens(uint256 _amountToSell, uint256 _minETHAmount) external onlyOwner {
        if (_amountToSell == 0 || _beta.balanceOf(address(this)) < _amountToSell)
            revert OTSeaErrors.InvalidAmount();
        if (_minETHAmount == 0) revert InvalidMinETHAmount();
        uint256 ethReceived = _sell(_amountToSell, _minETHAmount);
        emit SoldBetaTokens(_amountToSell, ethReceived);
    }

    /// @notice After 90 days, any unclaimed tokens are available to be claimed by the multi-sig admin
    function claimUnclaimedV1Tokens() external {
        if (_msgSender() != multiSigAdmin) revert OTSeaErrors.Unauthorized();
        if (address(v1) == address(0)) revert OTSeaErrors.NotAvailable();
        uint256 amountToClaim = v1.balanceOf(address(this));
        /// @dev If the deadline has not been reached yet or it has but the amount to claim is 0, it reverts
        if (!_isDeadlineReached() || amountToClaim == 0) revert OTSeaErrors.NotAvailable();
        v1.safeTransfer(multiSigAdmin, amountToClaim);
        emit ClaimedUnclaimedV1Tokens(amountToClaim);
    }

    /**
     * @notice Migrate beta -> v1 tokens provided a valid merkle proof is present
     * @param _migration Migration
     */
    function migrate(Migration calldata _migration) external canMigrate {
        /// @dev if credit is owed it must first be claimed
        if (_credit[_msgSender()] != 0) revert OTSeaErrors.NotAvailable();
        if (_migration.wallet != _msgSender()) revert OTSeaErrors.Unauthorized();
        _validateMigration(_migration);
        _checkSufficientAmount(_migration);
        _migrate(_migration);
    }

    /**
     * @notice Get the amount migrated by an address
     * @param _account Account
     * @return uint256 Amount migrated by _account
     */
    function getMigratedAmountByAddress(address _account) external view returns (uint256) {
        return _migrated[_account];
    }

    /**
     * @notice Get the amount of v1 credit owed to an address
     * @param _account Account
     * @return uint256 Amount of credited owed to _account
     */
    function getCreditAmountByAddress(address _account) external view returns (uint256) {
        return _credit[_account];
    }

    /// @param _migration Migration
    function _migrate(Migration calldata _migration) private {
        _migrated[_migration.wallet] += _migration.amount;
        _beta.safeTransferFrom(_migration.wallet, address(this), _migration.amount);
        v1.safeTransfer(_migration.wallet, _migration.amount);
        emit Migrated(_migration.wallet, _migration);
    }

    /**
     * @param _amountToSell Amount of beta tokens to sell
     * @param _minETHAmount Minimum ETH to receive from selling
     * @return received Amount of ETH received for selling _amountToSell beta tokens
     */
    function _sell(uint _amountToSell, uint _minETHAmount) private returns (uint256 received) {
        address[] memory path = new address[](2);
        path[0] = address(_beta);
        path[1] = _router.WETH();
        _beta.forceApprove(address(_router), _amountToSell);
        uint256 ethBefore = multiSigAdmin.balance;
        _router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            _amountToSell,
            _minETHAmount,
            path,
            multiSigAdmin,
            block.timestamp
        );
        received = multiSigAdmin.balance - ethBefore;
    }

    /// @param _migration Migration
    function _validateMigration(Migration calldata _migration) private view {
        if (_migration.proof.length == 0) revert InvalidProof();
        if (_migration.amount == 0 || _migration.snapshot == 0) revert OTSeaErrors.InvalidAmount();
        if (_migration.snapshot < _migrated[_migration.wallet] + _migration.amount)
            revert AmountExceedsSnapshot();
        bytes32 leaf = keccak256(abi.encodePacked(_migration.wallet, _migration.snapshot));
        bool isValidProof = MerkleProof.verifyCalldata(_migration.proof, merkleRoot, leaf);
        if (!isValidProof) revert InvalidProof();
    }

    /// @param _migration Migration
    function _checkSufficientAmount(Migration calldata _migration) private view {
        if (_beta.balanceOf(_migration.wallet) < _migration.amount)
            revert IERC20Errors.ERC20InsufficientBalance(
                _migration.wallet,
                _beta.balanceOf(_migration.wallet),
                _migration.amount
            );
        if (_beta.allowance(_migration.wallet, address(this)) < _migration.amount)
            revert IERC20Errors.ERC20InsufficientAllowance(
                address(this),
                _beta.allowance(_migration.wallet, address(this)),
                _migration.amount
            );
    }

    function _checkCanMigrate() private view {
        /// @dev check if the token has been configured and the deadline has not been reached
        if (address(v1) == address(0) || _isDeadlineReached()) revert OTSeaErrors.NotAvailable();
    }

    function _checkRootUploaded() private view {
        if (!_isRootUploaded()) revert RootNotUploaded();
    }

    /// @return bool true if the deadline has been reached, false if not
    function _isDeadlineReached() private view returns (bool) {
        return migrationDeadline < block.timestamp;
    }

    /// @return bool true if root has been uploaded, false if not
    function _isRootUploaded() private view returns (bool) {
        return merkleRoot != bytes32(0);
    }
}
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
