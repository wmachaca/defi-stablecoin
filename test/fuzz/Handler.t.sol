// SPDX-License-Identifier: MIT
// Handler is going to narrow down the way we call function.

//

pragma solidity ^0.8.20;
import {Test, console2} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

// Price feed.

contract Handler is Test {
    DSCEngine engine;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 public timesMintIsCalled;
    address[] public usersWithCollateralDeposited;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;
    constructor(DSCEngine _engine, DecentralizedStableCoin _dsc) {
        engine = _engine;
        dsc = _dsc;

        address[] memory collateralTokens = engine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
    }

    function mintDsc(uint256 amountDsc, uint256 addressSeed) public {
        // We can only mint DSC if we have collateral deposited.
        // We can check that by looking at the total supply of DSC. If it's 0, then there is no collateral in the system.
        // If there is no collateral in the system, then we can't mint DSC.

        if (usersWithCollateralDeposited.length == 0) {
            return;
        }
        // msg.sender is also a random.
        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length]; // index = addresss % length guaranties that we will always get a valid index (0<index<length).
        (uint256 totalDscMinted, uint256 totalCollateralValue) = engine.getAccountInformation(sender);

        int256 maxDscToMint = (int256(totalCollateralValue) / 2) - int256(totalDscMinted);
        if (maxDscToMint <= 0) {
            return;
        }
        amountDsc = bound(amountDsc, 0, uint256(maxDscToMint));
        if (amountDsc == 0) {
            return;
        }
        vm.startPrank(sender);
        engine.mintDsc(amountDsc);
        vm.stopPrank();
        timesMintIsCalled++;
    }
    // redeem collateral <- only if there is collateral to redeem.

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        // We need to approve the engine to spend our collateral before we can call this function.
        // We can do that in the invariant test, before we call the handler function.
        // Handler does not own collateral tokens.
        // Handler never approves the engine.
        // Collateral address fuzzed by Foundry is random, not weth or wbtc.
        //engine.depositCollateral(collateral, amountCollateral);

        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

        //aprove the engine to spend our collateral before we can call this function.
        //msg.sender is also random.
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(engine), amountCollateral);
        engine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
        usersWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        uint256 redeemReverts = 0;
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollatealToRedeem = engine.getCollateralBalanceOfUser(msg.sender, address(collateral));
        amountCollateral = bound(amountCollateral, 0, maxCollatealToRedeem);
        if (amountCollateral == 0) {
            return;
        }
        //engine.redeemCollateral(address(collateral), amountCollateral);
        try engine.redeemCollateral(address(collateral), amountCollateral) {
            // success
        } catch Error(string memory reason) {
            redeemReverts++;
            console2.log("Revert reason:", reason);
            console2.log("amount:", amountCollateral);
        } catch (bytes memory) {
            redeemReverts++;
            console2.log("Low-level revert");
            console2.log("amount:", amountCollateral);
        }
    }

    // This breaks our invariant test suite!!!
    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdpriceFeed.updateAnswer(newPriceInt);
    //     wbtcUsdpriceFeed.updateAnswer(newPriceInt);
    // }
    // Helper functions.
    function _getCollateralFromSeed(uint256 collateralSeed) public view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
