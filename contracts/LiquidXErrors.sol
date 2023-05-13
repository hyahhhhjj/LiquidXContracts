// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

error LiquidXStakePool__PoolNotEstablished();

error ManagerAccount__LowLevelCallFails();
error ManagerAccount__PairNotExists();
error ManagerAccount__ArrayLengthNotMatch();
error ManagerAccount__AccountNotInitialized();

error LiquidXAggregator__MangerAccountExists(address managerAccount_);
error LiquidXAggregator__CorrespondingStakePoolNotCreated();
error LiquidXAggregator__StakePoolExists(address pool_);
error LiquidXAggregator__AccountExists(address account_);
error LiquidXAggregator__WithdrawAmountExceedsMaxAllowed(address token_, uint256 amountOut_);
error LiquidXAggregator__LeverageExceedsMaxAllowed();