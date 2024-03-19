// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./Pool.sol";
import "./Factory.sol";
import "./oracle/PoolOracle.sol";


contract Token is ERC20 {
    address private owner;
    address private pool;
    bool  flag = true;
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        owner = msg.sender;
    }


    function mint(address to, uint256 amount) public onlyOwner{
        _mint(to, amount);
    }

   function burn(address to, uint256 amount) public onlyOwner{
        _burn(to, amount);
    }
}

contract Setup  {
    
    Factory public factory;
    Pool public pool;
    Pool public pool2;
    bool public flag =  true;
    bool  public success = false;
    Token public token0 ;
    Token public token1 ;
     function addManager(address manager) external {
            factory.addNFTManager(manager);
     }

    function airdroop() public {
        if(flag){
            flag = false;
            token1.mint(msg.sender,0.3 ether);
        }
    }


     constructor() public {
        token0 = new Token("token0", "TKN1");
        token1 = new Token("token1", "TKN2");

        PoolOracle oracle = new PoolOracle();
        oracle.initialize();
        factory = new Factory(0, address(oracle));
        factory.addNFTManager(address(this));
        pool = Pool(factory.createPool(address(token0), address(token1), 10));
        pool2 = Pool(factory.createPool(address(token0), address(token1), 8));
        token0 = Token(address(pool.token0()));
        token1 = Token(address(pool.token1()));

        token0.mint(address(pool), 10000 ether);
        token1.mint(address(pool), 10000 ether);
        token0.mint(address(pool2), 101 ether);
        token1.mint(address(pool2), 0.5 ether);

        pool.unlockPool(1 * 2 ** 96);
    }

    function check() public {
        if (token0.balanceOf(msg.sender) > 9999 && token1.balanceOf(address(pool2)) == 0.5 ether && token0.balanceOf(address(pool2)) == 101 ether){
            success = true;
        }
    }

    function isSolved() public returns (bool) {
        return success == true;
    }

}

