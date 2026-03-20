// SPDX-License-Identifier: MIT

// Have our invariant aka properties.

//What are our invariants?

//1. The total supply of DSC should never exceed the total value of collateral in the system.

// 2. Getter view functions should never revert <- evergreen invariant.

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract Invariants is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    address weth;
    address wbtc;
    Handler handler;

    function setUp() public {
        //console2.log("Before deployer: ");
        deployer = new DeployDSC();
        //console2.log("After deployer: ");
        (dsc, engine, config) = deployer.run();
        //console2.log("After deployer run: ", address(dsc), address(engine));
        (, , weth, wbtc, ) = config.activeNetworkConfig();
        //console2.log("After config setup: ", weth, wbtc);

        //targetContract(address(engine));
        handler = new Handler(engine, dsc);
        targetContract(address(handler));
        // Don't call redeemCollateral, unless there is collateral to redeem.
    }
    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // Get the value of all the collateral in the protocol.
        // Compare it to all the debt (dsc).
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(engine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(engine));

        uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = engine.getUsdValue(wbtc, totalWbtcDeposited);
        uint256 totalCollateralValue = wethValue + wbtcValue;

        console2.log("Total Supply: ", totalSupply);
        console2.log("Total Collateral Value: ", totalCollateralValue);
        console2.log("Times mint is called: ", handler.timesMintIsCalled());
        // If you use < sometimes, you might run into issues with rounding errors. So we use <= to be safe.
        // This is the error: [FAIL: failed to set up invariant testing environment: panic: assertion failed (0x01)]
        assert(totalSupply <= totalCollateralValue);
    }

    function invariant_gettersShouldNotRevert() public view {
        // Call all getter functions to ensure they do not revert
        engine.getPrecision();
        engine.getCollateralTokens();
        // Add more getter functions as needed
    }
    // function invariant_totalSupplyShouldNotExceedTotalCollateralValue() public view {
    //     uint256 totalSupply = dsc.totalSupply();
    //     uint256 totalCollateralValue = dsc.getTotalCollateralValue();
    //     assert(totalSupply <= totalCollateralValue);
    // }

    // function invariant_getterFunctionsShouldNotRevert() public view {
    //     // Call all getter functions to ensure they do not revert
    //     dsc.totalSupply();
    //     dsc.getTotalCollateralValue();
    //     dsc.getCollateralizationRatio();
    //     // Add more getter functions as needed
    // }
}
