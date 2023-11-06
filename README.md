# Perpetual Exchange Smart Contract

This repository contains a Solidity smart contract for the first mission of Owen Thurm's Security Course. The mission is to create a perpetual exchange with specified functionalities and corresponding tests.

## Mission Details

- **Objective:** Develop a perpetual exchange where liquidity providers can manage liquidity and traders can manage their positions in a decentralized manner.
- **Functionalities:**
  - Liquidity providers can deposit and withdraw liquidity.
  - Real-time price fetching of the traded asset.
  - Opening perpetual positions for BTC with specified size and collateral.
  - Increasing the size of a perpetual position.
  - Increasing the collateral of a perpetual position.
  - Ensuring traders do not utilize more than a configured percentage of the deposited liquidity.
  - Preventing liquidity providers from withdrawing liquidity that is reserved for open positions.
- **Additional Notes:**
  - Fees are not required to be implemented.
  - The contract does not handle decreasing, closing, or liquidating positions, although these are considerations for future development.
  - The USDC price is hardcoded within the contract.

## Quick Start

### Prerequisites

- [Node.js](https://nodejs.org/en/) >= v14.x
- [Yarn](https://yarnpkg.com/) or [npm](https://www.npmjs.com/)
- [Foundry](https://getfoundry.sh/) for Forge and Cast

### Installation

Clone the repository and install dependencies:

```sh
git clone https://github.com/gas-limit/perpetual-exchange.git
cd perpetual-exchange
yarn install
```

### Compilation

Compile the contract with Forge:

```sh
forge build
```

### Testing

Run tests to validate the implemented functionalities:

```sh
forge test
```

## Usage

Deploy the contract to a network using Forge:

```sh
forge create src/simple-perpetual-exchange.sol:perpetual --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

## Development

The contract is located in `simple-perpetual-exchange.sol` and utilizes interfaces for ERC20 tokens and Chainlink's price feed.

## Contributing

Contributions are welcome. Please ensure to follow the mission's specifications for any pull requests.

## License

This project is under the MIT License - see the LICENSE file for details.