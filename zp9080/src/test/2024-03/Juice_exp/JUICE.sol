                            Contract Source Code (Solidity Standard Json-Input format) IDEBlockscan IDE🤖 Code ReaderBetaRemix IDEMore OptionsSimilarSol2UmlSubmit AuditCompareFile 1 of 8 : JUICE.solpragma solidity ^0.8.9;

// SPDX-License-Identifier: MIT

//website: juicebot.app

//twitter: https://twitter.com/juicebotapp

//tg: https://t.me/JuiceBotApp

import "./ERC20.sol";
import "./Ownable.sol";


contract JUICE is ERC20, Ownable {
    
    uint256 constant private startingSupply = 10_000_000;
    uint256 constant private _tTotal = startingSupply * 10 **18;
    constructor(address _router) ERC20("JUICE", "JUICE") {
        _mint(msg.sender, _tTotal);

        uniswapRouter = IUniswapV2Router02(_router); 

        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[msg.sender] = true;
    }

    function enableTrading() public onlyOwner {
        require(!isTradingEnabled, "JUICE: Trading is alredy enabled");
        require(pairsList.length > 0, "JUICE: Please add all the pairs first");
        isTradingEnabled = true;
        contractSwapEnabled = true;
        emit ContractSwapEnabledUpdated(true);
    }

    function excludeOrInclude(address user, bool value) public onlyOwner {
        require(isExcludedFromFee[user] != value, "JUICE: Already set as same value");
        isExcludedFromFee[user] = value;
    }

    function addOrRemovePairs(address pair, bool value) public onlyOwner {
        require(isPair[pair] != value, "JUICE: Already set as same value");
        isPair[pair] = value;
        pairsList.push(pair);
        if (lpPair == address(0)) {
            lpPair = pair;
        }
    }

    function setSwapSettings(uint256 thresholdPercent, uint256 thresholdDivisor, uint256 amountPercent, uint256 amountDivisor) external onlyOwner {
        swapThreshold = (_tTotal * thresholdPercent) / thresholdDivisor;
        swapAmount = (_tTotal * amountPercent) / amountDivisor;
        require(swapThreshold <= swapAmount, "Threshold cannot be above amount.");
        require(swapAmount <= (balanceOf(lpPair) * 20) / 1000, "Cannot be above 2% of current PI.");
        require(swapAmount >= _tTotal / 10_000_000, "Cannot be lower than 0.00001% of total supply.");
        require(swapThreshold >= _tTotal / 10_000_000, "Cannot be lower than 0.00001% of total supply.");
    }

    function setPriceImpactSwapAmount(uint256 priceImpactSwapPercent) external onlyOwner {
        require(priceImpactSwapPercent <= 100, "Cannot set above 1%.");
        piSwapPercent = priceImpactSwapPercent;
    }

    function setContractSwapEnabled(bool swapEnabled, bool priceImpactSwapEnabled) external onlyOwner {
        contractSwapEnabled = swapEnabled;
        piContractSwapsEnabled = priceImpactSwapEnabled;
        emit ContractSwapEnabledUpdated(swapEnabled);
    }

    function updateDevelopmentAddress(address payable development) public onlyOwner {
        require(_taxWallets.development != development, "JUICE: Already set as same address");
        _taxWallets.development = payable(development);
    }

    function updateFees(uint256 transfer, uint256 buy, uint256 sell) public onlyOwner {
        transferFee = transfer;
        buyFee = buy;
        sellFee = sell;
    }

    function transferEther() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
    
    // function to allow admin to transfer *any* ERC20 tokens from this contract..
    function transferAnyERC20Tokens(address tokenAddress, address recipient, uint256 amount) public onlyOwner {
        require(amount > 0, "JUICE: amount must be greater than 0");
        require(recipient != address(0), "JUICE: recipient is the zero address");
        IERC20(tokenAddress).transfer(recipient, amount);
    }

    receive() external payable { }
}File 2 of 8 : Ownable.solpragma solidity ^0.8.9;

// SPDX-License-Identifier: MIT

import "./Context.sol";

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
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
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
}File 3 of 8 : ERC20.solpragma solidity ^0.8.9;

// SPDX-License-Identifier: MIT

import "./Context.sol";
import "./IERC20.sol";
import "./SafeMath.sol";
import "./IUniswapV2Router02.sol";

contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

    IUniswapV2Router02 public uniswapRouter;
    address public wethAddress;
    address[] public pairsList;
    address public lpPair;

    bool public isTradingEnabled = false;

    mapping (address => uint256) private _balances;
    mapping (address => bool) public isExcludedFromFee;
    mapping (address => bool) public isPair;

    mapping (address => mapping (address => uint256)) private _allowances;

    
    uint256 private _totalSupply;

    uint256 public transferFee = 0;
    uint256 public buyFee = 20;
    uint256 public sellFee = 20;

    string private _name;
    string private _symbol;   
    uint8 private _decimals; 

    bool inSwap;
    bool public contractSwapEnabled = false;
    uint256 public swapThreshold;
    uint256 public swapAmount;
    bool public piContractSwapsEnabled;
    uint256 public piSwapPercent;

    struct TaxWallets {
        address payable development;
    }

    TaxWallets public _taxWallets = TaxWallets({
        development: payable(0x3a5198c44E14C61C5Af67C8b44DbA19533FeD23d)
        });

    event SwapTokensForETH(uint256 tokenAmount, address[] path);
    event LiquidityAdded(uint256 amountTokenA, uint256 amountETH);
    event ContractSwapEnabledUpdated(bool enabled);

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

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
        _transfer(_msgSender(), recipient, amount);
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
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        bool buy = false;
        bool sell = false;
        bool other = false;
        if (isPair[sender]) {
            buy = true;
        } else if (isPair[recipient]) {
            sell = true;
        } else {
            other = true;
        }

        _beforeTokenTransfer(sender, recipient, amount);
        if (!isExcludedFromFee[sender] && !isExcludedFromFee[recipient]) {
            require(isTradingEnabled, "ERC20: Trading is not enabled yet..");
                if (sell) {
                    if (!inSwap) {
                        if (contractSwapEnabled) {
                            uint256 contractTokenBalance = balanceOf(address(this));
                            if (contractTokenBalance >= swapThreshold) {
                                uint256 swapAmt = swapAmount;
                                if (piContractSwapsEnabled) { swapAmt = (balanceOf(lpPair) * piSwapPercent); }
                                if (contractTokenBalance >= swapAmt) { contractTokenBalance = swapAmt; }
                                contractSwap(contractTokenBalance);
                            }
                        }
                    }
                }
                if (!isPair[sender] && !isPair[recipient]) {
                    uint256 fee = amount.mul(transferFee).div(100);                   
                    amount = amount.sub(fee);
                    _balances[sender] = _balances[sender].sub(fee, "ERC20: transfer amount exceeds balance");
                    _balances[address(this)] = _balances[address(this)].add(fee);
                    emit Transfer(sender, address(this), fee);
                }
                if (isPair[sender]) {
                    uint256 fee = amount.mul(buyFee).div(100);
                    amount = amount.sub(fee);
                    _balances[sender] = _balances[sender].sub(fee, "ERC20: transfer amount exceeds balance");
                    _balances[address(this)] = _balances[address(this)].add(fee);
                    emit Transfer(sender, address(this), fee);
                }
                if (isPair[recipient]) {
                    uint256 fee = amount.mul(sellFee).div(100);                  
                    amount = amount.sub(fee);
                    _balances[sender] = _balances[sender].sub(fee, "ERC20: transfer amount exceeds balance");
                    _balances[address(this)] = _balances[address(this)].add(fee);
                    emit Transfer(sender, address(this), fee);
                }
        }
        
        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function contractSwap(uint256 contractTokenBalance) internal lockTheSwap {

        if(_allowances[address(this)][address(uniswapRouter)] != type(uint256).max) {
            _allowances[address(this)][address(uniswapRouter)] = type(uint256).max;
        }
        
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapRouter.WETH();

        try uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            contractTokenBalance,
            0,
            path,
            address(this),
            block.timestamp
        ) {} catch {
            return;
        }

        uint256 amtBalance = address(this).balance;
        bool success;
        uint256 developmentBalance = amtBalance;
        (success,) = _taxWallets.development.call{value: developmentBalance, gas: 35000}("");
    }    


    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}File 4 of 8 : Context.solpragma solidity ^0.8.9;

// SPDX-License-Identifier: MIT

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
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}File 5 of 8 : IUniswapV2Router02.solpragma solidity ^0.8.9;

// SPDX-License-Identifier: MIT

import "./IUniswapV2Router01.sol";

interface IUniswapV2Router02 is IUniswapV2Router01 {
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
}File 6 of 8 : SafeMath.solpragma solidity ^0.8.9;

// SPDX-License-Identifier: MIT

library SafeMath {
    
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/OpenZeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}File 7 of 8 : IERC20.solpragma solidity ^0.8.9;

// SPDX-License-Identifier: MIT

interface IERC20 {
    
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}File 8 of 8 : IUniswapV2Router01.solpragma solidity ^0.8.9;

// SPDX-License-Identifier: MIT

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);
}
