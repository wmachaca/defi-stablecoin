<div align="center">

# 💰 Decentralized Stablecoin (DSC)

### Battle-Tested DeFi Protocol - Overcollateralized, Algorithmic, Transparent

**Built with Foundry & Solidity by WIMA**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-Latest-black)](https://github.com/foundry-rs/foundry)
[![chainlink](https://img.shields.io/badge/Chainlink-Price%20Feeds-375BD2)](https://chain.link/)

[Documentation](#key-features) • [Architecture](#architecture-overview) • [Quick Start](#-quick-start) • [Contributing](#-contributing)

</div>

---

## 🎯 What is DSC?

**Decentralized Stablecoin (DSC)** is a **battle-tested, exogenously collateralized stablecoin** protocol that maintains a 1:1 peg to USD through algorithmic stability mechanisms and overcollateralization requirements. Built on Solidity with Foundry, DSC prioritizes **trustless, immutable design** over governance complexity.

Think of it as **"What if DAI had no governance overhead, no fees, and only used WETH + WBTC as collateral"**.

### Why DSC?

- 🔒 **Overcollateralized**: System is always 200%+ collateralized (health factor ≥ 1.0)
- ⛓️ **Exogenous Collateral**: Backed by real crypto assets (wETH, wBTC) with Chainlink price feeds
- 📊 **Algorithmic Minting**: Users can only mint DSC if they maintain sufficient collateral ratios
- 🔄 **Liquidation System**: Market participants can liquidate unhealthy positions and earn bonuses
- 🧪 **Rigorously Tested**: Invariant testing, fuzz testing, and unit tests
- 🔓 **Fully Decentralized**: No governance tokens, no fees, trustless settlement

---

## ✨ Key Features

### 💳 Core Stability Mechanism

- **Price Feed Integration**: Real-time USD pricing via Chainlink oracles for ETH and BTC
- **Collateral Management**: Deposit wETH or wBTC as collateral, mint DSC algorithmically
- **Health Factor Tracking**: System tracks account health (required ≥ 1.0 to stay solvent)
- **Adaptive Liquidation**: When health factor drops below 1.0, any user can liquidate and earn 10% bonus
- **Overcollateralization Guarantee**: Protocol ensures total collateral value always > total DSC minted

### 🏦 Advanced Financial Features

- **Collateral Deposit & Withdrawal**: Full custody with no wrapping required
- **DSC Minting & Burning**: Mint backed by collateral, burn to reclaim collateral
- **One-Step Operations**: `depositCollateralAndMintDsc()` for convenience
- **Liquidation Auctions**: Market-driven liquidations with incentive mechanisms
- **Reentrancy Protection**: ReentrancyGuard on all critical functions
- **View Functions**: Comprehensive getters for health factors, collateral values, and account data

### 🔍 Security & Testing

- **Invariant Testing**: Fuzz-tested system invariants (overcollateralization, mint bounds)
- **Unit Test Coverage**: 50+ unit tests covering edge cases, reverts, and state changes

### 📊 Protocol Guarantees (Invariants)

These properties **must always hold** or the system has failed:

1. **`Protocol must always be overcollateralized`**: `totalDscMinted ≤ (totalCollateralValueInUsd / 2)`
2. **`Users cannot mint more than max DSC`**: Constrained by collateral \* 50% (LIQUIDATION_THRESHOLD)
3. **`All debt is accounted for`**: `sumOfUserDebts = totalDscMinted`
4. **`Price feed updates only increase precision`**: No corrupted price data

---

## 🏗️ Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│            Decentralized Stablecoin (DSC) System             │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌────────────────────────────────────────────────────────┐  │
│  │      Price Oracle Layer (Chainlink V3)                │  │
│  │                                                         │  │
│  │  • ETH/USD Feed → Real-time Ethereum pricing          │  │
│  │  • BTC/USD Feed → Real-time Bitcoin pricing           │  │
│  │  • 10 decimals of precision → 1e18 normalized         │  │
│  └────────────────┬─────────────────────────────────────┘  │
│                   │                                           │
│  ┌────────────────┴─────────────────────────────────────┐  │
│  │      Smart Contract Layer (Foundry/Solidity)         │  │
│  │                                                        │  │
│  │  DecentralizedStableCoin.sol                          │  │
│  │  ├─ ERC20 token minting/burning                      │  │
│  │  ├─ Only DSCEngine can mint/burn                     │  │
│  │  └─ Standard ERC20 transfers                         │  │
│  │                                                        │  │
│  │  DSCEngine.sol (Core Protocol)                       │  │
│  │  ├─ Collateral deposit/withdrawal (wETH, wBTC)      │  │
│  │  ├─ DSC minting/burning with health checks          │  │
│  │  ├─ Health factor calculation (USD-based)           │  │
│  │  ├─ Liquidation system with 10% bonus               │  │
│  │  ├─ Price feed management                           │  │
│  │  ├─ ReentrancyGuard on sensitive functions          │  │
│  │  └─ Comprehensive view functions for dApps          │  │
│  │                                                        │  │
│  │  HelperConfig.s.sol (Deployment Helper)             │  │
│  │                                                        │  │
│  │                                                        │  │
│  │  DeployDSC.s.sol (Deployment Script)                │  │
│  │                                                     │  │
│  └────────────────┬─────────────────────────────────────┘  │
│                   │                                           │
│  ┌────────────────┴─────────────────────────────────────┐  │
│  │      User Interaction Patterns                       │  │
│  │                                                        │  │
│  │  1. Deposit Collateral → DSCEngine                   │  │
│  │     ↓                                                   │  │
│  │  2. Check Health Factor → View Functions             │  │
│  │     ↓                                                   │  │
│  │  3. Mint DSC → DSCEngine (if health OK)              │  │
│  │     ↓                                                   │  │
│  │  4. Trade DSC → ERC20 transfer                       │  │
│  │     ↓                                                   │  │
│  │  5. Repay Debt → Burn DSC                            │  │
│  │     ↓                                                   │  │
│  │  6. Withdraw Collateral → DSCEngine (if health OK)   │  │
│  │                                                        │  │
│  │  Liquidation Path (For Liquidators):                 │  │
│  │  → Detect unhealthy position (HF < 1.0)             │  │
│  │  → Call liquidate() with user address               │  │
│  │  → Earn 10% bonus on collateral                      │  │
│  │  → System rebalances automatically                   │  │
│  └────────────────────────────────────────────────────┘  │
│                                                                │
└──────────────────────────────────────────────────────────────┘
```

### Smart Contract Interaction Flow

**Scenario: User mints DSC**

```
User sends transaction: depositCollateralAndMintDsc(wETH, 10e18, 500e18)
    ↓
DSCEngine._depositCollateral()
├─ Validates amount > 0
├─ Transfers wETH to contract via IERC20.transferFrom()
├─ Updates sCollateralDeposited[user][wETH]
└─ Emits CollateralDeposited event
    ↓
DSCEngine._mintDsc()
├─ Validates amount > 0
├─ Updates sDscMinted[user]
├─ Calls DecentralizedStableCoin.mint(user, amount)
├─ Calls revertIfHealthFactorIsBroken(user)
│   ├─ Gets user's total collateral value in USD
│   ├─ Gets user's total DSC minted
│   ├─ Calculates health factor = (collateralValueUsd * LIQUIDATION_THRESHOLD) / dscMinted
│   └─ Reverts if HF < 1.0
└─ Emits DscMinted event
    ↓
User now has 500 DSC in wallet, backed by 10 ETH collateral
```

**Scenario: Liquidator liquidates unhealthy position**

```
Liquidator calls: liquidate(address user, uint256 debtToCover)
    ↓
DSCEngine.liquidate()
├─ Validates debt > 0 and health factor < 1
├─ Calculates collateral bonus (10%)
├─ Burns user's DSC via DecentralizedStableCoin.burn()
├─ Transfers collateral reward to liquidator (debt * bonus)
├─ Updates user's collateral and debt
├─ Calls revertIfHealthFactorIsBroken(user) [optional]
└─ Emits Liquidation event
    ↓
System is rebalanced, liquidator earns reward, protocol stays safe
```

---

## 🚀 Quick Start

### Prerequisites

- **Node.js** 18+ (for package management)
- **Foundry** ([install here](https://book.getfoundry.sh/getting-started/installation))
- **Anvil** (local Ethereum simulator, included with Foundry)
- **Git** for version control
- An **Ethereum RPC** (Sepolia or similar) for testnet deployment
- A **code editor** (VS Code recommended)

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/defi-stablecoin.git
cd defi-stablecoin

# Install dependencies (OpenZeppelin, Chainlink contracts)
forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install smartcontractkit/chainlink-brownie-contracts --no-commit
forge install foundry-rs/forge-std --no-commit
```

### Smart Contract Compilation

```bash
# Compile all contracts
forge build

# Clean build artifacts
forge clean

```

### Running Tests

```bash
# Run all tests with verbose output
forge test -vvv

# Run specific test file
forge test --match-path test/unit/DSCEngineTest.t.sol -vvv

# Run with coverage report
forge coverage --report lcov

# Run invariant tests (fuzz testing system properties)
forge test --match-path test/fuzz/Invariants.t.sol -vvv

```

### Deployment

```bash
# Deploy to local Anvil network
anvil  # Terminal 1 - starts local Ethereum instance

forge script script/DeployDSC.s.sol:DeployDSC \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb476cce7f36bb641213ca8b53b8d \
  --broadcast \
  -vvv

# Deploy to Sepolia testnet
forge script script/DeployDSC.s.sol:DeployDSC \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY \
  --private-key YOUR_PRIVATE_KEY \
  --broadcast \
  -vvv \
  --verify \
  --etherscan-api-key YOUR_ETHERSCAN_KEY
```

### Verifying Contract Code

```bash
# Verify on Etherscan after deployment
forge verify-contract \
  0xYourContractAddress \
  src/DSCEngine.sol:DSCEngine \
  --constructor-args $(cast abi-encode "...constructor_args...") \
  --etherscan-api-key YOUR_KEY \
  --compiler-version v0.8.20
```

---

## 📦 Technology Stack

### Smart Contracts

| Tool             | Purpose                                     | Version |
| ---------------- | ------------------------------------------- | ------- |
| **Solidity**     | Smart contract language                     | 0.8.20  |
| **Foundry**      | Development framework & testing             | Latest  |
| **Forge**        | Contract compilation & testing              | Latest  |
| **Anvil**        | Local Ethereum simulator                    | Latest  |
| **OpenZeppelin** | Security utilities (ReentrancyGuard, ERC20) | v5.x    |
| **Chainlink**    | Oracle price feeds                          | v0.8    |

### Development Tools

| Tool             | Purpose                             |
| ---------------- | ----------------------------------- |
| **VS Code**      | Code editor with Solidity extension |
| **Cast**         | CLI for contract interactions       |
| **Bash Scripts** | Deployment automation               |

### Testing & Quality

| Framework             | Purpose                                     |
| --------------------- | ------------------------------------------- |
| **Forge Test**        | Unit and fuzz testing                       |
| **Invariant Testing** | Property-based testing with handlers        |
| **Solhint**           | Linting (Juan Blanco extension recommended) |

---

## 🧪 Testing Strategy

### Test Organization

```
test/
├── unit/
│   └── DSCEngineTest.t.sol          # Unit tests (constructor, deposit, mint, etc.)
├── fuzz/
│   ├── Handler.t.sol                 # Stateful fuzzing handlers
│   ├── Invariants.t.sol              # System invariant tests
│   ├── failOnRevert/                 # Tests that fail on any revert
│   └── continueOnRevert/             # Tests that continue on revert
└── mocks/
    ├── ERC20Mock.sol                 # Mock ERC20 for testing
    ├── MockV3Aggregator.sol          # Mock Chainlink price feed
    └── MockMoreDebtDSC.sol           # Mock for edge case testing
```

### Test Coverage

```bash
# Generate coverage report
forge coverage --report lcov

# View in browser
lcov --list coverage.lcov
```

---

## 🔑 Core Contract Reference

### DSCEngine.sol - Main Protocol Contract

#### State Variables & Constants

```solidity
// Constants
uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
uint256 private constant PRECISION = 1e18;
uint256 private constant LIQUIDATION_THRESHOLD = 50;      // 200% required collateral
uint256 private constant LIQUIDATION_PRECISION = 100;
uint256 private constant MIN_HEALTH_FACTOR = 1 * 1e18;    // 1.0
uint256 private constant LIQUIDATION_BONUS = 10;          // 10% liquidator bonus

// Mappings
mapping(address token => address priceFeed) private sPriceFeeds;
mapping(address user => mapping(address token => uint256 amount)) private sCollateralDeposited;
mapping(address user => uint256 amount) private sDscMinted;
address[] private sCollateralTokens;

DecentralizedStableCoin private immutable dsc;  // The stablecoin token
```

#### Critical Functions

| Function                                                   | Description                                    | Returns              |
| ---------------------------------------------------------- | ---------------------------------------------- | -------------------- |
| `depositCollateral(token, amount)`                         | Deposit collateral to increase borrowing power | —                    |
| `withdrawCollateral(token, amount)`                        | Withdraw deposited collateral                  | —                    |
| `mintDsc(amount)`                                          | Mint DSC against collateral                    | —                    |
| `burnDsc(amount)`                                          | Burn DSC to free up collateral                 | —                    |
| `depositCollateralAndMintDsc(token, colAmount, dscAmount)` | Atomic operation                               | —                    |
| `redeemCollateralForDsc(token, colAmount, dscAmount)`      | Atomic redemption                              | —                    |
| `liquidate(user, debtToCover)`                             | Liquidate undercollateralized position         | —                    |
| `getHealthFactor(user)`                                    | Get account health factor                      | uint256 (1.0 = 1e18) |
| `getAccountCollateralValue(user)`                          | Get total collateral value in USD              | uint256              |
| `getAccountInformation(user)`                              | Get debt and collateral                        | (uint256, uint256)   |
| `getUsdValue(token, amount)`                               | Convert token amount to USD                    | uint256              |
| `getTokenAmountFromUsd(token, usdAmount)`                  | Convert USD to token amount                    | uint256              |

#### Error Types

```solidity
error DSCEngine__MustBeMoreThanZero();
error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
error DSCEngine__NotAllowedToken();
error DSCEngine__TransferFailed();
error DSCEngine__BreaksHealthFactor();
error DSCEngine__InvalidPrice();
error DSCEngine__MintFailed();
error DSCEngine__HealthFactorOk();
error DSCEngine__HealthFactorNotImproved();
```

### DecentralizedStableCoin.sol - ERC20 Token

```solidity
// Only DSCEngine can mint and burn
function mint(address to, uint256 amount) public onlyEngine returns (bool)
function burn(uint256 amount) public onlyEngine returns (bool)

// Standard ERC20 functions
transfer(), transferFrom(), approve(), etc.
```

---

## 🛡️ Security Considerations

### Access Control

- ✅ **DSCEngine**: Only owner can set up price feeds
- ✅ **DecentralizedStableCoin**: Only DSCEngine can mint/burn
- ✅ **ReentrancyGuard**: Protects all external calls in DSCEngine
- ✅ **Reentrancy Pattern**: Checks-Effects-Interactions pattern strictly followed

### Health Factor Safety

- ✅ **Continuous Monitoring**: Health factor checked after every state change
- ✅ **200% Minimum Collateral**: LIQUIDATION_THRESHOLD = 50 (50/100 = 50% ratio)
- ✅ **Liquidation Incentives**: 10% bonus encourages timely liquidations
- ✅ **No Governance Risk**: Immutable parameters prevent attack vectors

---

## 📚 Code Quality & Conventions

This project follows the **strict Solidity conventions** defined in [.github/instructions/solidity-conventions.instructions.md](.github/instructions/solidity-conventions.instructions.md).

### Code Organization

Every contract follows this structure:

```solidity
// 1. SPDX License & pragma
// 2. Imports
// 3. Interfaces, libraries, contracts
// 4. Errors
// 5. Type declarations
// 6. State variables
// 7. Events
// 8. Modifiers
// 9. Functions (organized by visibility)
```

### Function Ordering

```solidity
contract Example {
    // 1. Constructor
    constructor() { ... }

    // 2. Receive / Fallback (if applicable)
    receive() external payable { ... }

    // 3. External functions
    function externalFunc() external { ... }

    // 4. Public functions
    function publicFunc() public { ... }

    // 5. Internal functions
    function _internalFunc() internal { ... }

    // 6. Private functions
    function _privateFunc() private { ... }

    // 7. View & Pure functions
    function getStatus() public view returns (bool) { ... }
}
```

### Naming Conventions

- **State Variables**: `sVariableName` (e.g., `sPriceFeeds`, `sCollateralDeposited`)
- **Constants**: `CONSTANT_NAME` (e.g., `MIN_HEALTH_FACTOR`, `LIQUIDATION_THRESHOLD`)
- **Errors**: `ContractName__DescriptiveError` (e.g., `DSCEngine__BreaksHealthFactor`)
- **Events**: `PastTenseAction` (e.g., `CollateralDeposited`, `DscMinted`)

### Documentation

All public/external functions have complete NatSpec:

```solidity
/**
 * @notice User-facing description
 * @param paramName Description
 * @return returnName Description
 * @dev Implementation details and edge cases
 */
```

---

## 🤝 Contributing

We welcome security researchers, developers, and enthusiasts to contribute!

### Development Workflow

1. **Fork & Clone**

   ```bash
   git clone https://github.com/yourusername/defi-stablecoin.git
   cd defi-stablecoin
   ```

2. **Create Feature Branch**

   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make Changes & Test Locally**

   ```bash
   forge test -vvv
   forge coverage
   ```

4. **Push & Create Pull Request**

   ```bash
   git push origin feature/your-feature-name
   ```

5. **PR Checklist**
   - [ ] All tests pass locally (`forge test -vvv`)
   - [ ] Coverage maintained or improved (`forge coverage`)
   - [ ] Code follows conventions (NatSpec, naming, organization)
   - [ ] No console.log() left in production code
   - [ ] Events emitted for state changes
   - [ ] Comments explain complex logic

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Cyfrin Updraft** - Advanced Foundry course and educational resources for smart contract development
- **Chainlink** - Reliable oracle infrastructure for price feeds
- **OpenZeppelin** - Security best practices and battle-tested contracts
- **Foundry** - Exceptional Solidity development framework
- **Ethereum** - The foundation of decentralized finance

---

<div align="center">

**Made with 💰 by WIMA**

[GitHub](https://github.com/wmachaca) • [Twitter](https://twitter.com/yourhandle)

> "In crypto we trust, in code we verify" — Build secure, test thoroughly, stay vigilant.

</div>
