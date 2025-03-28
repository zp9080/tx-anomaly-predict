pragma solidity =0.8.24;
import { IDoughIndex, CustomError } from "./Interfaces.sol";

/**
* $$$$$$$\                                $$\             $$$$$$$$\ $$\                                                   
* $$  __$$\                               $$ |            $$  _____|\__|                                                  
* $$ |  $$ | $$$$$$\  $$\   $$\  $$$$$$\  $$$$$$$\        $$ |      $$\ $$$$$$$\   $$$$$$\  $$$$$$$\   $$$$$$$\  $$$$$$\  
* $$ |  $$ |$$  __$$\ $$ |  $$ |$$  __$$\ $$  __$$\       $$$$$\    $$ |$$  __$$\  \____$$\ $$  __$$\ $$  _____|$$  __$$\ 
* $$ |  $$ |$$ /  $$ |$$ |  $$ |$$ /  $$ |$$ |  $$ |      $$  __|   $$ |$$ |  $$ | $$$$$$$ |$$ |  $$ |$$ /      $$$$$$$$ |
* $$ |  $$ |$$ |  $$ |$$ |  $$ |$$ |  $$ |$$ |  $$ |      $$ |      $$ |$$ |  $$ |$$  __$$ |$$ |  $$ |$$ |      $$   ____|
* $$$$$$$  |\$$$$$$  |\$$$$$$  |\$$$$$$$ |$$ |  $$ |      $$ |      $$ |$$ |  $$ |\$$$$$$$ |$$ |  $$ |\$$$$$$$\ \$$$$$$$\ 
* \_______/  \______/  \______/  \____$$ |\__|  \__|      \__|      \__|\__|  \__| \_______|\__|  \__| \_______| \_______|
*                               $$\   $$ |                                                                                
*                               \$$$$$$  |                                                                                
*                                \______/                                                                                 
* 
* @title DoughDsa
* @notice This contract is used to delegate the call to the respective connectors
* @custom:version 1.0 - Initial release
* @author Liberalite https://github.com/liberalite
* @custom:coauthor 0xboga https://github.com/0xboga
*/
contract DoughDsa {
    /* ========== LAYOUT ========== */
    address public dsaOwner;
    address public doughIndex;

    /**
    * @notice Initializes the DoughDsa contract
    * @param _dsaOwner: The DSA owner address of the DSA contract
    * @param _doughIndex: The DoughIndex contract address
    */
    function initialize(address _dsaOwner, address _doughIndex) external {
        if (dsaOwner != address(0) || _dsaOwner == address(0)) revert CustomError("invalid dsaOwner");
        if (doughIndex != address(0) || _doughIndex == address(0)) revert CustomError("invalid doughIndex");
        doughIndex = _doughIndex;
        dsaOwner = _dsaOwner;
    }

    /**
    * @notice Delegates the call to the respective connector
    * @param _connectorId: The connector ID to call
    * @param _actionId: The action ID to call
    * @param _token: The token address to call
    * @param _amount: The amount to call
    * @param _opt: The optional boolean value
    * @param _swapData: The swap data to call
    */
    function doughCall(uint256 _connectorId, uint256 _actionId, address _token, uint256 _amount, bool _opt, bytes[] calldata _swapData) external payable {
        // _connectorId:  0-dsa  1-aave  2-paraswap  3-uniV3  4-deleveraging-uniV3  4-deleveraging-paraswap  5-shield  6-vault
        address _contract = IDoughIndex(doughIndex).getDoughConnector(_connectorId);
        if (_contract == address(0)) revert CustomError("Unregistered Connector");

        if (_connectorId < 21) {
            // only the DSA Owner can run supply, withdraw, repay, swap, loop, deloop, etc
            if (msg.sender != dsaOwner) revert CustomError("Caller not dsaOwner");
        } else if (_connectorId == 21 || _connectorId == 22) {
            if (msg.sender != IDoughIndex(doughIndex).deleverageAutomation()) revert CustomError("Only Deleveraging Automation");
        } else if (_connectorId == 23) {
            if (msg.sender != IDoughIndex(doughIndex).shieldAutomation()) revert CustomError("Only Shield Automation");
        } else if (_connectorId == 24) {
            if (msg.sender != IDoughIndex(doughIndex).vaultAutomation()) revert CustomError("Only Vault Automation");
        } else {
            // future connectors will only be available to the DSA Owner
            if (msg.sender != dsaOwner) revert CustomError("Caller not dsaOwner");
        }

        (bool success, bytes memory data) = _contract.delegatecall(abi.encodeWithSignature("delegateDoughCall(uint256,address,uint256,bool,bytes[])", _actionId, _token, _amount, _opt, _swapData));
        if (!success) {
            if (data.length == 0) revert CustomError("Invalid doughcall error length");
            if (data.length > 0) {
                assembly {
                    revert(add(32, data), mload(data))
                }
            }
        }

    }

    /**
    * @notice Executes an action from and to the Flashloan Connector
    * @param _connectorId: The connector ID
    * @param _tokenIn: The token address to get in
    * @param _inAmount: The amount to get in
    * @param _tokenOut: The token address to get out
    * @param _outAmount: The amount to get out
    * @param _actionId: The action ID to call
    */
    function executeAction(uint256 _connectorId, address _tokenIn, uint256 _inAmount, address _tokenOut, uint256 _outAmount, uint256 _actionId) external payable {
        address _connector = IDoughIndex(doughIndex).getDoughConnector(_connectorId);
        if(msg.sender != address(this) && msg.sender != _connector) revert CustomError("Caller not owner or DSA");

        address aaveActions = IDoughIndex(doughIndex).aaveActionsAddress();

        (bool success, bytes memory data) = aaveActions.delegatecall(abi.encodeWithSignature("executeAaveAction(uint256,address,uint256,address,uint256,uint256)", _connectorId, _tokenIn, _inAmount, _tokenOut, _outAmount, _actionId));
        if (!success) {
            if (data.length == 0) revert CustomError("Invalid Aave error length");
            if (data.length > 0) {
                assembly {
                    revert(add(32, data), mload(data))
                }
            }
        }

    }

    /**
    * @notice allows DSA Owner to deposit and withdraw ETH
    */
    receive() external payable {}
    fallback() external payable {}
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
pragma solidity ^0.8.10;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error CustomError(string errorMsg);

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint amount) external;
}

