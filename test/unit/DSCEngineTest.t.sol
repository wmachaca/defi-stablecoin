// SPDX-LICENCE-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {console2} from "forge-std/console2.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address ethUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether; // 10 ETH
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        console2.log("Before Deploying contracts...");
        deployer = new DeployDSC();
        console2.log("Deploying contracts...");
        (dsc, engine, config) = deployer.run();
        (ethUsdPriceFeed, , weth, , ) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    ///////////////////////////////
    // Price Tests /////////
    ///////////////////////////////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18; // This is 15 ETH (15 * 10^18 in base units)
        // 15e18 * 2000/ ETH = 30000 e18;
        uint256 expectedUsdValue = 30000e18; // This is $30,000 USD

        // token = weth, amount = 15e18 (15 ETH)
        // The getUsdValue function will take the amount of ETH and multiply it by the price of ETH in USD (2000) to get the USD value.
        // price = 2000e8 (2000 with 8 decimals) ($2000 per ETH).
        // (2000e8 * 1e10 * 15e18) /1e18 = 30000e18 (30000 USD with 18 decimals)
        uint256 actualUsdValue = engine.getUsdValue(weth, ethAmount);

        assertEq(actualUsdValue, expectedUsdValue);
    }

    ///////////////////////////////
    // depositCollateral Tests ////
    ///////////////////////////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }
}
