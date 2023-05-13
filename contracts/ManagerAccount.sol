// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import './LiquidXStakePool.sol'; // replace contract with interface
import './LiquidXErrors.sol';

import './library/LowLevelCallHelper.sol';
import './library/Math512Bits.sol';

import './interfaces/ILiquidXAggregator.sol';
import './interfaces/IManagerAccount.sol';
import './interfaces/ILBToken.sol';

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/// @title LiquidX ManagerAccount
/// @author Yuang Huang
/// @notice This contract is the implementation of Manager Account
/// @dev This contract dynamically created by contract factory which is LiquidXAggregator
contract ManagerAccount is IManagerAccount, ReentrancyGuard{
    /// @dev Liquidity Parameters used to call tradeJoe interface
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

    using EnumerableSet for EnumerableSet.Bytes32Set;
    using LowLevelCallHelper for address;
    using Math512Bits for uint256;


    bool private accountFrozen;
    bool private assessState;
    /// @dev credit <= 2 ** 16
    uint256 private credit;

    address private guard;
    address private manager;
    address private liquidxAggregator;
    /// @dev fixed liquidity book V2 router address
    address private ILBRouterAddress;

    /// @dev mapping from erc20 token address to bool value
    mapping(address => bool) private erc20Approval;
    /// @dev mapping from erc20 token address to amount
    mapping(address => uint256) private accountBalanceAvailableLast;
    /// @dev mapping from erc20 token address to amount
    mapping(address => uint256) private accountBalanceAvailable;
    /// @dev mapping from LB pair address to id set, which also can be considered as array
    mapping(address => EnumerableSet.Bytes32Set) private mmLBPairToIdSet;
    /// @dev mapping from LB pair address to another mapping which maps id value to minted amount token on this id
    mapping(address => mapping(uint256 => uint256)) private mmLBPairToIdToAmount;

    modifier onlyLiquidXAggregator(){
        require(msg.sender == liquidxAggregator);
        _;
    }

    modifier onlyManager(){
        require(msg.sender == manager);
        _;
    }

    modifier onlyGuard(){
        require(msg.sender == guard);
        _;
    }

    modifier safeCheck(){
        require((!accountFrozen && msg.sender == manager) || msg.sender == liquidxAggregator || msg.sender == guard);
        _;
    }
    /// @notice special modifier to enable credit assessment
    /// first it will check if any lb token minted. if it is, then the credit assessment would not start
    /// @dev called before add liquidity
    modifier creditAssessInit(){
        bool liquidityRemovedAll = true;
        for (uint i = 0; i < getApprovedLBPairsLength(); i++){
            if(mmLBPairToIdSet[getApprovedLBPairByIndex(i)].length() != 0){
                liquidityRemovedAll = false;
                break;
            }
        }
        /// every repay, borrow, deposit, withdraw would turn assessState to false
        if (liquidityRemovedAll && assessState == false){
            uint256 length = ILiquidXAggregator(liquidxAggregator).getStakePoolsLength();
            for(uint i = 0; i < length; i++){
                address forLoopToken = LiquidXStakePool(ILiquidXAggregator(liquidxAggregator).getStakePoolByIndex(i)).getStakeTokenAddress();
                accountBalanceAvailableLast[forLoopToken] = accountBalanceAvailable[forLoopToken];
            }
            assessState = true;
        }
        _;
    }

    ///5.8update add new condition of calculating min ratio(accountBalanceAvailableLast[forLoopToken] > 0). towardsPositive and towardsNegative are deprecated
    /// @notice finish credit assessment
    /// first, it will check if all liquidity is removed and if the credit assessment has began
    /// @dev called whenever manager remove liquidity
    modifier creditAssessEnd(){
        bool liquidityRemovedAll = true;
        for (uint i = 0; i < getApprovedLBPairsLength(); i++){
            if(mmLBPairToIdSet[getApprovedLBPairByIndex(i)].length() != 0){
                liquidityRemovedAll = false;
                break;
            }
        }
        if (liquidityRemovedAll && assessState){
            uint256 length = ILiquidXAggregator(liquidxAggregator).getStakePoolsLength();
            uint256 minRatio;
            address forLoopToken;
            for(uint i = 0; i < length; i++){
                forLoopToken = LiquidXStakePool(ILiquidXAggregator(liquidxAggregator).getStakePoolByIndex(i)).getStakeTokenAddress();
                /// apply min(y2 / y1) - 1 (y2 > y1) or 1 - min(y2 / y1) (y2 < y1)
                /// accountBalanceAvailableLast[forLoopToken] cannot be zero
                if(accountBalanceAvailableLast[forLoopToken] > 0){
                    if(minRatio > 0) minRatio = min(minRatio,  uint256(accountBalanceAvailable[forLoopToken].shiftDivRoundDown(16, accountBalanceAvailableLast[forLoopToken]))); // inline fixed-point(16X16) number generation
                    else{
                       minRatio = uint256(accountBalanceAvailable[forLoopToken].shiftDivRoundDown(16, accountBalanceAvailableLast[forLoopToken]));
                    }
                }
            }
            if (minRatio > 2 ** 16){
                credit += (minRatio - 2 ** 16);
                if(credit > 2 ** 16){
                    credit = 2 ** 16;
                }
            }else if(minRatio < 2 ** 16){
                if((2 ** 16 - minRatio) < credit){
                    credit -= (2 ** 16 - minRatio);
                }else{
                    credit = 0;
                }
            }
        }
        assessState = false;
        _;
    }

    constructor() public{
        liquidxAggregator = msg.sender;
    }

    /// @notice initialize account by LiquidXAggregator
    /// @dev only called by LiquidXAggregator
    function initializeAccount(address guard_, address manager_, address ILBRouterAddress_) external override onlyLiquidXAggregator {
        guard = guard_;
        manager = manager_;
        ILBRouterAddress = ILBRouterAddress_;
    }

    /// @notice set erc20 approval
    function setERC20Approval(address token_) public override safeCheck{
        if (ILBRouterAddress == address(0)) revert ManagerAccount__AccountNotInitialized();
        erc20Approval[token_] = true;
        IERC20(token_).approve(ILBRouterAddress, type(uint256).max);
        ILiquidXAggregator(liquidxAggregator).approveFromAccount(token_);
    }

    /// @notice add liquidity. This is wrapped version of adding liquidity function
    /// to update LiquidX Protocol state
    /// @param pairAddress_ LB pair address which should be added to protocol in advance by contract guard.
    /// @param paramsUser_ LiquidityParameters
    function addLiquidity(address pairAddress_, LiquidityParameters memory paramsUser_) external safeCheck creditAssessInit nonReentrant{
        if(getLBPairApprovalIf(pairAddress_) == false) revert ManagerAccount__PairNotExists();
        (paramsUser_.tokenX, paramsUser_.tokenY, paramsUser_.binStep) = getLBPairInfoMapping(pairAddress_);
        if(!erc20Approval[address(paramsUser_.tokenX)]) setERC20Approval(address(paramsUser_.tokenX));
        if(!erc20Approval[address(paramsUser_.tokenY)]) setERC20Approval(address(paramsUser_.tokenY));
        paramsUser_.to = address(this);
        /// perform a low-level call to lower contract creation gas cost
        bytes memory data = abi.encodeWithSignature("addLiquidity((address,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,int256[],uint256[],uint256[],address,uint256))", paramsUser_); //this can be replaced abi.encodeWithSelector
        bytes memory results = ILBRouterAddress._callAndCatchError(data);
        /// decode results update minted liquidity
        (uint256[] memory depositIds, uint256[] memory liquidityMinted) = abi.decode(results, (uint256[], uint256[]));
        for (uint256 i = 0; i < depositIds.length; i++){
            if(mmLBPairToIdToAmount[pairAddress_][depositIds[i]] == 0) mmLBPairToIdSet[pairAddress_].add(bytes32(depositIds[i]));
            mmLBPairToIdToAmount[pairAddress_][depositIds[i]] += liquidityMinted[i];
        }
        /// update new erc20 balance
        accountBalanceAvailable[address(paramsUser_.tokenX)] = paramsUser_.tokenX.balanceOf(address(this));
        accountBalanceAvailable[address(paramsUser_.tokenY)] = paramsUser_.tokenY.balanceOf(address(this));
    }

    function removeLiquidity(
        address pairAddress_,
        uint256[] calldata ids_,
        uint256[] calldata amounts_,
        uint256 deadline_) external override safeCheck nonReentrant{
        _removeLiquidity(pairAddress_, ids_, amounts_, deadline_);
    }

    /// @notice remove liquidity. This is wrapped version of removing liquidity function
    /// @dev it will collect fees first and then remove liquidity
    /// @param pairAddress_ LB pair address which should be added to protocol in advance by contract guard.
    /// @param ids_ id array(can be found in tradeJoe router V2 interface)
    /// @param amounts_ amounts array(can be found in tradeJoe router V2 interface)
    /// @param deadline_ deadline
    function _removeLiquidity(
        address pairAddress_,
        uint256[] memory ids_,
        uint256[] memory amounts_,
        uint256 deadline_) internal {
        if(getLBPairApprovalIf(pairAddress_) == false) revert ManagerAccount__PairNotExists();
        if(!ILBToken(pairAddress_).isApprovedForAll(address(this), ILBRouterAddress)) ILBToken(pairAddress_).setApprovalForAll(ILBRouterAddress, true);
        (IERC20 tokenX, IERC20 tokenY, uint256 binStep) = getLBPairInfoMapping(pairAddress_);
        ILiquidXAggregator(liquidxAggregator).collectFeesFromAccount(pairAddress_, ids_, tokenX, tokenY);
        bytes memory data = abi.encodeWithSignature("removeLiquidity(address,address,uint16,uint256,uint256,uint256[],uint256[],address,uint256)", tokenX, tokenY, uint16(binStep), 0, 0, ids_, amounts_, address(this), deadline_);
        ILBRouterAddress._callAndCatchError(data);
        /// update new lbt liquidity
        for (uint i = 0; i < ids_.length; i++){
            mmLBPairToIdToAmount[pairAddress_][ids_[i]] -= amounts_[i];
            if(mmLBPairToIdToAmount[pairAddress_][ids_[i]] == 0) mmLBPairToIdSet[pairAddress_].remove(bytes32(ids_[i]));
        }
        /// update new balance
        accountBalanceAvailable[address(tokenX)] = tokenX.balanceOf(address(this));
        accountBalanceAvailable[address(tokenY)] = tokenY.balanceOf(address(this));
    }

    // this function should be deleted by formally deploying this contract on chain
    function testCollectFees(address pairAddress_, uint256[] memory ids_, IERC20 tokenX, IERC20 tokenY) external{
        ILiquidXAggregator(liquidxAggregator).collectFeesFromAccount(pairAddress_, ids_, tokenX, tokenY);
    }

    /// @dev call repay/borrow/deposit/withdraw function will result in ending credit assessment
    function repay(address repayToken_) external override safeCheck creditAssessEnd {
        ILiquidXAggregator(liquidxAggregator).repayFromAccount(repayToken_);
    }

    function borrow(address borrowToken_, uint256 borrowAmount_) external override safeCheck creditAssessEnd {
        ILiquidXAggregator(liquidxAggregator).borrowFromAccount(borrowToken_, borrowAmount_);
    }

    function deposit(address token_, uint256 amountIn_) external override safeCheck creditAssessEnd{
        ILiquidXAggregator(liquidxAggregator).depositFromAccount(msg.sender, token_, amountIn_);
    }

    function withdraw(address token_, uint256 amountOut_) external override safeCheck creditAssessEnd{
        ILiquidXAggregator(liquidxAggregator).withdrawFromAccount(msg.sender, token_, amountOut_);
    }

    function collectFees(address pairAddress_, uint256[] calldata ids_, IERC20 tokenX_, IERC20 tokenY_) external onlyLiquidXAggregator returns(uint256 amountX, uint256 amountY){
        bytes memory data = abi.encodeWithSignature("collectFees(address,uint256[])", address(this), ids_);
        bytes memory results = pairAddress_._callAndCatchError(data);
        (amountX, amountY) = abi.decode(results, (uint256, uint256));
        accountBalanceAvailable[address(tokenX_)] += amountX;
        accountBalanceAvailable[address(tokenY_)] += amountY;
    }

    /// @notice froze a account if necessary
    /// the frozen of account will also result in blocking manager's wallet address
    /// @dev only called by account guard
    function updateFreezeState(bool state_) external override onlyLiquidXAggregator{
        if(state_ != accountFrozen) accountFrozen = !accountFrozen;
    }

    /// @notice internal transferring unction to realize borrow/repay/distributingFees functions
    /// @dev only called by LiquidXAggregator
    function transferOut(address to_, address token_, uint256 amountOut_) external override onlyLiquidXAggregator{
        accountBalanceAvailable[token_] -= amountOut_;
        IERC20(token_).transfer(to_, amountOut_);
    }

    function transferIn(address from_, address token_, uint256 amountIn_) external override onlyLiquidXAggregator{
        accountBalanceAvailable[token_] += amountIn_;
        IERC20(token_).transferFrom(from_, address(this), amountIn_);
    }

    function min(uint256 a, uint256 b) internal pure returns(uint256){
        if(a < b) return a;
        else return b;
    }

    function getAccountFrozen() public view override returns(bool){
        return accountFrozen;
    }

    function getAssessState() public view override returns(bool){
        return assessState;
    }

    function getCredit() public view override returns(uint256){
        return credit;
    }

    function getManager() public view override returns(address){
        return manager;
    }

    function getApprovedLBPairsLength() public view override returns(uint256){
        return ILiquidXAggregator(liquidxAggregator).getLBPairsAllowedLength();
    }

    function getApprovedLBPairByIndex(uint256 index_) public view override returns(address){
        return ILiquidXAggregator(liquidxAggregator).getLBPairAllowedByIndex(index_);
    }

    function getLBPairApprovalIf(address lbPair_) public view override returns(bool){
        return ILiquidXAggregator(liquidxAggregator).getLBPairApprovalIf(lbPair_);
    }

    /// @notice View function to get the manager balance before credit assessment begins
    /// @param token_ token address
    /// @return token amount
    function getAccountBalanceAvailableLast(address token_) public view override returns(uint256){
        return accountBalanceAvailableLast[token_];
    }

    /// @notice View function to get current manager balance
    /// @param token_ token address
    /// @return token amount
    function getAccountBalanceAvailable(address token_) public view override returns(uint256){
        return accountBalanceAvailable[token_];
    }

    /// @notice View function to get LB pair information
    function getLBPairInfoMapping(address pair_) public view override returns(IERC20,IERC20,uint256){
        return ILiquidXAggregator(liquidxAggregator).getLBPairInfoMapping(pair_);
    }

    function getLBPairInfoTokenX(address pair_) public view override returns(IERC20){
        return ILiquidXAggregator(liquidxAggregator).getLBPairInfoTokenX(pair_);
    }

    function getLBPairInfoTokenY(address pair_) public view override returns(IERC20){
        return ILiquidXAggregator(liquidxAggregator).getLBPairInfoTokenY(pair_);
    }

    function getLBPairInfoTokenBinStep(address pair_) public view override returns(uint256){
        return ILiquidXAggregator(liquidxAggregator).getLBPairInfoTokenBinStep(pair_);
    }
    /// @notice View function to get manager current minted lb token ids' length
    /// @param pair_ LB pair address
    function getMMLBPairToIdSetLength(address pair_) public view override returns(uint256){
        return uint256(mmLBPairToIdSet[pair_].length());
    }

    /// @notice View function to get manager current minted lb token id value
    /// @param pair_ LB pair address
    /// @param index_ the index of id array
    function getMMLBPairToIdSetAtValue(address pair_, uint256 index_) public view override returns(uint256){
        return uint256(mmLBPairToIdSet[pair_].at(index_));
    }
    /// storage can be returned from internal function, not public view
    function getMMLBPairToIdToAmount(address pair_, uint256 id_) public view override returns(uint256){
        return mmLBPairToIdToAmount[pair_][id_];
    }

}
