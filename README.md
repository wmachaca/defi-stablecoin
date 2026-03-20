1. (Relative Stability) Achored or Pegged -> $1.00.
   1. Chainlink Price feed.
   2. Set a function to exchange ETH & BTC -> $$$ (USD equivalent).
2. Stability Mechanism (Minting): Algorithmic (Decentralized).
   1. People can only mint the stablecoin with enough collateral (coded).
3. Collateral: Exogenous (Crypto): wETH or wBTC (ERC20 version of ETH and BTC).

# linting:

solhint.json works better with solidity from juan blanco and not with solidity from nomic foundation. The last one do not show the errors inside the editor when working with foundry.

#

- calculate health factor function.
- set health factor if debt is 0.
- added a bunch of view functions

1- What are our invarian/properties? -> Fuzz testing: you supply random data to your system in an attempt to break it. Semi random data to find the sceneario when the function may explote. It only works on invariants (properties of the system that must always hold).
