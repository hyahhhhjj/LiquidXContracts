# LiquidX Protocol Contracts
This repository contains the contracts for the LiquidX Protocol, as well as tests and deployment scripts.

## Contracts
The following contracts are included in this repository:

- `AccountsGuard`: The contract used by the protocol guard to check manager assets and force liquidation if asset conditions are not healthy.
- `LBErrors`: A simplified version of TradeJoe V2's LBErrors.
- `LiquidXAggregator`: The contract that aggregates manager accounts and LiquidX stake pools.
- `LiquidXErrors`: The contract that contains all the error types that other contracts may use.
- `LiquidXStakePool`: The contract used to calculate user shares and satisfy ERC20 token standards. It can be transferred.
- `ManagerAccount`: The contract that implements manager operations, including adding/removing liquidity, borrowing/repaying assets, and depositing/withdrawing funds.

## Usage
To use these contracts, you can either deploy them yourself or use the deployed contracts on the Ethereum mainnet or testnets. 

## Contributing
If you would like to contribute to this repository, please follow the guidelines in CONTRIBUTING.md and submit a pull request.

## License
This project is licensed under the [MIT License](LICENSE).
