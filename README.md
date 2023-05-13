[LiquidX Protocol Contracts](https://github.com/hyahhhhjj/LiquidXContracts/tree/master)

This repository contains the LiquidX Protocol contracts, as well as tests and deploy scripts.

The AccountsGuard is the contract that protocol guard use to check manager assets and force liquidation if assets condition is not healthy.

The LBErrors is a simplified version TradeJoe V2's LBErrors.

The LiquidXAggregator is the contract that aggregates manager accounts and LiquidX stake pools.

The LiquidXErrors is the contract that contains all the error types that other contract may use.

The LiquidXStakePool is the contract used to calculate the shares of a user. The LiquidXStakePool shares satisfying ERC20 token standard. It can be transferred.

The ManagerAccount is the contract that implements manager operations, including adding/removing liquidity, borrowing/repaying asset and depositing/withdrawing funds.
