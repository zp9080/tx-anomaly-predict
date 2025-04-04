pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/ICvgControlTower.sol";

/// @title Cvg-Finance - CVG
/// @notice Convergence ERC20 token ($CVG)
contract Cvg is ERC20 {
    uint256 public constant MAX_PARTNERS = 685_000 * 10 ** 18;
    uint256 public constant MAX_AIRDROP = 1_848_560 * 10 ** 18;
    uint256 public constant MAX_VESTING = 39_466_440 * 10 ** 18;
    uint256 public constant MAX_BOND = 48_000_000 * 10 ** 18;
    uint256 public constant MAX_STAKING = 60_000_000 * 10 ** 18;

    /// @dev convergence ecosystem address
    ICvgControlTower public immutable cvgControlTower;

    /// @dev amount of tokens minted through bond contracts
    uint256 public mintedBond;

    /// @dev amount of tokens minted through staking contracts
    uint256 public mintedStaking;

    constructor(
        ICvgControlTower _cvgControlTower,
        address _vestingCvg,
        address _airdrop,
        address _partners
    ) ERC20("Convergence", "CVG") {
        _mint(_vestingCvg, MAX_VESTING);
        _mint(_airdrop, MAX_AIRDROP);
        _mint(_partners, MAX_PARTNERS);
        cvgControlTower = _cvgControlTower;
    }

    /**
     * @notice mint function for bond contracts
     * @param account address receiving the tokens
     * @param amount amount of tokens to mint
     */
    function mintBond(address account, uint256 amount) external {
        require(cvgControlTower.isBond(msg.sender), "NOT_BOND");
        uint256 newMintedBond = mintedBond + amount;
        require(newMintedBond <= MAX_BOND, "MAX_SUPPLY_BOND");

        mintedBond = newMintedBond;
        _mint(account, amount);
    }

    /**
     * @notice mint function for staking contracts
     * @param account address receiving the tokens
     * @param amount amount of tokens to mint
     */
    function mintStaking(address account, uint256 amount) external {
        require(cvgControlTower.isStakingContract(msg.sender), "NOT_STAKING");
        uint256 _mintedStaking = mintedStaking;
        require(_mintedStaking < MAX_STAKING, "MAX_SUPPLY_STAKING");

        /// @dev ensure every tokens will be minted from staking
        uint256 newMintedStaking = _mintedStaking + amount;
        if (newMintedStaking > MAX_STAKING) {
            newMintedStaking = MAX_STAKING;
            amount = MAX_STAKING - _mintedStaking;
        }

        mintedStaking = newMintedStaking;
        _mint(account, amount);
    }

    /**
     * @notice burn tokens
     * @param amount amount of tokens to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  function getRoundData(
    uint80 _roundId
  ) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}
pragma solidity ^0.8.0;

}
pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
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
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

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
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
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
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
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
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
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
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}
pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
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

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}
pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
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
pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
pragma solidity ^0.8.0;

import "./IBondStruct.sol";

interface IBondCalculator {
    function computeRoi(
        uint256 durationFromStart,
        uint256 totalDuration,
        IBondStruct.BondFunction composedFunction,
        uint256 totalTokenOut,
        uint256 amountTokenSold,
        uint256 gamma,
        uint256 scale,
        uint256 minRoi,
        uint256 maxRoi
    ) external pure returns (uint256 bondRoi);
}
pragma solidity ^0.8.0;

import "./ICvgControlTower.sol";
import "./IBondStruct.sol";
import "./ICvgOracle.sol";

interface IBondDepository {
    // Deposit Principle token in Treasury through Bond contract
    function deposit(uint256 tokenId, uint256 amount, address receiver) external;

    function depositToLock(uint256 amount, address receiver) external returns (uint256 cvgToMint);

    function positionInfos(uint256 tokenId) external view returns (IBondStruct.BondPending memory);

    function getTokenVestingInfo(uint256 tokenId) external view returns (IBondStruct.TokenVestingInfo memory);

    function bondParams() external view returns (IBondStruct.BondParams memory);

    function pendingPayoutFor(uint256 tokenId) external view returns (uint256);
}
pragma solidity 0.8.17;

interface IBondLogo {
    struct LogoInfos {
        uint256 tokenId;
        uint256 termTimestamp;
        uint256 pending;
        uint256 cvgClaimable;
        uint256 unlockingTimestamp;
    }
    struct LogoInfosFull {
        uint256 tokenId;
        uint256 termTimestamp;
        uint256 pending;
        uint256 cvgClaimable;
        uint256 unlockingTimestamp;
        uint256 year;
        uint256 month;
        uint256 day;
        bool isLocked;
        uint256 hoursLock;
        uint256 cvgPrice;
    }

    function _tokenURI(LogoInfos memory logoInfos) external pure returns (string memory output);

    
    function getLogoInfo(uint256 tokenId) external view returns (IBondLogo.LogoInfosFull memory);
}
pragma solidity ^0.8.0;

import "./IBondStruct.sol";
import "./IBondLogo.sol";
import "./IBondDepository.sol";

interface IBondPositionManager {
    function bondDepository() external view returns (IBondDepository);

    function getTokenIdsForWallet(address _wallet) external view returns (uint256[] memory);

    function bondPerTokenId(uint256 tokenId) external view returns (uint256);

    // Deposit Principle token in Treasury through Bond contract
    function mintOrCheck(uint256 bondId, uint256 tokenId, address receiver) external returns (uint256);

    function burn(uint256 tokenId) external;

    function unlockingTimestampPerToken(uint256 tokenId) external view returns (uint256);

    function logoInfo(uint256 tokenId) external view returns (IBondLogo.LogoInfos memory);

    function checkTokenRedeem(uint256[] calldata tokenIds, address receiver) external view;
}
pragma solidity ^0.8.0;

interface IBondStruct {
    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        STORED STRUCTS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    struct BondParams {
        /**
         * @dev Type of function used to compute the actual ROI of a bond.
         *      - 0 is SquareRoot
         *      - 1 is Ln
         *      - 2 is Square
         *      - 3 is Linear
         */
        BondFunction composedFunction;
        /// @dev Address of the underlaying token of the bond.
        address token;
        /**
         * @dev Gamma is used in the BondCalculator.It's the value dividing the ratio between the amount already sold and the theorical amount sold.
         *      250_000 correspond to 0.25 (25%).
         */
        uint40 gamma;
        /// @dev Total duration of the bond, uint40 is enough for a timestamp.
        uint40 bondDuration;
        /// @dev Determine if a Bond is paused. Can't deposit on a bond paused.
        bool isPaused;
        /**
         * @dev Scale is used in the BondCalculator. When a scale is A, the ROI vary by incremental of A.
         *      If scale is 5_000 correspond to 0.5%, the ROI will vary from the maxROI to minROI by increment of 0.5%.
         */
        uint32 scale;
        /**
         * @dev Minimum ROI of the bond. Discount cannot be less than the minROI.
         *      If minRoi is 100_000, it represents 10%.
         */

        uint24 minRoi;
        /**
         * @dev Maximum ROI of the bond. Discount cannot be more than the maxROI.
         *      If maxRoi is 150_000, it represents 15%.
         */
        uint24 maxRoi;
        /**
         * @dev Percentage maximum of the cvgToSell that an user can buy in one deposit
         *      If percentageOneTx is 200, it represents 20% of cvgToSell.
         */
        uint24 percentageOneTx;
        /// @dev Duration of the vesting in second.
        uint32 vestingTerm;
        /**
         * @dev Maximum amount that can be bought through this bond.
         *      uint80 represents 1.2M tokens in ethers. It means that we are never going to open a bond with more than 1.2M tokens.
         */
        uint80 cvgToSell; // Limit of Max CVG to sell => 1.2M CVG max approx
        /// @dev Timestamp in second of the beginning of the bond. Has to be in the future.
        uint40 startBondTimestamp;
    }
    struct BondPending {
        /// @dev Timestamp in second of the last interaction with this position.
        uint64 lastTimestamp;
        /// @dev Time in seconds lefting before the position is fully unvested
        uint64 vestingTimeLeft;
        /**
         * @dev Total amount of CVG still vested in the position.
         *      uint128 is way enough because it's an amount in CVG that have a max supply of 150M tokens.
         */
        uint128 leftClaimable;
    }

    enum BondFunction {
        SQRT,
        LN,
        POWER_2,
        LINEAR
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        VIEW STRUCTS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    struct BondTokenView {
        uint128 lastTimestamp;
        uint128 vestingEnd;
        uint256 claimableCvg;
        uint256 leftClaimable;
    }

    struct BondView {
        uint256 actualRoi;
        uint256 cvgAlreadySold;
        uint256 usdExecutionPrice;
        uint256 usdLimitPrice;
        uint256 assetBondPrice;
        uint256 usdBondPrice;
        bool isOracleValid;
        BondParams bondParameters;
        ERC20View token;
    }
    struct ERC20View {
        string token;
        address tokenAddress;
        uint256 decimals;
    }
    struct TokenVestingInfo {
        uint256 term;
        uint256 claimable;
        uint256 pending;
    }
}
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICommonStruct {
    struct TokenAmount {
        IERC20 token;
        uint256 amount;
    }
}
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

