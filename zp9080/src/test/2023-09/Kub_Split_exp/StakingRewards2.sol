pragma solidity 0.8.4;

/**
 * @dev Collection of functions related to the address type
 */

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
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
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
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
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
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
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}
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
    function symbol() external view returns (string memory);
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
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}
interface ISwapFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}
interface IRouter {
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
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactTokensForTokens(
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
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}
pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via _msgSender() and msg.data, they should not be accessed in such a direct
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
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
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
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
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
interface pairs{
   function setIRouter(address _IRouter)external;
   function IRouter()external view returns (address);
}
interface kub {
    function users(address,address)external view returns (uint,uint,uint);
    function FISTs(address)external view returns (uint,uint,uint);
    function teams(address)external view returns (uint,uint,uint);
    function upaddress(address)external view returns (address);
    function usersAddr(address)external view returns (uint,uint,uint,uint);
}
contract StakingRewards is Ownable {
    using SafeMath for uint256;
    IRouter public IRouters;
    uint private constant RATE_DAY= 86400;
    address private USDT;
    address public auditor;
    address public bunToken;
    address public DEX;
    address public KUBDEX=0xfDE81E1f340C3ec271142723781df9e685653213;
    address public LPaddr;
    address public KUB=0x808602d91e58f2d58D7C09306044b88234ab4628;//KUB
    address public FISTtoken;
    //11
    address public WBNB=0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    mapping (address=>address)public upaddress;
    mapping (address=>mapping (address=>uint)) public NFTsw;
    mapping (address=>address) public myReward;
    mapping (address=>address)public TokenOwner;
    mapping (address=>mapping (address=>user))public users;
    mapping (address=>user)public usersAddr;
    mapping (address=>bool)public listToken;
    mapping (address=>bool)public PairToken;
    mapping (address=>team)public teams;
    mapping (address=>mapping(address=>team))public teamsw;
    mapping (uint=>uint)public level;
    mapping (uint=>uint)public bl;
    mapping (address=>FIST)public FISTs;
    uint public uid=1;
    struct user{
        uint mnu;
        uint tim;
        uint yz;
        uint tz;
        address[] arrs;
    }
    struct team{
        uint A1;
        uint lv;
        uint value;
        uint _time;
        uint sum;
    }
    struct FIST{
        uint allPower;
        uint dayValue;
        uint TIME;
    }
    constructor() {  
        USDT=0x55d398326f99059fF775485246999027B3197955;//USDT
        auditor=msg.sender;
        bunToken=0x000000000000000000000000000000000000dEaD;
        DEX=0x10ED43C718714eb63d5aA57B78B54704E256024E;
    }
    receive() external payable{ 
    }
    function setLevels(address token,address addr,uint _lv,uint au,uint bls)public {
        require(msg.sender == TokenOwner[token]);
        teams[addr].A1=au;
        teams[addr].lv=_lv;
    }
    function _team(address a1,address my,uint _value)internal {
        address up=a1;
        address up1=my;
        uint bnbb=71;
        uint lvvx=1;
        uint lkj=0;
        uint lkjs=0;
           for(uint k=0;k<100;k++){
               if(up !=address(0)){
                   teams[up].A1+=_value;
                   if(teams[up].lv >= lvvx){
                     lvvx=teams[up].lv;
                     lkj=lvvx*10;
                     if(bnbb > lkj){
                         if(lkj > lkjs){
                           NFTsw[up][up1]=lkj-lkjs;
                         }
                         lkjs+=lkj;                       
                     }else {
                         //NFTsw[up]=81 - bnbb;
                     }
                   }
               }
               up1=up;
               up=upaddress[up];
               if(up == address(0)){
                break ;
               }
           }
    }
     function _teamvalue(address a1,address my,uint _value)internal {
        address up=a1;
        address up1=my;
        uint lvv=1;
           for(uint k=0;k<100;k++){
               if(up !=address(0) && teams[up].lv >=lvv){
                   teamsw[up][up1].value+=_value;
               }
               up1=up;
               up=upaddress[up];
               if(up == address(0)){
                break;
               }
           }
    }
    function _Levels(address up,uint amount)public view returns (uint){
        uint _lv;
        if(amount >= level[7] && teams[up].lv == 6){
            _lv=7;
        }
        if(amount >= level[6] && teams[up].lv == 5){
            _lv=6;
        }
        if(amount >= level[5] && teams[up].lv == 4){
            _lv=5;
        }
        if(amount >= level[4] && teams[up].lv == 3){
            _lv=4;
        }
        if(amount >= level[3] && teams[up].lv == 2){
            _lv=3;
        }
        if(amount >= level[2] && teams[up].lv == 1){
            _lv=2;
        }
        if(amount >= level[1] && teams[up].lv == 0){
            _lv=1;
        }
        return _lv;
    }
    function stake(address token,address token1,address up,uint amount)external{
        require(usersAddr[up].tz > 0 || msg.sender == owner());
        require(PairToken[token1]);
        require(listToken[token]);
        require(amount >0,"amount can not be 0");
        IERC20(token1).transferFrom(msg.sender,address(this),amount);
        FISTs[token].allPower+=amount;
        uint _bl=getValue(token,msg.sender,amount);
        usersAddr[msg.sender].tz+=amount;
        if(usersAddr[msg.sender].tim ==0){
            usersAddr[msg.sender].tim=block.timestamp;
            usersAddr[msg.sender].mnu=_bl*FISTs[token].dayValue/1 ether;   
        }else {
            usersAddr[msg.sender].mnu=_bl*FISTs[token].dayValue/1 ether;
        }
      IERC20(token1).transfer(auditor,amount * bl[444] / 100);   
      uint buyToken=_buy(token,amount * bl[222] / 100,address(this));
      require(buyToken > 0);
        _addL(token,buyToken,amount*bl[333]/100,address(this));       
        if(upaddress[msg.sender] == address(0) && up != msg.sender){
           upaddress[msg.sender]=up;
           usersAddr[up].arrs.push(msg.sender);
        }
        _team(upaddress[msg.sender],msg.sender,amount);
    }
    function getValue(address token,address to,uint _va)public view returns (uint){
             uint lastValue=usersAddr[to].tz;
             uint myValue;
             if(FISTs[token].allPower > 0){
               myValue=(lastValue + _va)*1 ether /FISTs[token].allPower;
             }
             
             return myValue;
    }
    function updateKUB(address token,address sDEX,address addr)internal  {
        (uint a,,)=kub(sDEX).teams(addr);
        (,uint b1,,uint c1)=kub(sDEX).usersAddr(addr);
            teams[addr].A1=a;
            usersAddr[addr].tim=b1;
            usersAddr[addr].tz=c1;
            upaddress[addr]=kub(sDEX).upaddress(addr);
            usersAddr[upaddress[addr]].arrs.push(addr);
            if(FISTs[token].allPower==0){
              (uint a2,uint b2,uint b3)=kub(sDEX).FISTs(token);
              FISTs[token].allPower=a2;
              FISTs[token].dayValue=b2;
              FISTs[token].TIME=b3;
            }
    }
    function updatebstake(address token,address sDEX,address[] memory addr)public {
        require(msg.sender == auditor);
        for(uint i=0;i<addr.length;i++){
            updateKUB(token,sDEX,addr[i]);
       }

    }
    function updateU(address token,address my,uint coin)internal  {
        uint ups=4;
        uint rs;
        address addr=my;
        for(uint i=0;i<ups && i<4;i++){
            if(upaddress[addr]!= address(0)){
                rs++;
                uint mn=getUp(rs,coin);
                if(mn >0){
                  IERC20(token).transfer(upaddress[addr],getUp(rs,coin));
                }
              users[token][upaddress[addr]].yz+=getUp(rs,coin);
            }else {
                if(upaddress[addr]!= address(0)){
                  ups++;
                }
            }
            addr=upaddress[addr];
            if(rs >=4 || upaddress[addr]== address(0)){
               break;
            }
        }
    }
    function updateTeam()public {
        address[] memory teamq=usersAddr[msg.sender].arrs;
        address max;
        address min;
        uint nn;
        uint nn2;
        uint nn3;
        for(uint i=0;i<teamq.length;i++){
            uint mm=teams[teamq[i]].A1;
            if(mm > nn){
                nn=mm;
                max=teamq[i];
            }
        }
        for(uint u=0;u<teamq.length;u++){
            uint mm2=teams[teamq[u]].A1;
            if(mm2 > nn2 && teamq[u] != max){
                nn2=mm2;
                min=teamq[u];
                nn3+=mm2;
            }else {
                if(teamq[u] != max){
                    nn3+=mm2;
                }
            }
        }
        uint lvv=_Levels(msg.sender,nn3);
        if(min != address(0) && lvv > teams[msg.sender].lv){
           teams[msg.sender].lv=lvv;
        }
    }
    function setTokenOwner(address token,address addr,address splitLP,address _FISTtoken,address Splitdex)public{
        require(msg.sender == auditor);
        TokenOwner[token]=addr;
        LPaddr=splitLP;//splitLP
        FISTtoken=_FISTtoken;
        myReward[FISTtoken]=KUB;
        IRouters=IRouter(Splitdex);
        IERC20(FISTtoken).approve(address(address(IRouters)), 2 ** 256 - 1);
        IERC20(USDT).approve(address(address(IRouters)), 2 ** 256 - 1);
        IERC20(KUB).approve(address(address(IRouters)),2 ** 256 - 1);
        
    }
    function setListToken(address token,address token1,bool b,bool b1)public{
        require(msg.sender == auditor);
        listToken[token]=b;
        PairToken[token1]=b1;
    }
    function setLeveValue(address token)public{
        require(listToken[token]);
        require(teams[msg.sender].lv>=1);
        require(teams[msg.sender].lv<=7);
        uint amount;
        if(teams[msg.sender]._time == 0){
           teams[msg.sender]._time=block.timestamp; 
        }
        if(block.timestamp > teams[msg.sender]._time){
              address[] memory addr=usersAddr[msg.sender].arrs;
              for(uint i=0;i<addr.length;i++){
                  if(teams[msg.sender].lv == teams[addr[i]].lv){
                      pingLevel(token,msg.sender,addr[i]);
                  }else {
                     if(NFTsw[msg.sender][addr[i]] >0 && NFTsw[msg.sender][addr[i]] <81){
                        amount=teamsw[msg.sender][addr[i]].value * NFTsw[msg.sender][addr[i]] /100;
                        teamsw[msg.sender][addr[i]].value=0;
                        if(amount >0){
                          bool isok=IERC20(token).transfer(msg.sender,amount);
                          require(isok);
                          teams[msg.sender].value=0;
                          teams[msg.sender]._time=teams[msg.sender]._time+86400;
                          teams[msg.sender].sum+=amount;
                        }
                    }
                }
            }
        }
    }
    function getLs(address addrs)public view returns (uint){
        uint amount;
        address[] memory addr=usersAddr[addrs].arrs;
              for(uint i=0;i<addr.length;i++){
                amount+=teamsw[addrs][addr[i]].value;
              }
        return  amount;

    }
    function pingLevel(address token,address to1,address to2)private  {
        if(teamsw[to1][to2].value >0){
           IERC20(token).transfer(msg.sender,teamsw[to1][to2].value *10 /100);
           teamsw[to1][to2].value=0;
        }
    }
    function setIlevel(uint _level,uint _value,uint _bl)public{
        require(msg.sender == auditor);
        level[_level]=_value;
        bl[_level]=_bl;
        //222=70，333=20
    }
    function _buy(address _token,uint amount0In,address to) internal returns (uint){
        uint lastvalue=IERC20(_token).balanceOf(address(this));
           address[] memory path = new address[](2);
           path[0] = KUB;
           path[1] = _token; 
           IRouters.swapExactTokensForTokens(amount0In,0,path,to,block.timestamp+360);
           if(IERC20(_token).balanceOf(address(this)) >lastvalue){
               return IERC20(_token).balanceOf(address(this)) - lastvalue;
           }else {
               return 0;
           }

    }
    function _addL(address _token,uint amount0, uint amount1,address to)internal   {
        
        IRouters.addLiquidity(_token,KUB,amount0,amount1,0, 0,to,block.timestamp+100);
        //IRouters.addLiquidityETH{value : amount1}(_token,amount0,0, 0,to,block.timestamp+100);
    }
    function setSplitPrice(address token,address token1)public {
        if(block.timestamp > FISTs[token].TIME){
            if(FISTs[token].TIME==0){
               FISTs[token].TIME=block.timestamp;
             }
            FISTs[token].dayValue=getTokenPriceKUB(token,1 ether);
            FISTs[token].TIME+=600;
        }
    }
    function claim(address token,address token1) public    {
        require(usersAddr[msg.sender].tz > 0);
        require(listToken[token]);
        require(PairToken[token1]);
        require(block.timestamp > usersAddr[msg.sender].tim && usersAddr[msg.sender].tim >0);
        uint  sum=usersAddr[msg.sender].tz/100;
        uint miao=getTokenPriceKUB(token,sum);
        usersAddr[msg.sender].mnu=miao;
        uint ss=block.timestamp- usersAddr[msg.sender].tim;
        uint coin=miao/RATE_DAY*ss;
        if(ss > 0 && coin >0){   
        bool isok=IERC20(token).transfer(msg.sender,coin*50/100);
        require(isok);
          usersAddr[msg.sender].tim=block.timestamp;
          updateU(token,msg.sender,coin*50/100);
          _teamvalue(upaddress[msg.sender],msg.sender,coin*40/100);
          setSplitPrice(token,token1);
        }
    }
    function sell(address token,address token1,uint amount)public {
        require(token != address(0) && token1 != address(0));
        require(myReward[token] == token1);
        require(listToken[token]);
        require(PairToken[token1]);
        bool isok=IERC20(token).transferFrom(msg.sender, bunToken, amount);
        require(isok);
        uint coin=amount*50/100;
        uint _sellc=getTokenPriceS(token,coin);
        if(IERC20(token1).balanceOf(address(this)) < _sellc){
           removeLiquidity(token,token1);
        }
        require(IERC20(token1).balanceOf(address(this)) > _sellc && IERC20(token).balanceOf(address(this)) > coin);
        IERC20(token1).transfer(msg.sender,_sellc);
        IERC20(token).transfer(msg.sender,coin);
    }
    function removeLiquidity(address token,address token1)internal  {
        address pair=ISwapFactory(IRouters.factory()).getPair(token,token1);
        uint lp=IERC20(pair).balanceOf(address(this))*7/1000;
        IERC20(pair).approve(address(address(IRouters)), lp);
        IRouters.removeLiquidity(token,token1,lp,0,0,address(this),block.timestamp+100); 
    }
    function getToken(address token,uint amount)public onlyOwner{
        IERC20(token).transfer(msg.sender,amount);
    }
    function getpair(address token) view public  returns(address){
           return myReward[token];    
    }
    function getTokenPriceKUB(address _tolens,uint bnb) view public  returns(uint){
           address[] memory routePath = new address[](2);
           routePath[0] = KUB;
           routePath[1] = _tolens;
           return IRouters.getAmountsOut(bnb,routePath)[1];    
    }
    function getTokenPrice(address _tolens,uint bnb) view public  returns(uint){
           address[] memory routePath = new address[](2);
           routePath[0] = KUB;
           routePath[1] = _tolens;
           return IRouter(KUBDEX).getAmountsOut(bnb,routePath)[1];    
    }
    function getTokenPriceS(address _tolens,uint bnb) view public  returns(uint){
           address[] memory routePath = new address[](2);
           routePath[0] = _tolens;
           routePath[1] = KUB;
           return IRouters.getAmountsOut(bnb,routePath)[1];    
    }
    function getTokenPriceSellc(address _tolen,address _tolens) view public  returns(uint){
           uint kubPrice=getTokenPriceU(KUB,USDT,1 ether);
           address pair=ISwapFactory(IRouters.factory()).getPair(_tolen,_tolens);
           uint kubUSDT=IERC20(KUB).balanceOf(LPaddr) * kubPrice / 1 ether;
           uint fistlpToken=kubUSDT* 1 ether/IERC20(_tolen).balanceOf(pair);
           return fistlpToken;  
    }
    function getTokenPriceU(address token,address token1,uint bnb) view public   returns(uint){
           address[] memory path = new address[](2);
           path[0] = token;
           path[1] = token1;
           return IRouter(KUBDEX).getAmountsOut(bnb,path)[1];  
    }
    function getMiner(address token)public  view returns(uint,uint,uint){
        return (FISTs[token].dayValue,FISTs[token].TIME,FISTs[token].allPower);
    }
    function getUp(uint _rs,uint bnb)public  view returns(uint){
           if(_rs == 1){
               return bnb*10/100;
           }
            if(_rs == 2){
               return bnb*6/100;
           }
           if(_rs == 3){
               return bnb*4/100;
           }
    }
    function getAddrsa(address to)external view returns(address[] memory,uint[] memory){
        address[] memory addr=usersAddr[to].arrs;
        uint[] memory routePath1 = new uint[](addr.length);
        for(uint i=0;i<addr.length;i++){
            routePath1[i]=teams[addr[i]].A1;
        }
        return (addr,routePath1);
    }
    function infos(address token,address to) external view returns(uint M,uint B,uint coin,uint a,uint z,uint y){
       a=usersAddr[to].tim;
       M=usersAddr[to].mnu;
       
      if(block.timestamp > usersAddr[to].tim){
          uint  sum=usersAddr[to].tz/100;
        uint miao=getTokenPriceKUB(token,sum);
        uint ss=block.timestamp- usersAddr[to].tim;
        uint coins=miao/RATE_DAY*ss;
         B=0; 
        coin=coins/2;
      }
        z=usersAddr[to].yz;
        y=usersAddr[to].tz;
     }
}
