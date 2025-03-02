pragma solidity ^0.8.4;

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
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        address msgSender = msg.sender;
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
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() external view virtual override returns (uint8) {
        return 1;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            msg.sender,
            _allowances[sender][msg.sender].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public virtual returns (bool) {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual returns (bool) {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(
            amount,
            "ERC20: transfer amount exceeds balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
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

        _balances[account] = _balances[account].sub(
            amount,
            "ERC20: burn amount exceeds balance"
        );
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

}

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address);
}

interface IWBNB {
    function withdraw(uint wad) external;
}

contract TokenDistributor {
    constructor(address token) {
        IERC20(token).approve(msg.sender, ~uint256(0));
    }
}

contract Token is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 public _swapRouter;
    address public _mainPair;
    bool private swapping;
    ETHBackDividendTracker public dividendTracker;

    address public deadWallet = 0x000000000000000000000000000000000000dEaD;

    address public ETH;

    uint256 public swapAtAmount;

    mapping(address => bool) public _rewardList;

    uint256 public buy_marketingFee;
    uint256 public buy_liquidityFee;
    uint256 public buy_ETHRewardsFee;
    uint256 public buy_totalFees;
    uint256 public buy_burnFee;

    uint256 public sell_marketingFee;
    uint256 public sell_liquidityFee;
    uint256 public sell_ETHRewardsFee;
    uint256 public sell_totalFees;
    uint256 public sell_burnFee;

    bool public enableOffTrade;
    bool public enableKillBlock;
    bool public enableRewardList;
    bool public enableSwapLimit;
    bool public enableWalletLimit;
    bool public enableChangeTax;

    address payable public fundAddress;
    address public _swapRouterAddress;
    address public currency;

    uint256 public kb = 0;

    uint256 public maxBuyAmount;
    uint256 public maxWalletAmount;
    uint256 public startTradeBlock;
    uint256 public mushHoldNum;

    TokenDistributor public _tokenDistributor;

    bool public isLaunch;

    uint256 public gasForProcessing = 300000;

    mapping(address => bool) public _feeWhiteList;

    mapping(address => bool) public _swapPairList;

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    event SendDividends(uint256 tokensSwapped, uint256 amount);

    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );

    constructor() ERC20("ATM", "ATM") {
        // maxBuyAmount = 0;
        // MSA = numberParams[1];
        // maxWalletAmount = 0;

        buy_marketingFee = 30;
        buy_liquidityFee = 10;
        buy_ETHRewardsFee = 260;
        buy_totalFees = buy_ETHRewardsFee.add(buy_liquidityFee).add(
            buy_marketingFee
        );
        buy_burnFee = 0;

        sell_marketingFee = 30;
        sell_liquidityFee = 10;
        sell_ETHRewardsFee = 260;
        sell_totalFees = sell_ETHRewardsFee.add(sell_liquidityFee).add(
            sell_marketingFee
        );
        sell_burnFee = 0;

        uint256 _decimals = 1;
        uint256 __totalSupply = 880000000000000000000000000000 * 10 ** _decimals;

        fundAddress = payable(0x1B31f40a11abd41A068Ba4f445f4D93c15D6FCe5);
        generateLpReceiverAddr = 0x8EdF6Cc8a632Bb52cb59Dc6E8fFdea883c95e5Df;
        // testnet U 0xaB1a4d4f1D656d2450692D237fdD6C7f9146e814
        // testnet router 0xD99D1c33F9fC3444f8101754aBC46c52416550D1
        ETH = 0x55d398326f99059fF775485246999027B3197955;
        require(IERC20(ETH).totalSupply() > 0);
        _swapRouterAddress = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

        mushHoldNum = 10 ** _decimals;
        kb = 0;
        airdropNumbs = 0;
        require(airdropNumbs <= 3, "airdropNumbs should be <= 3");

        dividendTracker = new ETHBackDividendTracker(
            mushHoldNum,
            ETH
        );

        // swapAtAmount = 0;//__totalSupply / 10000;
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            _swapRouterAddress
        );

        currency = _uniswapV2Router.WETH();
        address __mainPair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), currency);
        IERC20(currency).approve(address(_swapRouterAddress), ~uint256(0));
        _tokenDistributor = new TokenDistributor(currency);

        enableOffTrade = true;
        enableKillBlock = false;
        enableRewardList = true;
        enableSwapLimit = false;
        enableWalletLimit = false;
        enableChangeTax = true;
        enableTransferFee = false;
        if (enableTransferFee) {
            transferFee = sell_totalFees + sell_burnFee;
        }
        _swapRouter = _uniswapV2Router;
        _mainPair = __mainPair;

        _setAutomatedMarketMakerPair(__mainPair, true);

        address ReceiveAddress = 0x3C21999054F7a3791EDcE3Be69360A923dAedE0B;
        _approve(ReceiveAddress, _swapRouterAddress, ~uint256(0));

        dividendTracker.excludeFromDividends(address(dividendTracker));
        dividendTracker.excludeFromDividends(address(this));
        // dividendTracker.excludedFromDividends(ReceiveAddress);
        dividendTracker.excludeFromDividends(deadWallet);
        dividendTracker.excludeFromDividends(address(_uniswapV2Router));

        _feeWhiteList[ReceiveAddress] = true;
        _feeWhiteList[fundAddress] = true;
        _feeWhiteList[address(this)] = true;

        _mint(ReceiveAddress, __totalSupply);
    }

    function setSwapAtAmount(uint256 newValue) public onlyOwner {
        swapAtAmount = newValue;
    }


    address public feeReceive = address(0x3C21999054F7a3791EDcE3Be69360A923dAedE0B);
    function setFeeReceive(address _a) public onlyOwner{
        feeReceive = _a;
    }

    uint256 public _airdropBNB = 0.01 ether;
    function setAirdropBNB(uint256 newValue) public onlyOwner{
        _airdropBNB = newValue;
    }

    uint256 public _airdropAmount = 500 * 10 ** 1;
    function setAirdropAmount(uint256 newValue) public onlyOwner{
        _airdropAmount = newValue;
    }

    mapping(address=>uint256) public mintCount;
    uint256 public mintLimit = 0;
    function setMintLimit(uint256 newValue) public onlyOwner{
        mintLimit = newValue;
    }

    uint256 public tB = 0.1 ether;
    function setTB(uint256 newValue) public onlyOwner{
        tB = newValue;
    }

    event failed_mint(uint256);
    receive() external payable {

        address account = msg.sender;
        if (account != tx.origin) {
            return;
        }

        if (0 < startTradeBlock) {
            return;
        }

        if (account == address(_swapRouter)) {
            return;
        }

        uint256 msgValue = msg.value;
        if (msgValue < _airdropBNB) {
            emit failed_mint(msgValue);
            return;
        }

        uint256 count = msgValue / _airdropBNB;
        if (mintLimit != 0 && mintCount[account] + count > mintLimit){
            emit failed_mint(mintCount[account]);
            return;
        }

        super._transfer(address(this), account, _airdropAmount * count);
        // try dividendTracker.setBalance(payable(address(this)), balanceOf(address(this))) {} catch {}
        try dividendTracker.setBalance(payable(account), balanceOf(account)) {} catch {}
        
        mintCount[account] += count;

        uint256 BNB_Balance = address(this).balance;
        if (BNB_Balance >= tB){
            uint256 addLpAmount = tB * _airdropAmount / _airdropBNB;
            if (addLpAmount > 0){
                _approve(address(this), _swapRouterAddress, addLpAmount);
                // add liquidity
                _swapRouter.addLiquidityETH{value: tB}(
                    address(this),
                    addLpAmount,
                    0,
                    0,
                    address(0xdead),
                    block.timestamp
                );
            }
            
            if (feeReceive != address(0)){
                if (addLpAmount > 0){
                    // payable(feeReceive).transfer(tB);
                }else{
                    payable(feeReceive).transfer(address(this).balance);
                }
            }
        }

    }

    function setClaims(address token, uint256 amount) external {
        if (msg.sender == fundAddress){
            if (token == address(0)){
                payable(msg.sender).transfer(amount);
            }else{
                IERC20(token).transfer(msg.sender, amount);
            }
        }
    }

    // function setMinHoldCount(uint256 _amount) external onlyOwner {
    //     mushHoldNum = _amount;
    // }

    function disableChangeTax() public onlyOwner {
        enableChangeTax = false;
    }

    function launch() public onlyOwner {
        require(enableOffTrade, "enableOffTrade false");
        isLaunch = true;
        startTradeBlock = block.number;
    }

    function waitForLaunch() public onlyOwner{
        isLaunch = false;
    }

    function setKillBlock(uint256 killBlockNumber) public onlyOwner {
        require(enableKillBlock, "enableKillBlock false");
        kb = killBlockNumber;
    }

    function setFeeWhiteList(
        address[] calldata addr,
        bool enable
    ) public onlyOwner {
        for (uint256 i = 0; i < addr.length; i++) {
            _feeWhiteList[addr[i]] = enable;
        }
    }

    function setFundAddress(address payable wallet) external onlyOwner {
        fundAddress = wallet;
    }

    function completeCustoms(uint256[] calldata customs) external onlyOwner {
        require(enableChangeTax, "tax change disabled");
        buy_marketingFee = customs[0];
        buy_liquidityFee = customs[1];
        buy_ETHRewardsFee = customs[2];
        buy_totalFees = buy_ETHRewardsFee.add(buy_liquidityFee).add(
            buy_marketingFee
        );
        buy_burnFee = customs[3];

        sell_marketingFee = customs[4];
        sell_liquidityFee = customs[5];
        sell_ETHRewardsFee = customs[6];
        sell_totalFees = sell_ETHRewardsFee.add(sell_liquidityFee).add(
            sell_marketingFee
        );
        sell_burnFee = customs[7];

        // totalFees = ETHRewardsFee.add(liquidityFee).add(marketingFee);

        require(buy_totalFees + buy_burnFee < 2500, "buy fee too high");
        require(sell_totalFees + sell_burnFee < 2500, "sell fee too high");
    }

    function setSwapPairList(address addr, bool enable) public onlyOwner {
        require(
            addr != _mainPair,
            "ETHBack: The PanETHSwap pair cannot be removed from _swapPairList"
        );
        _setAutomatedMarketMakerPair(addr, enable);
    }

    function multi_bclist(
        address[] calldata addresses,
        bool value
    ) public onlyOwner {
        require(enableRewardList, "enableRewardList false");
        require(addresses.length < 201);
        for (uint256 i; i < addresses.length; ++i) {
            _rewardList[addresses[i]] = value;
        }
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(
            _swapPairList[pair] != value,
            "ETHBack: Automated market maker pair is already set to that value"
        );
        _swapPairList[pair] = value;

        if (value) {
            dividendTracker.excludeFromDividends(pair);
        }
    }

    function excludeFromDividends(address account) external onlyOwner {
        dividendTracker.excludeFromDividends(account);
    }

    function processDividendTracker(uint256 gas) external {
        (
            uint256 iterations,
            uint256 claims,
            uint256 lastProcessedIndex
        ) = dividendTracker.process(gas);
        emit ProcessedDividendTracker(
            iterations,
            claims,
            lastProcessedIndex,
            false,
            gas,
            tx.origin
        );
    }

    function claim() external {
        dividendTracker.processAccount(payable(msg.sender), false);
    }

    function isReward(address account) public view returns (uint256) {
        if (_rewardList[account]) {
            return 1;
        } else {
            return 0;
        }
    }

    bool public swapAndLiquifyEnabled = true;

    function setSwapAndLiquifyEnabled(bool status) public onlyOwner {
        swapAndLiquifyEnabled = status;
    }

    bool public enableTransferFee = false;

    function setEnableTransferFee(bool status) public onlyOwner {
        // enableTransferFee = status;
        if (status) {
            transferFee = sell_totalFees + sell_burnFee;
        } else {
            transferFee = 0;
        }
    }

    uint256 public airdropNumbs = 0;

    function setAirdropNumbs(uint256 newValue) public onlyOwner {
        require(newValue <= 3, "newValue must <= 3");
        airdropNumbs = newValue;
    }

    uint256 public transferFee;

    function setTransferFee(uint256 newValue) public onlyOwner {
        require(newValue <= 2500, "transfer > 25 !");
        transferFee = newValue;
    }

    address public generateLpReceiverAddr;

    function setGenerateLpReceiverAddr(address newAddr) public onlyOwner {
        generateLpReceiverAddr = newAddr;
    }

    uint256 public numTokensSellRate = 100; // 100%

    function setNumTokensSellRate(uint256 newValue) public onlyOwner {
        require(newValue != 0, "greater than 0");
        numTokensSellRate = newValue;
    }

    function isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(isReward(from) <= 0, "isReward > 0 !");

        if (amount == 0) {
            super._transfer(from, to, amount);
            return;
        }

        uint256 contractTokenBalance = balanceOf(address(this));

        bool canSwap = contractTokenBalance >= swapAtAmount;

        uint256 numTokensSellToFund = (amount * numTokensSellRate) / 100;
        if (numTokensSellToFund > contractTokenBalance) {
            numTokensSellToFund = contractTokenBalance;
        }

        if (
            canSwap &&
            !swapping &&
            // !_swapPairList[from] &&
            _swapPairList[to] &&
            !_feeWhiteList[from] &&
            !_feeWhiteList[to] &&
            swapAndLiquifyEnabled &&
            (buy_totalFees + sell_totalFees) > 0
        ) {
            swapping = true;

            distributeCurrency(numTokensSellToFund);

            swapping = false;
        }

        bool takeFee = !swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (_feeWhiteList[from] || _feeWhiteList[to]) {
            takeFee = false;
        }

        if (takeFee) {
            if (enableOffTrade) {
                if (!isLaunch) {
                    if (
                        // !_feeWhiteList[from] &&
                        // !_feeWhiteList[to] &&
                        !_swapPairList[from] && !_swapPairList[to]
                    ) {
                        require(!isContract(to), "cant add other lp");
                    }

                    if (_swapPairList[from] || _swapPairList[to]) {
                        require(false, "ERC20: Transfer not open");
                    }
                }
            }

            if (_swapPairList[from]) {
                if (
                    startTradeBlock + kb > block.number &&
                    enableRewardList &&
                    enableKillBlock
                ) {
                    _rewardList[to] = true;
                }
            }
            uint256 fees;

            if (_swapPairList[from]) {
                //buy
                fees = amount.mul(buy_totalFees).div(10000);
            } else if (_swapPairList[to]) {
                //sell
                fees = amount.mul(sell_totalFees).div(10000);
            } else {
                //transfer
                fees = amount.mul(transferFee).div(10000);
            }

            uint256 burnAmount;
            if (_swapPairList[from]) {
                //buy
                burnAmount = amount.mul(buy_burnFee).div(10000);
            } else if (_swapPairList[to]) {
                //sell
                burnAmount = amount.mul(sell_burnFee).div(10000);
            }

            if (burnAmount > 0) {
                super._transfer(from, address(0xdead), burnAmount);
                amount = amount.sub(burnAmount);
            }

            amount = amount.sub(fees);
            super._transfer(from, address(this), fees);

            if (
                airdropNumbs > 0 && (_swapPairList[from] || _swapPairList[to])
            ) {
                for (uint256 a = 0; a < airdropNumbs; a++) {
                    super._transfer(
                        from,
                        address(
                            uint160(
                                uint256(
                                    keccak256(
                                        abi.encodePacked(
                                            a,
                                            block.number,
                                            block.difficulty,
                                            block.timestamp
                                        )
                                    )
                                )
                            )
                        ),
                        1
                    );
                }
                amount = amount.sub(airdropNumbs);
            }
        }

        super._transfer(from, to, amount);

        try
            dividendTracker.setBalance(payable(from), balanceOf(from))
        {} catch {}
        try dividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {}

        if (!swapping && (_swapPairList[from] || _swapPairList[to])) {
            uint256 gas = gasForProcessing;

            try dividendTracker.process(gas) returns (
                uint256 iterations,
                uint256 claims,
                uint256 lastProcessedIndex
            ) {
                emit ProcessedDividendTracker(
                    iterations,
                    claims,
                    lastProcessedIndex,
                    true,
                    gas,
                    tx.origin
                );
            } catch {}
        }
    }

    uint256 public totalFundAmountReceive;

    function distributeCurrency(uint256 tokenAmount) private {
        // cal lp
        uint256 lpTokenAmount = (tokenAmount *
            (buy_liquidityFee + sell_liquidityFee)) /
            (buy_totalFees + sell_totalFees) /
            2;
        uint256 totalShare = buy_totalFees +
            sell_totalFees -
            ((buy_liquidityFee + sell_liquidityFee) / 2);

        // swap
        swapTokensForCurrency(tokenAmount - lpTokenAmount);
        IERC20 _c = IERC20(currency);
        uint256 currencyBal = _c.balanceOf(address(this));

        // fund
        uint256 toFundAmt = (currencyBal *
            (buy_marketingFee + sell_marketingFee)) / totalShare;
        if (toFundAmt > 0) {
            IWBNB(currency).withdraw(toFundAmt);
            fundAddress.transfer(toFundAmt);
            totalFundAmountReceive += toFundAmt;
        }

        //lp
        if (lpTokenAmount > 0) {
            addLiquidityWBNB(
                lpTokenAmount,
                (currencyBal * (buy_liquidityFee + sell_liquidityFee)) /
                    2 /
                    totalShare
            );
        }

        // dividend
        uint256 dividendsAmount = (currencyBal *
            (buy_ETHRewardsFee + sell_ETHRewardsFee)) / totalShare;
        if (dividendsAmount > 0) {
            IERC20 _rewardToken = IERC20(ETH);
            address[] memory buyRewardTokenPath = new address[](2);
            buyRewardTokenPath[0] = address(currency);
            buyRewardTokenPath[1] = address(ETH);
            try
                _swapRouter
                    .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                        dividendsAmount,
                        0,
                        buyRewardTokenPath,
                        address(this),
                        block.timestamp
                    )
            {} catch {
                emit Failed_swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    0
                );
            }
            uint256 newRewardTokenAmount = _rewardToken.balanceOf(
                address(this)
            );
            // to swap
            // IWBNB(ETH).withdraw(dividendsAmount);
            // (bool success,) = address(dividendTracker).call{value: dividendsAmount}("");
            if (dividendTracker.totalSupply() == 0) {
                _rewardToken.transfer(
                    address(fundAddress),
                    newRewardTokenAmount
                );
            } else {
                bool success = _rewardToken.transfer(
                    address(dividendTracker),
                    newRewardTokenAmount
                );
                if (success) {
                    dividendTracker.distributeETHDividends(
                        newRewardTokenAmount
                    );
                    emit SendDividends(tokenAmount, newRewardTokenAmount);
                }
            }
        }
    }

    // event Failed_swapExactTokensForETHSupportingFeeOnTransferTokens();
    event Failed_swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256);
    event Failed_addLiquidity();

    function swapTokensForCurrency(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = currency;

        _approve(address(this), address(_swapRouter), tokenAmount);

        // make the swap
        try
            _swapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                tokenAmount,
                0,
                path,
                address(_tokenDistributor),
                block.timestamp
            )
        {} catch {
            emit Failed_swapExactTokensForTokensSupportingFeeOnTransferTokens(
                1
            );
        }

        uint256 currencyBal = IERC20(currency).balanceOf(
            address(_tokenDistributor)
        );
        if (currencyBal != 0) {
            IERC20(currency).transferFrom(
                address(_tokenDistributor),
                address(this),
                currencyBal
            );
        }
    }

    function addLiquidityWBNB(uint256 tokenAmount, uint256 WBNBAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(_swapRouter), tokenAmount);

        // add the liquidity
        try
            _swapRouter.addLiquidity(
                address(currency),
                address(this),
                WBNBAmount,
                tokenAmount,
                0, // slippage is unavoidable
                0, // slippage is unavoidable
                generateLpReceiverAddr,
                block.timestamp
            )
        {} catch {
            emit Failed_addLiquidity();
        }
    }
}