interface ICvg is IERC20Metadata {
    function MAX_AIRDROP() external view returns (uint256);

    function MAX_BOND() external view returns (uint256);

    function MAX_STAKING() external view returns (uint256);

    function MAX_VESTING() external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function burn(uint256 amount) external;

    function cvgControlTower() external view returns (address);

    function decimals() external view returns (uint8);

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

    function mintBond(address account, uint256 amount) external;

    function mintStaking(address account, uint256 amount) external;

    function mintedBond() external view returns (uint256);

    function mintedStaking() external view returns (uint256);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./IERC20Mintable.sol";
import "./ICvg.sol";
import "./IBondDepository.sol";
import "./IBondCalculator.sol";
import "./IBondStruct.sol";
import "./ICvgOracle.sol";
import "./IVotingPowerEscrow.sol";
import "./ICvgRewards.sol";
import "./ILockingPositionManager.sol";
import "./ILockingPositionDelegate.sol";
import "./IGaugeController.sol";
import "./IYsDistributor.sol";
import "./IBondPositionManager.sol";
import "./ISdtStakingPositionManager.sol";
import "./IBondLogo.sol";
import "./ILockingLogo.sol";
import "./ILockingPositionService.sol";
import "./IVestingCvg.sol";
import "./ISdtBuffer.sol";
import "./ISdtBlackHole.sol";
import "./ISdtStakingPositionService.sol";
import "./ISdtFeeCollector.sol";
import "./ISdtBuffer.sol";
import "./ISdtRewardDistributor.sol";

interface ICvgControlTower {
    function cvgToken() external view returns (ICvg);

