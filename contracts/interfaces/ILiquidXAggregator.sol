// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface ILiquidXAggregator {

    function updateGuard(address guard_) external;

    function addNewLBPair(address lbPair_, address tokenX_, address tokenY_, uint256 binStep_) external;

    function deleteLBPair(address lbPair_) external;

    function addStakePool(address stakePool_) external;

    function createManagerAccount(address manager_, address ILBRouterAddress_) external;

    function borrowFromAccount(address borrowToken_, uint256 borrowAmount_) external;

    function repayFromAccount(address repayToken_) external;

    function collectFeesFromAccount(address pairAddress_, uint256[] calldata ids_, IERC20 tokenX_, IERC20 tokenY_) external;

    function depositFromAccount(address from_, address token_, uint256 amountIn_) external;

    function withdrawFromAccount(address to_, address token_, uint256 amountOut_) external;

    function approveFromAccount(address token_) external;

    function getOwner() external view returns(address);

    function getGuard() external view returns(address);

    function getManagerAccountsLength() external view returns(uint256);

    function getManagerAccountByIndex(uint256 index_) external view returns(address);

    function getStakePoolsLength() external view returns(uint256);

    function getStakePoolByIndex(uint256 index_) external view returns(address);

    function getLBPairsAllowedLength() external view returns(uint256);

    function getLBPairAllowedByIndex(uint256 index_) external view returns(address);

    function getAllLBPairsAllowed() external returns(address[] memory);

    function getLBPairApprovalIf(address lbPair_) external view returns(bool);

    function getAccount(address manager_) external view returns(address);

    function getStakePool(address token_) external view returns(address);

    function getLBPairInfoMapping(address pair_) external view returns(IERC20,IERC20,uint256);

    function getLBPairInfoTokenX(address pair_) external view returns(IERC20);

    function getLBPairInfoTokenY(address pair_) external view returns(IERC20);

    function getLBPairInfoTokenBinStep(address pair_) external view returns(uint256);

    function getMarginAvailableByAsset(address manager_, address asset_) external view returns(uint256);

    function getMarginFrozenByAsset(address manager_, address asset_) external view returns(uint256);

    function getManagerBorrowedAmount(address manager_, address asset_) external view returns(uint256);

}
