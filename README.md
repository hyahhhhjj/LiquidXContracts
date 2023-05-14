# LiquidX Protocol Contracts
This repository contains the contracts for the LiquidX Protocol, as well as tests and deployment scripts.

## Contracts
The following contracts are included in this repository:

- `AccountsGuard`: The contract is used by the protocol guard to check manager assets and force liquidation if asset conditions are not healthy.
- `LBErrors`: A simplified version of TradeJoe V2's LBErrors.
- `LiquidXAggregator`: The contract that aggregates manager accounts and LiquidX stake pools.
- `LiquidXErrors`: The contract that contains all the error types that other contracts may use.
- `LiquidXStakePool`: The contract is used to calculate and mint/burn user shares which satisfies ERC20 token standards. 
- `ManagerAccount`: The contract is used to implement manager operations, including adding/removing liquidity, borrowing/repaying assets, and depositing/withdrawing funds.

For more information, you can go to [LiquidXProtocol_LitePaper](https://github.com/hyahhhhjj/LiquidXContracts/blob/master/documentation/LiquidXProtocol_LitePaper.pdf)

## Usage
To use these contracts, you can either deploy them yourself or use the deployed contracts on the Ethereum mainnet or testnets. 

## Contributing
If you would like to contribute to this repository, please follow the guidelines in CONTRIBUTING.md and submit a pull request.

## License
This project is licensed under the [MIT License](LICENSE).
