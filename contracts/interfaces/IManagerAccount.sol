// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

struct LiquidityParameters {
    IERC20 tokenX;
    IERC20 tokenY;
    uint256 binStep;
    uint256 amountX;
    uint256 amountY;
    uint256 amountXMin;
    uint256 amountYMin;
    uint256 activeIdDesired;
    uint256 idSlippage;
    int256[] deltaIds;
    uint256[] distributionX;
    uint256[] distributionY;
    address to;
    uint256 deadline;
}


interface IManagerAccount {

    function initializeAccount(address guard_, address manager_, address ILBRouterAddress_) external;

    function setERC20Approval(address token_) external;

    function removeLiquidity(address pairAddress_, uint256[] memory ids_, uint256[] memory amounts_, uint256 deadline_) external;

    function repay(address repayToken_) external;

    function borrow(address borrowToken_, uint256 borrowAmount_) external;

    function deposit(address token_, uint256 amountIn_) external;

    function withdraw(address token_, uint256 amountOut_) external;

    function updateFreezeState(bool state_) external;

    function transferOut(address to_, address token_, uint256 amountOut_) external;

    function transferIn(address from_, address token_, uint256 amountIn_) external;

    function getAccountFrozen() external view returns(bool);

    function getAssessState() external view returns(bool);

    function getCredit() external view returns(uint256);

    function getManager() external view returns(address);

    function getApprovedLBPairsLength() external view returns(uint256);

    function getApprovedLBPairByIndex(uint256 index_) external view returns(address);

    function getLBPairApprovalIf(address lbPair_) external view returns(bool);

    function getAccountBalanceAvailableLast(address token_) external view returns(uint256);

    function getAccountBalanceAvailable(address token_) external view returns(uint256);

    function getLBPairInfoMapping(address pair_) external view returns(IERC20,IERC20,uint256);

    function getLBPairInfoTokenX(address pair_) external view returns(IERC20);

    function getLBPairInfoTokenY(address pair_) external view returns(IERC20);

    function getLBPairInfoTokenBinStep(address pair_) external view returns(uint256);

    function getMMLBPairToIdSetLength(address pair_) external view returns(uint256);

    function getMMLBPairToIdSetAtValue(address pair_, uint256 index_) external view returns(uint256);

    function getMMLBPairToIdToAmount(address pair_, uint256 id_) external view returns(uint256);

}