    function cvgOracle() external view returns (ICvgOracle);

    function bondCalculator() external view returns (IBondCalculator);

    function gaugeController() external view returns (IGaugeController);

    function cvgCycle() external view returns (uint128);

    function votingPowerEscrow() external view returns (IVotingPowerEscrow);

    function treasuryDao() external view returns (address);

    function treasuryPod() external view returns (address);

    function treasuryPdd() external view returns (address);

    function treasuryAirdrop() external view returns (address);

    function treasuryTeam() external view returns (address);

    function cvgRewards() external view returns (ICvgRewards);

    function lockingPositionManager() external view returns (ILockingPositionManager);

    function lockingPositionService() external view returns (ILockingPositionService);

    function lockingPositionDelegate() external view returns (ILockingPositionDelegate);

    function isStakingContract(address contractAddress) external view returns (bool);

    function ysDistributor() external view returns (IYsDistributor);

    function isBond(address account) external view returns (bool);

    function bondPositionManager() external view returns (IBondPositionManager);

    function sdtStakingPositionManager() external view returns (ISdtStakingPositionManager);

    function sdtStakingLogo() external view returns (ISdtStakingLogo);

    function bondLogo() external view returns (IBondLogo);

    function lockingLogo() external view returns (ILockingLogo);

    function isSdtStaking(address contractAddress) external view returns (bool);

    function vestingCvg() external view returns (IVestingCvg);

    function sdt() external view returns (IERC20);

    function cvgSDT() external view returns (IERC20Mintable);

    function cvgSdtStaking() external view returns (ISdtStakingPositionService);

    function cvgSdtBuffer() external view returns (ISdtBuffer);

    function veSdtMultisig() external view returns (address);

    function cloneFactory() external view returns (address);

    function sdtUtilities() external view returns (address);

    function insertNewSdtStaking(address _sdtStakingClone) external;

    function allBaseSdAssetStaking(uint256 _index) external view returns (address);

    function allBaseSdAssetBuffer(uint256 _index) external view returns (address);

    function sdtFeeCollector() external view returns (ISdtFeeCollector);

    function updateCvgCycle() external;

    function sdtBlackHole() external view returns (ISdtBlackHole);

    function sdtRewardDistributor() external view returns (address);

    function poolCvgSdt() external view returns (address);

    function bondDepository() external view returns (address);
}
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./IOracleStruct.sol";

interface ICvgOracle {
    function getPriceVerified(address erc20) external view returns (uint256);

    function getPriceUnverified(address erc20) external view returns (uint256);

