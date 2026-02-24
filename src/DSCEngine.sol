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

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
contract DSCEngine is ReentrancyGuard { // ReentrancyGuard is a contract from OpenZeppelin that helps prevent reentrancy attacks by adding a modifier to functions that should not be called recursively. It is more gas consuming than a regular function.
    ////////////
    // Errors //
    ////////////
    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine_NotAllowedToken();
    error DSCEngine__TransferFailed();


    /////////////////////
    // State Variables //
    /////////////////////
    mapping(address token => address priceFeed) private s_priceFeeds; // mapping of token address to its price feed address. (WETH -> ETH/USD, WBTC -> BTC/USD)
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited; // mapping of user address to token address to amount of collateral deposited. (user -> WETH -> 1 WETH)

    DecentralizedStableCoin private immutable i_dsc; // the DSC token contract


    ////////////
    // Events //
    ////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);



    ///////////////
    // Modifiers //
    ///////////////

    modifier moreThanZero(uint256 amount) {
        if(amount == 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
        _;// function runs after the modifier
    }

    modifier isAllowedToken(address token) {
        // check if the token is allowed (WETH or WBTC)
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine_NotAllowedToken();
        }
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
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }


    ////////////////////////
    // External Functions //
    ////////////////////////

    function depositCollateralAndMintDsc()  external {}


    /**
     * @notice follows CEI pattern. First, the user deposits collateral, then they can mint DSC in the same transaction. This is more efficient than having two separate transactions for depositing collateral and minting DSC.
     * @param tokenCollateralAddress The address of the token to deposit as collateral. (WETH or WBTC) 
     * @param amountCollateral The amount of the token to deposit as collateral.
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral) external moreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress) nonReentrant {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if(!success) {
            revert DSCEngine__TransferFailed();
        }
    }
    
    
    function redeemCollateralForDsc() external {}
    function redeemCollateral() external {}
    function mintDsc() external {}
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
}