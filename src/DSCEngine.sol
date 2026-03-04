// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.20;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSCEngine
 * @author WIMA
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token ==  $1 peg.
 * This stablecoin has the properties:
 * - Exogenous Collateral (ETH & BTC)
 * - Pegged to USD
 * - Algorithmic Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was only backed by WETH and WBTC.
 *
 * Our DSC system should allways be "overcollateralized". At no point,
 * should the value of all collateral <= the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the DSC System. It handles all the logic for mining and redeeming DSC,
 * as well as depositing  & withdrawing collateral.
 * @notice This contract is VERY loosely based on the MakerDAO DSS (DAI) system.
 */
contract DSCEngine is
    ReentrancyGuard // ReentrancyGuard is a contract from OpenZeppelin that helps prevent reentrancy attacks by adding a modifier to functions that should not be called recursively. It is more gas consuming than a regular function.
{
    ////////////
    // Errors //
    ////////////
    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine_NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor();
    error DSCEngine__InvalidPrice();
    error DSCEngine__MintFailed();

    /////////////////////
    // State Variables //
    /////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18; // 18 decimals of precision for all calculations
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // means we need to be 200% overcollateralized ????
    uint256 private constant LIQUIDATION_PRECISION = 100; // to take into account the percentage for liquidation_threshold. (50% = 50/100).
    uint256 private constant MIN_HEALTH_FACTOR = 1 * 1e18; // 1 * 1e18 = 1.0. If health factor < 1, then the position can be liquidated.

    mapping(address token => address priceFeed) private sPriceFeeds; // mapping of token address to its price feed address. (WETH -> ETH/USD, WBTC -> BTC/USD)
    mapping(address user => mapping(address token => uint256 amount)) private sCollateralDeposited; // mapping of user address to token address to amount of collateral deposited. (user -> WETH -> 1 WETH)
    mapping(address user => uint amountDscMinted) private sDscMinted; // mapping of user address to amount of DSC minted. (user -> 100 DSC)
    address[] private sCollateralTokens; // array of collateral tokens (WETH, WBTC)

    DecentralizedStableCoin private immutable DSC; // the DSC token contract

    ////////////
    // Events //
    ////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);

    ///////////////
    // Modifiers //
    ///////////////

    modifier moreThanZero(uint256 amount) {
        _moreThanZero(amount);
        _; // function runs after the modifier
    }

    modifier isAllowedToken(address token) {
        _isAllowedToken(token);
        _;
    }

    ///////////////
    // Functions //
    ///////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        // For example ETH/USD, BTC/USD, MKR/USD, etc.
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            sPriceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            sCollateralTokens.push(tokenAddresses[i]);
        }
        DSC = DecentralizedStableCoin(dscAddress);
    }

    ////////////////////////
    // External Functions //
    ////////////////////////

    function depositCollateralAndMintDsc() external {}

    /**
     * @notice follows CEI pattern. First, the user deposits collateral, then they can mint DSC in the same transaction. This is more efficient than having two separate transactions for depositing collateral and minting DSC.
     * @param tokenCollateralAddress The address of the token to deposit as collateral. (WETH or WBTC)
     * @param amountCollateral The amount of the token to deposit as collateral.
     */
    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) external moreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress) nonReentrant {
        sCollateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDsc() external {}
    function redeemCollateral() external {}

    // 1. Check if the collateral value > DSC amount.
    /**
     * @notice follows CEI pattern.
     * @notice they must have more collateral value than the minimum threshold.
     * @param amountDscToMint The amount of DSC to mint.
     */
    function mintDsc(uint256 amountDscToMint) external moreThanZero(amountDscToMint) nonReentrant {
        sDscMinted[msg.sender] += amountDscToMint;
        // Check if the collateral value > DSC amount.
        // If not, revert the transaction.
        // If yes, mint the DSC to the user.

        // If the user doesn't have enough collateral, the health factor will be < 1 and the transaction will revert.
        _revertIfHealthFactorIsBroken(msg.sender);

        bool minted = DSC.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }
    function burnDsc() external {}

    // Threshold to let's say 150%. That means if the value of the collateral falls below 150% of
    // the value of the DSC ($75 ETH), then anyone can call the liquidate function to liquidate the position.
    // $ 100 ETH -> $ 40 ETH. (Undercollateralized). User needs to add more collateral to their position or they will be liquidated.
    // $50 DSC. User needs to pay back $50 DSC + fees to get their collateral back.

    // If someone pays back your minted DSC, they can have all your collateral for a discount.

    // Threshold to let's say 150%.
    // $100 ETH Collateral -> $74 ETH. (decrease its value).
    // $ 50 DSC.
    // UNDERCOLLARALIZED!!!.

    // I'll pay back the $50 DSC -> get all your collateral!.
    // $74 ETH.
    // -$50 DSC.
    // $ 24 ETH. (earn the liquidator).
    function liquidate() external {}
    function getHealthFactor() external view returns (uint256) {}

    ///////////////////////////////////////
    // Private & Internal View Functions //
    ///////////////////////////////////////

    function _getAccountInformation(
        address user
    ) private view returns (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) {
        // 1. Get the total value of the collateral deposited by the user.
        // 2. Get the total value of the DSC minted by the user.
        // 3. Return the total collateral value and total DSC minted.

        totalDscMinted = sDscMinted[user];
        totalCollateralValueInUsd = getAccountCollateralValue(user);
    }
    /**
     * Returns how close to liquidation a user is.
     * If a user goes below 1, then they can get liquidated.
     */
    function _healthFactor(address user) private view returns (uint256) {
        // 1. Get the total value of the collateral deposited by the user.
        // 2. Get the total value of the DSC minted by the user.
        // 3. Calculate the health factor (collateral value / DSC value).
        // 4. Return the health factor.

        (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = _getAccountInformation(user);
        // 1000 ETH * 50 / 1000 = 500.
        uint256 collateralAdjustedForThreshold = (totalCollateralValueInUsd * LIQUIDATION_THRESHOLD) /
            LIQUIDATION_PRECISION;

        // $150 ETH / 100 DSC = 1.5
        // 150*50 = 7500 / 100 = 75. (75/100 = 0.75) < 1.

        // $1000 ETH / 100 DSC = 10.
        // 1000 * 50 = 50000 / 100 = 500. (500/100 = 5) > 1.
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted; // multiplied by PRECISION to get the correct precision for the health factor. (0.75 * 1e18 = 0.75e18, 5 * 1e18 = 5e18).
    }
    function _revertIfHealthFactorIsBroken(address user) internal view {
        // 1. Check health factor (do they have enough collateral?).
        // 2. Revert if they don't.

        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor();
        }
    }

    //////////////////////////////////////
    // Public & External View Functions //
    //////////////////////////////////////
    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // 1. Loop through the collateral deposited by the user.
        // 2. Get the price of each collateral token in USD using the price feed.
        // 3. Calculate the total value of the collateral in USD.
        // 4. Return the total collateral value in USD.

        totalCollateralValueInUsd = 0;
        for (uint256 i = 0; i < sCollateralTokens.length; i++) {
            address token = sCollateralTokens[i];
            uint256 amount = sCollateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        // 1. Call the price feed contract to get the latest price.
        // 2. Return the price.
        AggregatorV3Interface priceFeed = AggregatorV3Interface(sPriceFeeds[token]);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        if (price <= 0) {
            revert DSCEngine__InvalidPrice();
        }
        // 1ETH = $1000
        // The returned value from CL will be 1000*1e8 (because CL price feeds have 8 decimals).
        // We need price*amount
        // recall to see data feeds in chain link for presicion of the price of ETH / USD or others.
        // In this case ETH has 8 decimals from chainlink and we need 18 decimals for our calculations, so we need to multiply the price by 1e10 to get the correct precision.
        // forge-lint: disable-next-line(unsafe-typecast) // safe: price checked > 0
        return (uint256(price) * ADDITIONAL_FEED_PRECISION * amount) / PRECISION; // (1000*1e8*1e10) *1000 * 1e18
    }

    function _moreThanZero(uint256 amount) internal pure {
        if (amount == 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
    }

    function _isAllowedToken(address token) internal view {
        // check if the token is allowed (WETH or WBTC)
        if (sPriceFeeds[token] == address(0)) {
            revert DSCEngine_NotAllowedToken();
        }
    }
}
