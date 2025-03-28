pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;


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

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

library Address {

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

   
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }

    
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }


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

contract Ownable is Context {
    address internal _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
     function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );
}

library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}

library EnumerableSet {
   
    struct Set {
        bytes32[] _values;
        mapping (bytes32 => uint256) _indexes;
    }

    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    function _remove(Set storage set, bytes32 value) private returns (bool) {
        
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) { // Equivalent to contains(set, value)
            
            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

    
            bytes32 lastvalue = set._values[lastIndex];

            set._values[toDeleteIndex] = lastvalue;
            // Update the index for the moved value
            set._indexes[lastvalue] = toDeleteIndex + 1; // All indexes are 1-based

            set._values.pop();

            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

   
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        require(set._values.length > index, "EnumerableSet: index out of bounds");
        return set._values[index];
    }

    struct Bytes32Set {
        Set _inner;
    }

    
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }


    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

   
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    struct AddressSet {
        Set _inner;
    }

    
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }


    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

   
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

   
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    struct UintSet {
        Set _inner;
    }

    
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }
}

interface IUniswapV2Pair {
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function sync() external;
}


contract BBOXToken is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcludedFromFee;

    uint8 private _decimals = 9;
    uint256 private _tTotal = 2100000 * 10 ** 9;

    string private _name = "BBOX";
    string private _symbol = "BBOX";
    
    uint256 public _burnFee = 10;
    uint256 public _lPFee = 20;

    uint256 public _shareFee = 30;
    uint[] internal shareConfig = [20,2,2,2,2,2];

    uint256 public totalFee = 60;
    IUniswapV2Router02 public uniswapV2Router;

    mapping(address => bool) public ammPairs;

    bool inSwapAndLiquify;
    
    address public uniswapV2Pair;
    address public wbnb;    
    address public holder;
    address public tokenReceiver;

    uint public recommeCondition = 1e8;

    address constant public rootAddress = address(0x000000000000000000000000000000000000dEaD);
    
    mapping (address => address) public _recommerMapping;

    struct Interest{
        uint256 index;
        uint256 period;
        uint256 lastSendTime;
        uint minAward;
        uint award;
        IERC20  token;
        EnumerableSet.AddressSet tokenHolder;
    }
    uint256 distributorGas = 500000;
    address  fromAddress;
    address  toAddress;
    Interest internal lpInterest;

    uint public sellSwapLimitRate = 90;
    uint public sellSwapTimeLimit = 20;
    mapping(address => uint) public lastBuyTime;

    bool public pairAmountChange = true;
    uint public pairAmount;
    address public initPoolAddress;

    uint public addLiquidityValue = 1e6;

    constructor (
        address _route,
        address _holder,
        address _initPoolAddress) public {
        
        initPoolAddress = _initPoolAddress;
         holder = _holder;
        _recommerMapping[rootAddress] = address(0xdeaddead);
        _recommerMapping[holder] = rootAddress;
       
        _tOwned[holder] = _tTotal;
        
        _isExcludedFromFee[holder] = true;
        _isExcludedFromFee[address(this)] = true;

        uniswapV2Router = IUniswapV2Router02(_route);

        wbnb = uniswapV2Router.WETH();
         
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), wbnb);
        
        ammPairs[uniswapV2Pair] = true;
        _owner = msg.sender;

        lpInterest.token = IERC20(uniswapV2Pair);
        lpInterest.lastSendTime = block.timestamp;
        lpInterest.minAward = 1e6;
        lpInterest.period = 86400;
        emit Transfer(address(0), _holder, _tTotal);
    }

    struct InterestInfo{
        uint period;
        uint lastSendTime;
        uint award;
        uint count;
    }
    function getInterestInfo()external view returns(InterestInfo memory lpI){
        lpI.period = lpInterest.period;
        lpI.lastSendTime = lpInterest.lastSendTime;
        lpI.award = lpInterest.award;
        lpI.count = lpInterest.tokenHolder.length();
    }

    function setAmmPair(address pair,bool hasPair)external onlyOwner{
        ammPairs[pair] = hasPair;
    }

    function setTxAmount(uint rc,uint dbg,uint sslr,uint sstl)external onlyOwner{
        recommeCondition = rc;
        distributorGas = dbg;
        sellSwapLimitRate = sslr;
        sellSwapTimeLimit = sstl;
    }

    function setInterest( uint lpMA,uint alv,uint peroid)external onlyOwner{
        lpInterest.minAward = lpMA;
        addLiquidityValue = alv;
        lpInterest.period = peroid;
    }

    function setpairAmountChange(bool change)external onlyOwner{
        pairAmountChange = change;
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
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _tOwned[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
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
    
    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }
    
    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

     function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }
    
    receive() external payable {}

    function _take(uint256 tValue,address from,address to) private {
        _tOwned[to] = _tOwned[to].add(tValue);
        emit Transfer(from, to, tValue);
    }
    
    function getForefathers(address owner,uint num) internal view returns(address[] memory fathers){
        fathers = new address[](num);
        address parent  = owner;
        for( uint i = 0; i < num; i++){
            parent = _recommerMapping[parent];
            if( parent == rootAddress || parent == address(0) ) break;
            fathers[i] = parent;
        }
    }

    function _takeShare(uint tShare,address from,address user) private {

        address[] memory farthers = getForefathers(user,shareConfig.length);

        uint len = farthers.length;
        uint sended = 0;
        for( uint i = 0; i < len; i++ ){
            address parent = farthers[i];
            if( parent == address(0)) break;
            uint tv = tShare * shareConfig[i] / _shareFee;
            _take(tv, from, parent);
            sended += tv;
        }  
        
        if( tShare > sended && tShare - sended > 10000 ){
            _take(tShare - sended,from,address(0));
        }
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function addRelationEx(address recommer,address user) internal {
        if( 
            recommer != user 
            && _recommerMapping[user] == address(0x0) 
            && _recommerMapping[recommer] != address(0x0) ){
                _recommerMapping[user] = recommer;
        }       
    }

    struct Param{
        bool takeFee;
        uint tTransferAmount;
        uint tLP;
        uint tBurn;
        uint tShare;
        address user;
    }

     function _initParam(uint256 tAmount,Param memory param) private view  {
        param.tLP = tAmount * _lPFee / 1000;
        param.tBurn = tAmount * _burnFee / 1000;
        param.tShare = tAmount * _shareFee / 1000;
        uint tFee = tAmount * totalFee / 1000;
        param.tTransferAmount = tAmount.sub(tFee);
    }

    function _takeFee(Param memory param,address from)private {
        if( param.tLP > 0 ){
            _take(param.tLP, from, address(this));
            lpInterest.award += param.tLP;
        }
        if( param.tBurn > 0 ){
            _take(param.tBurn, from, address(0));
        }
        if( param.tShare > 0 ){
             _takeShare(param.tShare,from,param.user);
        }
    }

    function _isLiquidity(address from,address to)internal view returns(bool isAdd,bool isDel){

        if( ammPairs[to] ){
           isAdd = address(uniswapV2Router).balance > addLiquidityValue;
        }

        // if( ammPairs[from] ){
        //     isDel = IERC20(wbnb).balanceOf(address(uniswapV2Router)) > addLiquidityValue;
        // }
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if( 
            !_isContract(to) 
            && _recommerMapping[to] == address(0) 
            && amount >= recommeCondition){
            
            if( ammPairs[from]  ){
                addRelationEx(holder,to);
            }else{
                addRelationEx(from,to);
            }
        }

        bool isAddLiquidity;
        bool isDelLiquidity;
        ( isAddLiquidity, isDelLiquidity) = _isLiquidity(from,to);

        if( 
            pairAmountChange 
            && !isAddLiquidity
            && pairAmount > 0 
            && !ammPairs[from] 
            && pairAmount < balanceOf(uniswapV2Pair)){

            uint v = pairAmount;
            pairAmount = 0;
            _tOwned[uniswapV2Pair] =  _tOwned[uniswapV2Pair].sub(v);
            _tOwned[address(0)] = _tOwned[address(0)].add(v);
            emit Transfer(uniswapV2Pair, address(0), v);

            IUniswapV2Pair(uniswapV2Pair).sync();
        }
       
        Param memory param;
        param.tTransferAmount = amount;
        param.user = to;

        bool takeFee = true;
        if( 
            _isExcludedFromFee[from] 
            || _isExcludedFromFee[to] 
            || isAddLiquidity 
            || to == address(uniswapV2Router)){
            takeFee = false;
        }

        if( takeFee && ammPairs[from] ){
            param.user = to;
            pairAmount += amount * 3 / 100;
            lastBuyTime[to] = block.timestamp;
        }

        if( takeFee && ammPairs[to] ){
            param.user = from;
            pairAmount += amount * 3 / 100;
            require(block.timestamp > lastBuyTime[from] + sellSwapTimeLimit,"sell limit time");
            require(amount <= balanceOf(from) * sellSwapLimitRate / 100 ,"sell limit amount");
        }

        if( isAddLiquidity &&  IERC20(uniswapV2Pair).totalSupply() == 0 && ammPairs[to]  ){
            require(from == initPoolAddress,"not allow");
        }   

        param.takeFee = takeFee;
        if( takeFee ){
            _initParam(amount,param);
        }
        
        _tokenTransfer(from,to,amount,param);

        if (fromAddress == address(0)) fromAddress = from;
        if (toAddress == address(0)) toAddress = to;
        if ( !ammPairs[fromAddress] ) {
            setEst(lpInterest,fromAddress);
        }
        if ( !ammPairs[toAddress] ) {
            setEst(lpInterest,toAddress);
        }
        fromAddress = from;
        toAddress = to;

        if( 
            from != address(this) 
            && lpInterest.lastSendTime + lpInterest.period < block.timestamp
            && lpInterest.award > 0
            && lpInterest.award <= balanceOf(address(this))
            && lpInterest.token.totalSupply() > 1e5){
            
            lpInterest.lastSendTime = block.timestamp;
            processEst(lpInterest, distributorGas);
        }
    }

    function _tokenTransfer(address sender, address recipient, uint256 tAmount,Param memory param) private {
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _tOwned[recipient] = _tOwned[recipient].add(param.tTransferAmount);
         emit Transfer(sender, recipient, param.tTransferAmount);
        if(param.takeFee){
            _takeFee(param,sender);
        }
    }

    function donateDust(address addr, uint256 amount) external onlyOwner {
        TransferHelper.safeTransfer(addr, _msgSender(), amount);
    }

    function donateEthDust(uint256 amount) external onlyOwner {
        TransferHelper.safeTransferETH(_msgSender(), amount);
    }

     function _isContract(address a) internal view returns(bool){
        uint256 size;
        assembly {size := extcodesize(a)}
        return size > 0;
    }
    
    function processEst(Interest storage est,uint256 gas) private {
        uint256 shareholderCount = est.tokenHolder.length();

        if (shareholderCount == 0) return;

        uint256 nowbanance = est.award;
        uint256 surplusAmount = nowbanance;
        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();
        uint256 iterations = 0;
        uint index = est.index;
        uint minAward = est.minAward;

        uint ts = est.token.totalSupply();
        while (gasUsed < gas && iterations < shareholderCount) {
            if (index >= shareholderCount) {
                index = 0;
            }

            address shareholder = est.tokenHolder.at(index);

            uint256 amount = nowbanance.mul(est.token.balanceOf(shareholder)).div(ts);

            if (balanceOf(address(this)) < amount ||  surplusAmount < amount ) break;

            if (amount >= minAward) {
                surplusAmount -= amount;
                _tOwned[address(this)] = _tOwned[address(this)].sub(amount);
                _tOwned[shareholder] = _tOwned[shareholder].add(amount);
                emit Transfer(address(this), shareholder, amount);
            }
            gasUsed = gasUsed.add(gasLeft.sub(gasleft()));
            gasLeft = gasleft();
            iterations++;
            index ++;
        }
        est.index = index;
        est.award = surplusAmount;
    }

    function setEst(Interest storage est, address owner) private {
       
        if( est.tokenHolder.contains(owner) ){
            if( est.token.balanceOf(owner) == 0 ) {
                est.tokenHolder.remove(owner);
            }
            return;
        }

        if( est.token.balanceOf(owner) > 0 ){
            est.tokenHolder.add(owner);
        }
    }
}