    function getAndVerifyTwoPrices(address tokenIn, address tokenOut) external view returns (uint256, uint256);

    function getTwoPricesAndIsValid(
        address tokenIn,
        address tokenOut
    ) external view returns (uint256, uint256, bool, uint256, uint256, bool);

    function getPriceAndValidationData(
        address erc20Address
    ) external view returns (uint256, uint256, bool, bool, bool, bool);

    function getPoolAddressByToken(address erc20) external view returns (address);

    function poolTypePerErc20(address) external view returns (IOracleStruct.PoolType);

    //OWNER

    function setPoolTypeForToken(address _erc20Address, IOracleStruct.PoolType _poolType) external;

    function setStableParams(address _erc20Address, IOracleStruct.StableParams calldata _stableParams) external;

    function setCurveDuoParams(address _erc20Address, IOracleStruct.CurveDuoParams calldata _curveDuoParams) external;

    function setCurveTriParams(address _erc20Address, IOracleStruct.CurveTriParams calldata _curveTriParams) external;

    function setUniV3Params(address _erc20Address, IOracleStruct.UniV3Params calldata _uniV3Params) external;

    function setUniV2Params(address _erc20Address, IOracleStruct.UniV2Params calldata _uniV2Params) external;
}
pragma solidity ^0.8.0;

interface ICvgRewards {
    function cvgCycleRewards() external view returns (uint256);

    function addGauge(address gaugeAddress) external;

    function removeGauge(address gaugeAddress) external;

    function getCycleLocking(uint256 timestamp) external view returns (uint256);
}
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

/**
 * @dev Interface for the optional mint function from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Mintable is IERC20Metadata {
    /**
     * @dev Mint `amount` of token to `account`
     */
    function mint(address account, uint256 amount) external;
}
pragma solidity ^0.8.0;

interface IGaugeController {
    struct WeightType {
        uint256 weight;
        uint256 type_weight;
        int128 gauge_type;
    }

    function add_type(string memory typeName, uint256 weight) external;

    function add_gauge(address addr, int128 gaugeType, uint256 weight) external;

    function get_gauge_weight(address gaugeAddress) external view returns (uint256);

    function get_gauge_weights(address[] memory gaugeAddresses) external view returns (uint256[] memory, uint256);

    function get_gauge_weights_and_types(address[] memory gaugeAddresses) external view returns (WeightType[] memory);

    function get_total_weight() external view returns (uint256);

    function n_gauges() external view returns (uint128);

    function gauges(uint256 index) external view returns (address);

    function gauge_types(address gaugeAddress) external view returns (int128);

    function get_type_weight(int128 typeId) external view returns (uint256);

    function gauge_relative_weight(address addr, uint256 time) external view returns (uint256);

    function set_lock(bool isLock) external;

    function gauge_relative_weight_write(address gaugeAddress) external;

    function gauge_relative_weight_writes(uint256 from, uint256 length) external;

    function simple_vote(uint256 tokenId, address gaugeAddress, uint256 tokenWeight) external;
}
pragma solidity ^0.8.0;

interface ILockingLogo {
    struct LogoInfos {
        uint256 tokenId;
        uint256 cvgLocked;
        uint256 lockEnd;
        uint256 ysPercentage;
        uint256 mgCvg;
        uint256 unlockingTimestamp;
    }
    struct GaugePosition {
        uint256 ysWidth; // width of the YS gauge part
        uint256 veWidth; // width of the VE gauge part
    }

    struct LogoInfosFull {
        uint256 tokenId;
        uint256 cvgLocked;
        uint256 lockEnd;
        uint256 ysPercentage;
        uint256 mgCvg;
        uint256 unlockingTimestamp;
        uint256 cvgLockedInUsd;
        uint256 ysCvgActual;
        uint256 ysCvgNext;
        uint256 veCvg;
        GaugePosition gaugePosition;
        uint256 claimableInUsd;
        bool isLocked;
        uint256 hoursLock;
    }

    function _tokenURI(LogoInfos memory logoInfos) external pure returns (string memory output);

    function getLogoInfo(uint256 tokenId) external view returns (ILockingLogo.LogoInfosFull memory);
}
pragma solidity ^0.8.0;

interface ILockingPositionDelegate {
    struct OwnedAndDelegated {
        uint256[] owneds;
        uint256[] mgDelegateds;
        uint256[] veDelegateds;
    }

    function delegatedYsCvg(uint256 tokenId) external view returns (address);

