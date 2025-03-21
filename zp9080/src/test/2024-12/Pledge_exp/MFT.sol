pragma solidity ^0.8.6;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; 
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


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

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract ERC20 is Context, IERC20 {
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
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
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

        _balances[sender] = _balances[sender].sub(amount);

        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

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
}
interface IPancakeRouter01 {
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
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}
interface IPancakeRouter02 is IPancakeRouter01 {
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

    function getAmountsOut(uint amountIn, address[] calldata path)
      external view returns (uint[] memory amounts);
}

interface IUniswapV2Factory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}
contract MFT is ERC20, Ownable {
    using SafeMath for uint256;

    IPancakeRouter02 public _swapRouter;

    address public _mainPair;

    address public _targetAdress = 0x000000000000000000000000000000000000dEaD;

    address public _usdt = 0x55d398326f99059fF775485246999027B3197955;

    mapping(address => bool) public _swapPairList;

    mapping(address => bool) public _feeWhiteList;

    mapping(address => bool) public _blackList;

    mapping(address => uint256) public _lastBlockTraded;

    uint256 public constant MAX = ~uint256(0);

    bool public swapStart = false;

    uint256 public _startTime;


    constructor (
    )
        ERC20("MFT", "MFT")
    {
        _mint(msg.sender, 1000000000 * 10 ** decimals());

        IPancakeRouter02 swapRouter = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        _swapRouter = swapRouter;
        IUniswapV2Factory swapFactory = IUniswapV2Factory(swapRouter.factory());
        address swapPair = swapFactory.createPair(address(this), _usdt);

        _mainPair = swapPair;
        _swapPairList[_mainPair] = true;

        _feeWhiteList[msg.sender] = true;

        _blackList[0x36696169C63e42cd08ce11f5deeBbCeBae652050] = true;
        _blackList[0x92b7807bF19b7DDdf89b706143896d05228f3121] = true;
        _blackList[0x172fcD41E0913e95784454622d1c3724f546f849] = true;
        _blackList[0x46A15B0b27311cedF172AB29E4f4766fbE7F4364] = true;
        _blackList[0x556B9306565093C855AEA9AE92A594704c2Cd59e] = true;
    }
    
    function _mint(address account, uint256 amount) internal override {
        super._mint(account, amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        require(!_blackList[sender] && !_blackList[recipient], "no swap");

        require(recipient != sender, "ERC20: transfer to the same address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0);

        if (_feeWhiteList[sender] || _feeWhiteList[recipient]) {
            super._transfer(sender, recipient, amount);
            return;
        }

        require(swapStart, "no start");

        if (_swapPairList[recipient]) {
            require(_lastBlockTraded[sender] < block.number, "Cannot trade twice in the same block");
            _lastBlockTraded[sender] = block.number; 
        } else if (_swapPairList[sender]) {
            require(_lastBlockTraded[recipient] != block.number, "Cannot trade twice in the same block");
            _lastBlockTraded[recipient] = block.number; 
        }
        if(tx.origin != msg.sender){
            require(_lastBlockTraded[msg.sender] < block.number, "Cannot trade twice in the same block orgin");
            _lastBlockTraded[msg.sender] = block.number; 
        }

        if(sender == _mainPair){
            if (!_feeWhiteList[sender] && !_feeWhiteList[recipient]) {
                    require(block.timestamp > _startTime, "time error");
            }
        }

        if(recipient == _mainPair || sender == _mainPair){
            super._transfer(sender, _targetAdress, amount * 3 / 100);
            super._transfer(sender, recipient, amount * 97 / 100);
            return;
        }else{
            super._transfer(sender, recipient, amount);
        }
            

    }

    function setB(address _target, bool _bool) external onlyOwner{
        _blackList[_target] = _bool;
    }

    function setWhiteList(address _target, bool _bool) external onlyOwner{
        _feeWhiteList[_target] = _bool;
    }

    function setStart(bool _bool) external onlyOwner{
        swapStart = _bool;
    }

    function setTargetAddress(address _target) external onlyOwner{
        _targetAdress = _target;
    }

    function setUAddress(address _target) external onlyOwner{
        _usdt = _target;
    }

    function setStartTime(uint256 _time) external onlyOwner{
        _startTime = _time;
    }

}
