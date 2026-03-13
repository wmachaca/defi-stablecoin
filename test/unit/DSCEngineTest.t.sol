// SPDX-LICENCE-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {console2} from "forge-std/console2.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockMoreDebtDSC} from "../mocks/MockMoreDebtDSC.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {console2} from "forge-std/console2.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    address public LIQUIDATOR = makeAddr("liquidator");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether; // 10 ETH
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public amountToMint = 100 ether;

    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    function setUp() public {
        console2.log("Before Deploying contracts...");
        deployer = new DeployDSC();
        console2.log("Deploying contracts...");
        (dsc, engine, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, , ) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    ///////////////////////////////
    // Constructor Tests /////////
    ///////////////////////////////

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeedLength() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed); // Adding an extra price feed to create a mismatch

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
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

    function testgetTokenAmountFromUsd1() public {
        uint256 usdAmount = 30000e18; // This is $30,000 USD
        // 30000e18 * 1e18 / (2000e8 * 1e10) = 15e18 (15 ETH)
        uint256 expectedTokenAmount = 15e18; // This is 15 ETH

        // token = weth, amount = 30000e18 (30000 USD)
        // The getTokenAmountFromUsd function will take the amount of USD and divide it by the price of ETH in USD (2000) to get the amount of ETH.
        // price = 2000e8 (2000 with 8 decimals) ($2000 per ETH).
        uint256 actualTokenAmount = engine.getTokenAmountFromUsd(weth, usdAmount);

        assertEq(actualTokenAmount, expectedTokenAmount);
    }

    function testgetTokenAmountFromUsd2() public {
        uint256 usdAmount = 100 ether; // This is $100 USD
        // 100 * 1e18 / (2000e8 * 1e10) = 0.05e18 (15 ETH)
        uint256 expectedWeth = 0.05 ether; // This is 15 ETH

        // token = weth, amount = 30000e18 (30000 USD)
        // The getTokenAmountFromUsd function will take the amount of USD and divide it by the price of ETH in USD (2000) to get the amount of ETH.
        // price = 2000e8 (2000 with 8 decimals) ($2000 per ETH).
        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);

        assertEq(actualWeth, expectedWeth);
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

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        engine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL); // Trying to deposit an unapproved collateral (address(1))
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = engine.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0; // No DSC minted yet
        uint256 expectedDepositAmount = engine.getTokenAmountFromUsd(weth, totalCollateralValueInUsd); // This should be 10 ETH
        assertEq(totalDscMinted, expectedTotalDscMinted); // No DSC minted yet
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount); // deposit amount should be 10 ETH
    }
    ///////////////////////////////
    // redeemCollateral Tests ////
    ///////////////////////////////
    function testCanRedeemCollateral() public depositedCollateral {
        uint256 redeemAmount = 5 ether;

        uint256 startingUserBalance = ERC20Mock(weth).balanceOf(USER);

        vm.startPrank(USER);
        engine.redeemCollateral(weth, redeemAmount);
        vm.stopPrank();

        uint256 endingUserBalance = ERC20Mock(weth).balanceOf(USER);

        assertEq(endingUserBalance, startingUserBalance + redeemAmount);
    }

    function testRedeemRevertsIfZero() public depositedCollateral {
        vm.startPrank(USER);

        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        engine.redeemCollateral(weth, 0);

        vm.stopPrank();
    }

    function testRedeemRevertsIfHealthFactorBroken() public depositedCollateral {
        vm.startPrank(USER);
        // collateral 10 ether
        // debt: 10000 ether
        uint256 mintAmount = 10000 ether;
        engine.mintDsc(mintAmount);

        vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
        engine.redeemCollateral(weth, 1 ether);

        vm.stopPrank();
    }
    function testCanRedeemAllCollateral() public depositedCollateral {
        uint256 startingUserBalance = ERC20Mock(weth).balanceOf(USER);

        vm.startPrank(USER);
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        uint256 endingUserBalance = ERC20Mock(weth).balanceOf(USER);

        assertEq(endingUserBalance, startingUserBalance + AMOUNT_COLLATERAL);
    }

    ///////////////////////////////
    // mintDsc Tests ////
    ///////////////////////////////

    function testMintDscRevertsIfAmountIsZero() public {
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);

        vm.prank(USER);
        engine.mintDsc(0);
    }

    function testMintDscRevertsIfHealthFactorIsBroken() public depositedCollateral {
        vm.startPrank(USER);

        uint256 tooMuchDsc = 20000 ether;

        vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
        engine.mintDsc(tooMuchDsc);

        vm.stopPrank();
    }

    function testCanMintDsc() public depositedCollateral {
        // the collateral deposited is 10 ether -> 10 WETH
        // the value of the collateral is : ETH price = $2000
        // then 10 ETH *$2000 = $20 000 as collateral
        // max mintable DSC = $20000*50% = $10000 -> the user can mint $10 000 DSC!
        uint256 mintAmount = 1000 ether; // 1000 ether -> 1000 DSC

        vm.startPrank(USER);
        engine.mintDsc(mintAmount);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(USER);

        assertEq(userBalance, mintAmount);
    }

    ///////////////////////////////
    // burnDsc Tests ////
    ///////////////////////////////

    function testBurnDscRevertsIfAmountIsZero() public {
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);

        engine.burnDsc(0);
    }

    // 1. deposit collateral.
    // 2. mint DSC.
    // 3. approve DSC to engine._
    // 4. burn DSC.
    // 5. verify balances.
    function testCanBurnDsc() public depositedCollateral {
        uint256 mintAmount = 1000 ether;

        vm.startPrank(USER);

        // mint DSC
        engine.mintDsc(mintAmount);

        // approve engine to spend DSC. Without this, the transferFrom will revert.
        dsc.approve(address(engine), mintAmount);

        // burn DSC
        engine.burnDsc(mintAmount);

        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(USER);

        assertEq(userBalance, 0);
    }

    function testBurnDscReducesUserDebt() public depositedCollateral {
        uint256 mintAmount = 1000 ether;

        vm.startPrank(USER);

        engine.mintDsc(mintAmount);

        dsc.approve(address(engine), mintAmount);

        engine.burnDsc(mintAmount);

        vm.stopPrank();

        (uint256 totalDscMinted, ) = engine.getAccountInformation(USER);

        assertEq(totalDscMinted, 0);
    }

    function testBurnDscDecreasesTotalSupply() public depositedCollateral {
        uint256 mintAmount = 1000 ether;

        vm.startPrank(USER);

        engine.mintDsc(mintAmount);

        dsc.approve(address(engine), mintAmount);

        uint256 supplyBefore = dsc.totalSupply();

        engine.burnDsc(mintAmount);

        uint256 supplyAfter = dsc.totalSupply();

        vm.stopPrank();

        assertEq(supplyAfter, supplyBefore - mintAmount);
    }

    ///////////////////////////////
    // liquidate Tests ////
    ///////////////////////////////
    // This test needs it's own setup
    function testMustImproveHealthFactorOnLiquidation() public {
        // Arrange - Setup
        MockMoreDebtDSC mockDsc = new MockMoreDebtDSC(ethUsdPriceFeed); // owner of MockMoreDebtDSC is the test contract (address(this)).
        // Define collateral tokens and price feeds for the mock DSCEngine.
        tokenAddresses = [weth];
        priceFeedAddresses = [ethUsdPriceFeed];
        // Store the owner
        address owner = msg.sender;
        vm.prank(owner);
        DSCEngine mockDsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockDsc)); // Deploy the DSCEngine. Now the engine knows collateral tokens, price feeds, DSC token.
        mockDsc.transferOwnership(address(mockDsce)); // Transfer ownership of MockMoreDebtDSC to the mock DSCEngine so that it can call the burn function during liquidation.

        // Arrange - User: borrower
        // Collateral: 10 ETH, Debt: 100 DSC, Initial ETH price = $2000. This position is healthy with a HF > 1.
        // HF=20000*0.5/100 = 1000 > 1.
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(mockDsce), AMOUNT_COLLATERAL); // User allows the engine to pull WETH from their wallet.
        mockDsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, amountToMint); // User deposits collateral and mints DSC. Now the user has a position with 10 ETH collateral and 100 DSC debt.
        // Only to test:
        uint256 hfBefore = mockDsce.getHealthFactor(USER);
        console2.log("Health Factor before price crash:", hfBefore / 1e18);
        //
        vm.stopPrank();

        // Arrange - Liquidator
        // Collateral: 10 ETH, Debt: 100 DSC, ETH price = $18.
        // HF = 10*18*0.5/100 = 0.9 < 1. This position is undercollateralized and eligible for liquidation.
        collateralToCover = 1 ether;
        ERC20Mock(weth).mint(liquidator, collateralToCover); // Give the liquidator some WETH to use for liquidation.

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(mockDsce), collateralToCover); // Allows the engine to transfer WETH from the liquidator's wallet during liquidation.
        uint256 debtToCover = 10 ether; // The liquidator will try to cover 10 DSC of the user's debt.
        mockDsce.depositCollateralAndMintDsc(weth, collateralToCover, amountToMint); // The liquidator needs DSC tokens so the engine can burn them during liquidation
        mockDsc.approve(address(mockDsce), debtToCover);
        // Act
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18; This is a significant drop in the price of ETH, which will make the user's position undercollateralized and eligible for liquidation.
        //
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        // Only to test:
        uint256 hfAfterPriceDrop = mockDsce.getHealthFactor(USER);
        console2.log("HF after crash (human):", hfAfterPriceDrop, hfAfterPriceDrop / 1e18);
        //
        // Act/Assert
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorNotImproved.selector);
        // 1. HF < 1.
        // 2. Engine transfer collateral to the liquidator: USER WETH -> LIQUIDATOR WETH.
        // 3. Engine burns the liquidator's DSC.
        // 4. Inside the mock, the malicious trick happens: ETH price is updated to $0 before the burn happens, which makes the health factor even worse after liquidation instead of improving it. This causes the liquidation to revert with "HealthFactorNotImproved" error.
        mockDsce.liquidate(weth, USER, debtToCover); // Inside liquidation, calls MockMoreDebtDSC.burn().
        vm.stopPrank();
    }

    function testCantLiquidateGoodHealthFactor() public {
        // First deposit collateral and minted

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, amountToMint);
        vm.stopPrank();

        // liquidtor tries to liquidate but the health factor is still above 1, so it should revert with "HealthFactorOk" error.

        ERC20Mock(weth).mint(liquidator, collateralToCover); // Give the liquidator some WETH   to use for liquidation.

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(engine), collateralToCover);
        engine.depositCollateralAndMintDsc(weth, collateralToCover, amountToMint);
        dsc.approve(address(engine), amountToMint);

        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        engine.liquidate(weth, USER, amountToMint);
        vm.stopPrank();
    }

    modifier liquidated() {
        // USER:
        // Collateral: 10 ETH, Debt: 100 DSC, Initial ETH price = $2000. This position is healthy with a HF > 1.
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, amountToMint);
        vm.stopPrank();
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        uint256 userHealthFactor = engine.getHealthFactor(USER);
        console2.log("HF after crash (human):", userHealthFactor, userHealthFactor / 1e18);

        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(engine), collateralToCover);
        engine.depositCollateralAndMintDsc(weth, collateralToCover, amountToMint); // The collateralToCover is no longer in the liquidator wallet.
        // It was transfered to the engine contract.
        dsc.approve(address(engine), amountToMint);
        engine.liquidate(weth, USER, amountToMint); // We are covering their whole debt
        vm.stopPrank();
        _;
    }

    function testLiquidationPayoutIsCorrect() public liquidated {
        uint256 liquidatorWethBalance = ERC20Mock(weth).balanceOf(liquidator);
        // getTokenAmountFromUsd = usdAmount / price.
        // So 100 /18 = 5.5555 ETH
        // Liquidator receives 10% bonus: 5.5555 * 10% = 0.5555 ETH
        // Total: 5.5555 + 0.5555 = 6.1111 ETH
        uint256 expectedWeth = engine.getTokenAmountFromUsd(weth, amountToMint) +
            ((engine.getTokenAmountFromUsd(weth, amountToMint) * engine.getLiquidationBonus()) /
                engine.getLiquidationPrecision());
        uint256 hardCodedExpected = 6_111_111_111_111_111_110;
        assertEq(liquidatorWethBalance, hardCodedExpected);
        assertEq(liquidatorWethBalance, expectedWeth);
    }

    function testUserStillHasSomeEthAfterLiquidation() public liquidated {
        // Get how much WETH the user lost
        uint256 amountLiquidated = engine.getTokenAmountFromUsd(weth, amountToMint) +
            ((engine.getTokenAmountFromUsd(weth, amountToMint) * engine.getLiquidationBonus()) /
                engine.getLiquidationPrecision());

        uint256 usdAmountLiquidated = engine.getUsdValue(weth, amountLiquidated);
        //10 ETH - 6.1111 ETH = 3.8889 ETH-> 3.8889 ETH * $18 = $70.0002 USD
        uint256 expectedUserCollateralValueInUsd = engine.getUsdValue(weth, AMOUNT_COLLATERAL) - (usdAmountLiquidated);

        (, uint256 userCollateralValueInUsd) = engine.getAccountInformation(USER);
        uint256 hardCodedExpectedValue = 70_000_000_000_000_000_020;
        assertEq(userCollateralValueInUsd, expectedUserCollateralValueInUsd);
        assertEq(userCollateralValueInUsd, hardCodedExpectedValue);
    }

    function testLiquidatorTakesOnUsersDebt() public liquidated {
        // Important
        // Liquidator mint DSC to transfer to the engine contract to burn the user's debt.
        // This reduces the USER's debt and increases the liquidator's debt.
        // So after liquidation, sDscMinted for the USER should be 0 and sDscMinted for the liquidator should be equal to the amount of DSC that was covered by the liquidation (amountToMint in this case).
        (uint256 liquidatorDscMinted, ) = engine.getAccountInformation(liquidator);
        assertEq(liquidatorDscMinted, amountToMint);
    }

    function testUserHasNoMoreDebt() public liquidated {
        (uint256 userDscMinted, ) = engine.getAccountInformation(USER);
        assertEq(userDscMinted, 0);
    }
}