    function getMgDelegateeInfoPerTokenAndAddress(
        uint256 _tokenId,
        address _to
    ) external view returns (uint256, uint256, uint256);

    function getIndexForVeDelegatee(address _delegatee, uint256 _tokenId) external view returns (uint256);

    function getIndexForMgCvgDelegatee(address _delegatee, uint256 _tokenId) external view returns (uint256);

    function delegateVeCvg(uint256 _tokenId, address _to) external;

    function delegateYsCvg(uint256 _tokenId, address _to, bool _status) external;

    function delegateMgCvg(uint256 _tokenId, address _to, uint256 _percentage) external;

    function delegatedVeCvg(uint256 tokenId) external view returns (address);

    function getVeCvgDelegatees(address account) external view returns (uint256[] memory);

    function getMgCvgDelegatees(address account) external view returns (uint256[] memory);

    function getTokenOwnedAndDelegated(address _addr) external view returns (OwnedAndDelegated[] memory);

    function getTokenMgOwnedAndDelegated(address _addr) external view returns (uint256[] memory, uint256[] memory);

    function getTokenVeOwnedAndDelegated(address _addr) external view returns (uint256[] memory, uint256[] memory);

    function addTokenAtMint(uint256 _tokenId, address minter) external;

    function cleanDelegateesOnTransfer(uint256 _tokenId) external;
}
pragma solidity ^0.8.0;

import "./ILockingLogo.sol";

interface ILockingPositionManager {
    function ownerOf(uint256 tokenId) external view returns (address);

    function mint(address account) external returns (uint256);

    function burn(uint256 tokenId, address caller) external;

    function logoInfo(uint256 tokenId) external view returns (ILockingLogo.LogoInfos memory);

    function checkYsClaim(uint256 tokenId, address caller) external view;

    function checkOwnership(uint256 _tokenId, address operator) external view;

    function checkOwnerships(uint256[] memory _tokenIds, address operator) external view;

    function checkFullCompliance(uint256 tokenId, address operator) external view;