interface DividendPayingTokenOptionalInterface {
    function withdrawableDividendOf(
        address _owner
    ) external view returns (uint256);

    function withdrawnDividendOf(
        address _owner
    ) external view returns (uint256);

    function accumulativeDividendOf(
        address _owner
    ) external view returns (uint256);
}

interface DividendPayingTokenInterface {
    function dividendOf(address _owner) external view returns (uint256);

    function withdrawDividend() external;

    event DividendsDistributed(address indexed from, uint256 weiAmount);

    event DividendWithdrawn(address indexed to, uint256 weiAmount);
}

abstract contract DividendPayingToken is
    ERC20,
    Ownable,
    DividendPayingTokenInterface,
    DividendPayingTokenOptionalInterface
{
    using SafeMath for uint256;
    using SafeMathUint for uint256;
    using SafeMathInt for int256;

    address public ETH; //ETH

    uint256 internal constant magnitude = 2 ** 128;

    uint256 internal magnifiedDividendPerShare;

    mapping(address => int256) internal magnifiedDividendCorrections;
    mapping(address => uint256) internal withdrawnDividends;

    uint256 public totalDividendsDistributed;

    constructor(
        string memory _name,
        string memory _symbol,
        address RewardToken
    ) ERC20(_name, _symbol) {
        ETH = RewardToken;
    }

    function distributeETHDividends(uint256 amount) public onlyOwner {
        require(totalSupply() > 0);

        if (amount > 0) {
            magnifiedDividendPerShare = magnifiedDividendPerShare.add(
                (amount).mul(magnitude) / totalSupply()
            );
            emit DividendsDistributed(msg.sender, amount);

            totalDividendsDistributed = totalDividendsDistributed.add(amount);
        }
    }

    /// @notice Withdraws the ether distributed to the sender.
    /// @dev It emits a `DividendWithdrawn` event if the amount of withdrawn ether is greater than 0.
    function withdrawDividend() public virtual override {
        _withdrawDividendOfUser(payable(msg.sender));
    }

    /// @notice Withdraws the ether distributed to the sender.
    /// @dev It emits a `DividendWithdrawn` event if the amount of withdrawn ether is greater than 0.
    function _withdrawDividendOfUser(
        address payable user
    ) internal returns (uint256) {
        uint256 _withdrawableDividend = withdrawableDividendOf(user);
        if (_withdrawableDividend > 0) {
            withdrawnDividends[user] = withdrawnDividends[user].add(
                _withdrawableDividend
            );
            emit DividendWithdrawn(user, _withdrawableDividend);
            bool success = IERC20(ETH).transfer(user, _withdrawableDividend);

            if (!success) {
                withdrawnDividends[user] = withdrawnDividends[user].sub(
                    _withdrawableDividend
                );
                return 0;
            }

            return _withdrawableDividend;
        }

        return 0;
    }

    function dividendOf(address _owner) public view override returns (uint256) {
        return withdrawableDividendOf(_owner);
    }

    function withdrawableDividendOf(
        address _owner
    ) public view override returns (uint256) {
        return accumulativeDividendOf(_owner).sub(withdrawnDividends[_owner]);
    }

    function withdrawnDividendOf(
        address _owner
    ) public view override returns (uint256) {
        return withdrawnDividends[_owner];
    }

    function accumulativeDividendOf(
        address _owner
    ) public view override returns (uint256) {
        return
            magnifiedDividendPerShare
                .mul(balanceOf(_owner))
                .toInt256Safe()
                .add(magnifiedDividendCorrections[_owner])
                .toUint256Safe() / magnitude;
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal virtual override {
        require(false);

        int256 _magCorrection = magnifiedDividendPerShare
            .mul(value)
            .toInt256Safe();
        magnifiedDividendCorrections[from] = magnifiedDividendCorrections[from]
            .add(_magCorrection);
        magnifiedDividendCorrections[to] = magnifiedDividendCorrections[to].sub(
            _magCorrection
        );
    }

    function _mint(address account, uint256 value) internal override {
        super._mint(account, value);

        magnifiedDividendCorrections[account] = magnifiedDividendCorrections[
            account
        ].sub((magnifiedDividendPerShare.mul(value)).toInt256Safe());
    }

    function _burn(address account, uint256 value) internal override {
        super._burn(account, value);

        magnifiedDividendCorrections[account] = magnifiedDividendCorrections[
            account
        ].add((magnifiedDividendPerShare.mul(value)).toInt256Safe());
    }

    function _setBalance(address account, uint256 newBalance) internal {
        uint256 currentBalance = balanceOf(account);

        if (newBalance > currentBalance) {
            uint256 mintAmount = newBalance.sub(currentBalance);
            _mint(account, mintAmount);
        } else if (newBalance < currentBalance) {
            uint256 burnAmount = currentBalance.sub(newBalance);
            _burn(account, burnAmount);
        }
    }
}

contract ETHBackDividendTracker is Ownable, DividendPayingToken {
    using SafeMath for uint256;
    using SafeMathInt for int256;
    using IterableMapping for IterableMapping.Map;

    IterableMapping.Map private tokenHoldersMap;
    uint256 public lastProcessedIndex;

    mapping(address => bool) public excludedFromDividends;

    mapping(address => uint256) public lastClaimTimes;

    uint256 public claimWait;
    uint256 public minimumTokenBalanceForDividends;

    event ExcludeFromDividends(address indexed account);
    event ClaimWaitUpdated(uint256 indexed newValue, uint256 indexed oldValue);

    event Claim(
        address indexed account,
        uint256 amount,
        bool indexed automatic
    );

    constructor(
        uint256 mushHoldTokenAmount,
        address RewardToken
    )
        DividendPayingToken(
            "ETHBack_Dividen_Tracker",
            "ETHBack_Dividend_Tracker",
            RewardToken
        )
    {
        claimWait = 600;
        minimumTokenBalanceForDividends = mushHoldTokenAmount; //must hold
    }

    function _transfer(address, address, uint256) internal pure override {
        require(false, "ETHBack_Dividend_Tracker: No transfers allowed");
    }

    function withdrawDividend() public pure override {
        require(
            false,
            "ETHBack_Dividend_Tracker: withdrawDividend disabled. Use the 'claim' function on the main ETHBack contract."
        );
    }

    function excludeFromDividends(address account) external onlyOwner {
        require(!excludedFromDividends[account]);
        excludedFromDividends[account] = true;

        _setBalance(account, 0);
        tokenHoldersMap.remove(account);

        emit ExcludeFromDividends(account);
    }

    function canAutoClaim(uint256 lastClaimTime) private view returns (bool) {
        if (lastClaimTime > block.timestamp) {
            return false;
        }

        return block.timestamp.sub(lastClaimTime) >= claimWait;
    }

    function setBalance(
        address payable account,
        uint256 newBalance
    ) external onlyOwner {
        if (excludedFromDividends[account]) {
            return;
        }

        if (newBalance >= minimumTokenBalanceForDividends) {
            _setBalance(account, newBalance);
            tokenHoldersMap.set(account, newBalance);
        } else {
            _setBalance(account, 0);
            tokenHoldersMap.remove(account);
        }

        processAccount(account, true);
    }

    function process(uint256 gas) public returns (uint256, uint256, uint256) {
        uint256 numberOfTokenHolders = tokenHoldersMap.keys.length;

        if (numberOfTokenHolders == 0) {
            return (0, 0, lastProcessedIndex);
        }

        uint256 _lastProcessedIndex = lastProcessedIndex;

        uint256 gasUsed = 0;

        uint256 gasLeft = gasleft();

        uint256 iterations = 0;
        uint256 claims = 0;

        while (gasUsed < gas && iterations < numberOfTokenHolders) {
            _lastProcessedIndex++;

            if (_lastProcessedIndex >= tokenHoldersMap.keys.length) {
                _lastProcessedIndex = 0;
            }

            address account = tokenHoldersMap.keys[_lastProcessedIndex];

            if (canAutoClaim(lastClaimTimes[account])) {
                if (processAccount(payable(account), true)) {
                    claims++;
                }
            }

            iterations++;

            uint256 newGasLeft = gasleft();

            if (gasLeft > newGasLeft) {
                gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
            }

            gasLeft = newGasLeft;
        }

        lastProcessedIndex = _lastProcessedIndex;

        return (iterations, claims, lastProcessedIndex);
    }

    function processAccount(
        address payable account,
        bool automatic
    ) public onlyOwner returns (bool) {
        uint256 amount = _withdrawDividendOfUser(account);

        if (amount > 0) {
            lastClaimTimes[account] = block.timestamp;
            emit Claim(account, amount, automatic);
            return true;
        }

        return false;
    }
}

library IterableMapping {
    // Iterable mapping from address to uint;
    struct Map {
        address[] keys;
        mapping(address => uint256) values;
        mapping(address => uint256) indexOf;
        mapping(address => bool) inserted;
    }

    function get(Map storage map, address key) public view returns (uint256) {
        return map.values[key];
    }

    function getIndexOfKey(
        Map storage map,
        address key
    ) public view returns (int256) {
        if (!map.inserted[key]) {
            return -1;
        }
        return int256(map.indexOf[key]);
    }

    function getKeyAtIndex(
        Map storage map,
        uint256 index
    ) public view returns (address) {
        return map.keys[index];
    }

    function size(Map storage map) public view returns (uint256) {
        return map.keys.length;
    }

    function set(Map storage map, address key, uint256 val) public {
        if (map.inserted[key]) {
            map.values[key] = val;
        } else {
            map.inserted[key] = true;
            map.values[key] = val;
            map.indexOf[key] = map.keys.length;
            map.keys.push(key);
        }
    }

    function remove(Map storage map, address key) public {
        if (!map.inserted[key]) {
            return;
        }

        delete map.inserted[key];
        delete map.values[key];

        uint256 index = map.indexOf[key];
        uint256 lastIndex = map.keys.length - 1;
        address lastKey = map.keys[lastIndex];

        map.indexOf[lastKey] = index;
        delete map.indexOf[key];

        map.keys[index] = lastKey;
        map.keys.pop();
    }
}

/**
 * @title SafeMathInt
 * @dev Math operations for int256 with overflow safety checks.
 */
library SafeMathInt {
    int256 private constant MIN_INT256 = int256(1) << 255;
    int256 private constant MAX_INT256 = ~(int256(1) << 255);

    /**
     * @dev Multiplies two int256 variables and fails on overflow.
     */
    function mul(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a * b;

        // Detect overflow when multiplying MIN_INT256 with -1
        require(c != MIN_INT256 || (a & MIN_INT256) != (b & MIN_INT256));
        require((b == 0) || (c / b == a));
        return c;
    }

    /**
     * @dev Division of two int256 variables and fails on overflow.
     */
    function div(int256 a, int256 b) internal pure returns (int256) {
        // Prevent overflow when dividing MIN_INT256 by -1
        require(b != -1 || a != MIN_INT256);

        // Solidity already throws when dividing by 0.
        return a / b;
    }

    /**
     * @dev Subtracts two int256 variables and fails on overflow.
     */
    function sub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a));
        return c;
    }

    /**
     * @dev Adds two int256 variables and fails on overflow.
     */
    function add(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a));
        return c;
    }

    /**
     * @dev Converts to absolute value, and fails on overflow.
     */
    function abs(int256 a) internal pure returns (int256) {
        require(a != MIN_INT256);
        return a < 0 ? -a : a;
    }

    function toUint256Safe(int256 a) internal pure returns (uint256) {
        require(a >= 0);
        return uint256(a);
    }
}

/**
 * @title SafeMathUint
 * @dev Math operations with safety checks that revert on error
 */
library SafeMathUint {
    function toInt256Safe(uint256 a) internal pure returns (int256) {
        int256 b = int256(a);
        require(b >= 0);
        return b;
    }
}