interface AaveActionsConnector {
    function executeAaveAction(address _dsaAddress, uint256 _connectorId, address _tokenIn, uint256 _inAmount, address _tokenOut, uint256 _outAmount, uint256 _actionId) external payable;
}

interface IDoughDsa {
    function doughCall(uint256 _connectorId, uint256 _actionId, address _token, uint256 _amount, bool _opt, bytes[] calldata _swapData) external payable;
    function executeAction(uint256 _connectorId, address tokenIn, uint256 inAmount, address tokenOut, uint256 outAmount, uint256 actionId) external payable;
    function dsaOwner() external view returns (address);
    function doughIndex() external view returns (address);
}

interface IDoughIndex {
    function aaveActionsAddress() external view returns (address);
    function setDsaMasterClone(address _dsaMasterCopy) external;
    function setNewBorrowFormula(address _newBorrowFormula) external;
    function setNewAaveActions(address _newAaveActions) external;
    function apyFee() external view returns (uint256);
    function getFlashBorrowers(address _flashBorrower) external view returns (bool);
    function deleverageAutomation() external view returns (address);
    function shieldAutomation() external view returns (address);
    function vaultAutomation() external view returns (address);
    function getWhitelistedTokenList() external view returns (address[] memory);
    function multisig() external view returns (address);
    function treasury() external view returns (address);
    function deleverageAsset() external view returns (address);
    function getDoughConnector (uint256 _connectorId) external view returns (address);
    function getOwnerOfDoughDsa(address dsaAddress) external view returns (address);
    function getDoughDsa(address dsaAddress) external view returns (address);
    function getTokenDecimals(address _token) external view returns (uint8);
    function getTokenMinInterest(address _token) external view returns (uint256);
    function getTokenIndex(address _token) external view returns (uint256);
    function borrowFormula (address _token, address _dsaAddress) external returns (uint256, uint256, uint256, uint256);
    function borrowFormulaInterest (address _token, address _dsaAddress) external returns (uint256);
    function getDsaBorrowStartDate (address _dsaAddress, address _token) external view returns (uint256);
    function updateBorrowDate(uint256 _connectorID, uint256 _time, address _dsaAddress, address _token) external;
    function minDeleveragingRatio() external view returns (uint256);
    function minHealthFactor() external view returns (uint256);
}

interface IBorrowManagementConnector {
    function borrowFormula(address _token, address _dsaAddress) external view returns (uint256, uint256, uint256, uint256);
    function borrowFormulaInterest(address _token, address _dsaAddress) external view returns (uint256);
}

interface IConnectorMultiFlashloan {
    function flashloanReq(address[] memory flashloanTokens, uint256[] memory flashloanAmounts, uint256[] memory flashLoanInterestRateModes, bytes[] memory swapData) external;
}

interface IConnectorMultiFlashloanOnchain {
    function flashloanReq(address[] memory flashloanTokens, uint256[] memory flashloanAmount, uint256[] memory flashLoanInterestRateModes, address[] memory flashLoanTokensCollateral, uint256[] memory flashLoanAmountsCollateral) external;
}

interface IConnectorFlashloan {
    function flashloanReq(address dsaOwnerAddress, address flashloanToken, uint256 flashloanAmount, uint256 flashActionId, bytes calldata _swapData) external;
}