    function getTokenIdsForWallet(address _wallet) external view returns (uint256[] memory);
}
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILockingPositionService {
    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        STORED STRUCTS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    struct LockingPosition {
        /// @dev Starting cycle of a LockingPosition. Maximum value of uint24 is 16M, so 16M weeks is way enough.
        uint24 startCycle;
        /// @dev End cycle of a LockingPosition. Maximum value of uint24 is 16M, so 16M weeks is way enough.
        uint24 lastEndCycle;
        /** @dev Percentage of the token allocated to ysCvg. Amount dedicated to vote is so equal to 100 - ysPercentage.
         *  A position with ysPercentage as 60 will allocate 60% of his locking to YsCvg and 40% to veCvg and mgCvg.
         */
        uint8 ysPercentage;
        /** @dev Total Cvg amount locked in the position.
         *  Max supply of CVG is 150M, it so fits into an uint104 (20 000 billions approx).
         */
        uint104 totalCvgLocked;
        /**  @dev MgCvgAmount held by the position.
         *   Max supply of mgCVG is 150M, it so fits into an uint96 (20 billions approx).
         */
        uint96 mgCvgAmount;
    }

    struct TrackingBalance {
        /** @dev Amount of ysCvg to add to the total supply when the corresponding cvgCycle is triggered.
         *  Max supply of ysCVG is 150M, it so fits into an uint128.
         */
        uint128 ysToAdd;
        /** @dev Amount of ysCvg to remove from the total supply when the corresponding cvgCycle is triggered.
         *  Max supply of ysCVG is 150M, it so fits into an uint128.
         */
        uint128 ysToSub;
    }

    struct Checkpoints {
        uint24 cycleId;
        uint232 ysBalance;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        VIEW STRUCTS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    struct TokenView {
        uint256 tokenId;
        uint128 startCycle;
        uint128 endCycle;
        uint256 cvgLocked;
        uint256 ysActual;
        uint256 ysTotal;
        uint256 veCvgActual;
        uint256 mgCvg;
        uint256 ysPercentage;
    }

    struct LockingInfo {
        uint256 tokenId;
        uint256 cvgLocked;
        uint256 lockEnd;
        uint256 ysPercentage;
        uint256 mgCvg;
    }

    function TDE_DURATION() external view returns (uint256);

    function MAX_LOCK() external view returns (uint24);

    function updateYsTotalSupply() external;

    function ysTotalSupplyHistory(uint256) external view returns (uint256);

    function ysShareOnTokenAtTde(uint256, uint256) external view returns (uint256);

    function veCvgVotingPowerPerAddress(address _user) external view returns (uint256);

    function mintPosition(
        uint24 lockDuration,
        uint128 amount,
        uint8 ysPercentage,
        address receiver,
        bool isAddToManagedTokens
    ) external;

    function increaseLockAmount(uint256 tokenId, uint128 amount, address operator) external;

    function increaseLockTime(uint256 tokenId, uint256 durationAdd) external;

    function increaseLockTimeAndAmount(uint256 tokenId, uint24 durationAdd, uint128 amount, address operator) external;

    function totalSupplyYsCvgHistories(uint256 cycleClaimed) external view returns (uint256);

    function balanceOfYsCvgAt(uint256 tokenId, uint256 cycle) external view returns (uint256);

    function lockingPositions(uint256 tokenId) external view returns (LockingPosition memory);

    function unlockingTimestampPerToken(uint256 tokenId) external view returns (uint256);

    function lockingInfo(uint256 tokenId) external view returns (LockingInfo memory);

    function isContractLocker(address contractAddress) external view returns (bool);

    function getTotalSupplyAtAndBalanceOfYs(uint256 tokenId, uint256 cycleId) external view returns (uint256, uint256);

    function getTotalSupplyHistoryAndBalanceOfYs(
        uint256 tokenId,
        uint256 cycleId
    ) external view returns (uint256, uint256);
}
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IOracleStruct {
    enum PoolType {
        NOT_INIT,
        STABLE,
        CURVE_DUO,
        CURVE_TRI,
        UNI_V3,
        UNI_V2
    }

    struct StableParams {
        AggregatorV3Interface aggregatorOracle;
        uint40 deltaLimitOracle; // 5 % => 500 & 100 % => 10 000
        uint56 maxLastUpdate; // Buffer time before a not updated price is considered as stale
        uint128 minPrice;
        uint128 maxPrice;
    }

    struct CurveDuoParams {
        bool isReversed;
        bool isEthPriceRelated;
        address poolAddress;
        uint40 deltaLimitOracle; // 5 % => 500 & 100 % => 10 000
        uint40 maxLastUpdate; // Buffer time before a not updated price is considered as stale
        uint128 minPrice;
        uint128 maxPrice;
        address[] stablesToCheck;
    }

    struct CurveTriParams {
        bool isReversed;
        bool isEthPriceRelated;
        address poolAddress;
        uint40 deltaLimitOracle;
        uint40 maxLastUpdate;
        uint8 k;
        uint120 minPrice;
        uint128 maxPrice;
        address[] stablesToCheck;
    }

    struct UniV2Params {
        bool isReversed;
        bool isEthPriceRelated;
        address poolAddress;
        uint80 deltaLimitOracle;
        uint96 maxLastUpdate;
        AggregatorV3Interface aggregatorOracle;
        uint128 minPrice;
        uint128 maxPrice;
        address[] stablesToCheck;
    }

    struct UniV3Params {
        bool isReversed;
        bool isEthPriceRelated;
        address poolAddress;
        uint80 deltaLimitOracle;
        uint80 maxLastUpdate;
        uint16 twap;
        AggregatorV3Interface aggregatorOracle;
        uint128 minPrice;
        uint128 maxPrice;
        address[] stablesToCheck;
    }
}
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface IPresaleCvgSeed is IERC721Enumerable {
    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            ENUMS & STRUCTS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    enum SaleState {
        NOT_ACTIVE,
        PRESEED,
        SEED,
        OVER
    }

    struct PresaleInfo {
        uint256 vestingType; // Define the presaler type
        uint256 cvgAmount; // Total CVG amount claimable for the nft owner
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            SETTERS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    function setSaleState(SaleState _saleState) external;

    function grantPreseed(address _wallet, uint256 _amount) external;

    function grantSeed(address _wallet, uint256 _amount) external;

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            EXTERNALS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    function investMint(bool _isDai) external;

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            GETTERS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    function presaleInfoTokenId(uint256 _tokenId) external view returns (PresaleInfo memory);

    function saleState() external view returns (SaleState);

    function tokenOfOwnerByIndex(address owner, uint256 index) external view override returns (uint256);

    function getTokenIdAndType(
        address _wallet,
        uint256 _index
    ) external view returns (uint256 tokenId, uint256 typeVesting);

    function getTokenIdsForWallet(address _wallet) external view returns (uint256[] memory);

    function getTotalCvg() external view returns (uint256);

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        WITHDRAW OWNER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    function withdrawFunds() external;

    function withdrawToken(address _token) external;
}
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "./ICvgControlTower.sol";
import "./ISdtBuffer.sol";

interface IOperator {
    function token() external view returns (IERC20Metadata);

    function deposit(uint256 amount, bool isLock, bool isStake, address receiver) external;
}

interface ISdAsset is IERC20Metadata {
    function sdAssetGauge() external view returns (IERC20);

    function initialize(
        ICvgControlTower _cvgControlTower,
        IERC20 _sdAssetGauge,
        string memory setName,
        string memory setSymbol
    ) external;

    function setSdAssetBuffer(address _sdAssetBuffer) external;

    function mint(address to, uint256 amount) external;

    function operator() external view returns (IOperator);
}

interface ISdAssetGauge is IERC20Metadata {
    function deposit(uint256 value, address addr) external;

    function deposit(uint256 value, address addr, bool claimRewards) external;

    function staking_token() external view returns (IERC20);

    function reward_count() external view returns (uint256);

    function reward_tokens(uint256 i) external view returns (IERC20);

    function claim_rewards(address account) external;

    function set_rewards_receiver(address account) external;

    function claimable_reward(address account, address token) external view returns (uint256);

    function set_reward_distributor(address rewardToken, address distributor) external;

    function deposit_reward_token(address rewardToken, uint256 amount) external;

    function admin() external view returns (address);

    function working_balances(address) external view returns (uint256);

    function working_supply() external view returns (uint256);
}
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ICommonStruct.sol";

interface ISdtBlackHole {
    function withdraw(uint256 amount, address receiver) external;

    function setGaugeReceiver(address gaugeAddress, address bufferReceiver) external;

    function getBribeTokensForBuffer(address buffer) external view returns (IERC20[] memory);

    function pullSdStakingBribes(
        address _processor,
        uint256 _processorRewardsPercentage
    ) external returns (ICommonStruct.TokenAmount[] memory);
}
pragma solidity ^0.8.0;
import "./ICvgControlTower.sol";

import "./ISdAssets.sol";

import "./ICommonStruct.sol";

interface ISdtBuffer {
    function initialize(
        ICvgControlTower _cvgControlTower,
        address _sdAssetStaking,
        ISdAssetGauge _sdGaugeAsset,
        IERC20 _sdt
    ) external;

    function pullRewards(address _processor) external returns (ICommonStruct.TokenAmount[] memory);

    function processorRewardsPercentage() external view returns (uint256);
}
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISdtFeeCollector {
    function rootFees() external returns (uint256);

    function withdrawToken(IERC20[] calldata _tokens) external;

    function withdrawSdt() external;
}
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ICommonStruct.sol";

interface ISdtRewardDistributor {
    function claimCvgSdtSimple(
        address receiver,
        uint256 cvgAmount,
        ICommonStruct.TokenAmount[] memory sdtRewards,
        uint256 minCvgSdtAmountOut,
        bool isConvert
    ) external;
}
pragma solidity ^0.8.0;

import "./ICommonStruct.sol";

interface ISdtStakingLogo {
    struct LogoInfos {
        uint256 tokenId;
        string symbol;
        uint256 pending;
        uint256 totalStaked;
        uint256 cvgClaimable;
        ICommonStruct.TokenAmount[] sdtClaimable;
        uint256 unlockingTimestamp;
    }

    struct LogoInfosFull {
        uint256 tokenId;
        string symbol;
        uint256 pending;
        uint256 totalStaked;
        uint256 cvgClaimable;
        ICommonStruct.TokenAmount[] sdtClaimable;
        uint256 unlockingTimestamp;
        uint256 claimableInUsd;
        bool erroneousAmount;
        bool isLocked;
        uint256 hoursLock;
    }

    function _tokenURI(LogoInfos memory logoInfos) external pure returns (string memory output);

    function getLogoInfo(uint256 tokenId) external view returns (ISdtStakingLogo.LogoInfosFull memory);
}
pragma solidity ^0.8.0;

import "./ISdtStakingLogo.sol";
import "./ISdtStakingPositionService.sol";

interface ISdtStakingPositionManager {
    struct ClaimSdtStakingContract {
        ISdtStakingPositionService stakingContract;
        uint256[] tokenIds;
    }

    function mint(address account) external;

    function burn(uint256 tokenId) external;

    function nextId() external view returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);

    function checkMultipleClaimCompliance(ClaimSdtStakingContract[] calldata, address account) external view;

    function checkTokenFullCompliance(uint256 tokenId, address account) external view;

    function checkIncreaseDepositCompliance(uint256 tokenId, address account) external view;

    function stakingPerTokenId(uint256 tokenId) external view returns (address);

    function unlockingTimestampPerToken(uint256 tokenId) external view returns (uint256);

    function logoInfo(uint256 tokenId) external view returns (ISdtStakingLogo.LogoInfos memory);

    function getTokenIdsForWallet(address _wallet) external view returns (uint256[] memory);
}
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./ICommonStruct.sol";
import "./ISdtBuffer.sol";

interface ISdtStakingPositionService {
    struct CycleInfo {
        uint256 cvgRewardsAmount;
        uint256 totalStaked;
        bool isSdtProcessed;
    }

    struct TokenInfo {
        uint256 amountStaked;
        uint256 pendingStaked;
    }
    struct CycleInfoMultiple {
        uint256 totalStaked;
        ICommonStruct.TokenAmount[] sdtClaimable;
    }
    struct StakingInfo {
        uint256 tokenId;
        string symbol;
        uint256 pending;
        uint256 totalStaked;
        uint256 cvgClaimable;
        ICommonStruct.TokenAmount[] sdtClaimable;
    }

    function setBuffer(address _buffer) external;

    function stakingCycle() external view returns (uint256);

    function cycleInfo(uint256 cycleId) external view returns (CycleInfo memory);

    function stakingAsset() external view returns (ISdAssetGauge);

    function buffer() external view returns (ISdtBuffer);

    function tokenTotalStaked(uint256 _tokenId) external view returns (uint256 amount);

    function stakedAmountEligibleAtCycle(
        uint256 cvgCycle,
        uint256 tokenId,
        uint256 actualCycle
    ) external view returns (uint256);

    function tokenInfoByCycle(uint256 cycleId, uint256 tokenId) external view returns (TokenInfo memory);

    function stakingInfo(uint256 tokenId) external view returns (StakingInfo memory);

    function getProcessedSdtRewards(uint256 _cycleId) external view returns (ICommonStruct.TokenAmount[] memory);

    function deposit(uint256 tokenId, uint256 amount, address operator) external;

    function claimCvgSdtMultiple(
        uint256 _tokenId,
        address operator
    ) external returns (uint256, ICommonStruct.TokenAmount[] memory);
}
pragma solidity ^0.8.0;
import "./IPresaleCvgSeed.sol";

interface IVestingCvg {
    /// @dev Struct Info about VestingSchedules
    struct VestingSchedule {
        uint16 daysBeforeCliff;
        uint16 daysAfterCliff;
        uint24 dropCliff;
        uint256 totalAmount;
        uint256 totalReleased;
    }

    struct InfoVestingTokenId {
        uint256 amountReleasable;
        uint256 totalCvg;
        uint256 amountRedeemed;
    }

    enum VestingType {
        SEED,
        WL,
        IBO,
        TEAM,
        DAO
    }

    function vestingSchedules(VestingType vestingType) external view returns (VestingSchedule memory);

    function getInfoVestingTokenId(
        uint256 _tokenId,
        VestingType vestingType
    ) external view returns (InfoVestingTokenId memory);

    function whitelistedTeam() external view returns (address);

    function presaleSeed() external view returns (IPresaleCvgSeed);

    function MAX_SUPPLY_TEAM() external view returns (uint256);

    function startTimestamp() external view returns (uint256);
}
pragma solidity ^0.8.0;

interface IVotingPowerEscrow {
    function create_lock(uint256 tokenId, uint256 value, uint256 unlockTime) external;

    function increase_amount(uint256 tokenId, uint256 value) external;

    function increase_unlock_time(uint256 tokenId, uint256 unlockTime) external;

    function increase_unlock_time_and_amount(uint256 tokenId, uint256 unlockTime, uint256 amount) external;

    function withdraw(uint256 tokenId) external;

    function total_supply() external returns (uint256);

    function balanceOf(uint256 tokenId) external view returns (uint256);
}
pragma solidity ^0.8.0;

import "./ICommonStruct.sol";

interface IYsDistributor {
    struct TokenAmount {
        IERC20 token;
        uint96 amount;
    }

    struct Claim {
        uint256 tdeCycle;
        bool isClaimed;
        TokenAmount[] tokenAmounts;
    }

    function getPositionRewardsForTdes(
        uint256[] calldata _tdeIds,
        uint256 actualCycle,
        uint256 _tokenId
    ) external view returns (Claim[] memory);
}
