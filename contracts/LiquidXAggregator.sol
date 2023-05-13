// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import './LiquidXStakePool.sol';
import './ManagerAccount.sol';
import './interfaces/ILiquidXAggregator.sol';
import './interfaces/IManagerAccount.sol';
import './library/Math512Bits.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

struct PairInfo{
    IERC20 tokenX;
    IERC20 tokenY;
    uint256 binStep;
}

/// @title LiquidXAggregator
/// @author Yuang Huang
/// @notice This contract is the implementation of LiquidXAggregator to aggregate manager accounts and LiquidX stake pools
contract LiquidXAggregator is ILiquidXAggregator{
    using Math512Bits for uint256;
    using LowLevelCallHelper for address;
    address private owner; // creator of this contract
    address private guard; // ultimate controller of this contract
    address private accountsGuard;

    address[] private allManagerAccounts;
    address[] private allStakePools;
    address[] private allLBPairsAllowed;

    /// @dev mapping from LB pair address to bool value
    mapping(address => bool) private LBPairsToApproval;
    /// @dev mapping from manger address to account address
    mapping(address => address) private managerToAccount; // unidirectional mapping
    /// @dev mapping from account address to manager address
    mapping(address => address) private accountToManager;
    /// @dev mapping from stake pool address to erc20 token address
    mapping(address => address) private poolToToken; // unidirectional mapping
    /// @dev mapping from lb pair address to pair information struct
    mapping(address => PairInfo) private LBPairInfoMapping;
    /// @notice available manager Margin
    /// @dev mapping from account address to another mapping(erc20 token address to amount)
    mapping(address => mapping(address => uint256)) private managerMarginAvailable;
    /// @notice frozen margin of manager account
    /// @dev mapping from account address to another mapping(erc20 token address to amount)
    mapping(address => mapping(address => uint256)) private managerMarginFrozen;
    /// @notice manager borrowed assets
    /// @dev mapping from account address to another mapping(erc20 token address to amount)
    mapping(address => mapping(address => uint256)) private managerBorrowedAssets;

    constructor(address accountsGuard_) public{
        owner = msg.sender;
        guard = msg.sender;
        accountsGuard = accountsGuard_;
    }

    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    modifier onlyGuard(){
        require(msg.sender == guard);
        _;
    }

    modifier onlyManagerAccount(){
        require(accountToManager[msg.sender] != address(0));
        _;
    }

    function updateGuard(address guard_) external override onlyOwner{
        guard = guard_;
    }

    /// @notice add new pair to aggregator
    /// @dev only called by guard
    /// @param lbPair_ liquidity book pair address
    /// @param tokenX_ The address of the tokenX. Can't be address 0
    /// @param tokenY_ The address of the tokenY. Can't be address 0
    /// @param binStep_ The binStep of lbPair_
    function addNewLBPair(
        address lbPair_,
        address tokenX_,
        address tokenY_,
        uint256 binStep_) external override onlyGuard{
        if(poolToToken[tokenX_] == address(0) || poolToToken[tokenY_] == address(0)) revert LiquidXAggregator__CorrespondingStakePoolNotCreated();
        allLBPairsAllowed.push(lbPair_);
        LBPairsToApproval[lbPair_] = true;
        LBPairInfoMapping[lbPair_] = PairInfo(IERC20(tokenX_), IERC20(tokenY_), binStep_);
    }

    /// @notice delete existing pair
    /// @dev this can be only done after every account has removed liquidity or money may get stuck in contract
    /// @param lbPair_ liquidity book pair address
    function deleteLBPair(address lbPair_) external override onlyGuard{
        address lastLBPair;
        for (uint i = 0; i < allLBPairsAllowed.length; i++){
            if(allLBPairsAllowed[i] == lbPair_){
                lastLBPair = allLBPairsAllowed[allLBPairsAllowed.length - 1];
                allLBPairsAllowed[allLBPairsAllowed.length - 1] = allLBPairsAllowed[i];
                allLBPairsAllowed[i] = lastLBPair;
                allLBPairsAllowed.pop();
                LBPairsToApproval[lbPair_] = false;
                LBPairInfoMapping[lbPair_] = PairInfo(IERC20(address(0)), IERC20(address(0)), 0);
            }
        }
    }

    /// @notice add LiquidX stake pool to aggregator
    /// @dev stake pool need to be created first using stakePoolFactory.sol and then it can be added to aggregator.
    /// @param stakePool_ LiquidX stake pool address
    function addStakePool(address stakePool_) external override onlyGuard{
        address stakeToken = LiquidXStakePool(stakePool_).getStakeTokenAddress();
        if(poolToToken[stakeToken] != address(0)) revert LiquidXAggregator__StakePoolExists(poolToToken[stakeToken]);
        poolToToken[stakeToken] = stakePool_;
        allStakePools.push(stakePool_);
    }

    /// @notice this function performs as account factory
    /// but it need to be updated before deploying to mainnet owing to safety issue.
    /// The ILBRouterAddress_ cannot be manually set by user.
    /// @dev this function can be directly called by user
    /// @param manager_ user address
    /// @param ILBRouterAddress_ ILBRouter address(Liquidity book V2)
    function createManagerAccount(address manager_, address ILBRouterAddress_) external override {
        if (managerToAccount[manager_] != address(0)) revert LiquidXAggregator__AccountExists(managerToAccount[manager_]);
        bytes memory bytecode = type(ManagerAccount).creationCode;
        bytes32 salt = keccak256(abi.encode(manager_));
        address account;
        assembly{
                account := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        IManagerAccount(account).initializeAccount(accountsGuard, manager_, ILBRouterAddress_);
        managerToAccount[manager_] = account;
        accountToManager[account] = manager_;
        allManagerAccounts.push(account);
        // set bidirectional approval for transferring erc20 token
        address token;
        for(uint i = 0; i < allStakePools.length; i++){
            token = LiquidXStakePool(allStakePools[i]).getStakeTokenAddress();
            IManagerAccount(account).setERC20Approval(token);
        }
    }
    /// @notice borrow asset by account and update state variable
    /// @dev only called by manager account
    /// @param borrowToken_ address of which token that manager wants to borrow
    /// @param borrowAmount_ amount of token that manager wants to borrow
    function borrowFromAccount(address borrowToken_, uint256 borrowAmount_) external override onlyManagerAccount{
        LiquidXStakePool stakePool = LiquidXStakePool(poolToToken[borrowToken_]);
        if(address(stakePool) == address(0)) revert LiquidXAggregator__CorrespondingStakePoolNotCreated();
        uint256 maxLeverage = uint256(min32(getAccountLeverage(msg.sender), stakePool.getLeverageAllowedMax())); // 16 X 16 Fixed point number
        if(borrowAmount_ > managerMarginAvailable[msg.sender][borrowToken_].mulShiftRoundDown(maxLeverage, 16)) revert LiquidXAggregator__LeverageExceedsMaxAllowed();
        uint256 marginAmount = borrowAmount_.shiftDivRoundDown(16, maxLeverage);
        managerMarginAvailable[msg.sender][borrowToken_] -= marginAmount;
        managerMarginFrozen[msg.sender][borrowToken_] += marginAmount;
        managerBorrowedAssets[msg.sender][borrowToken_] += borrowAmount_;
        stakePool.borrowFromAggregator(msg.sender, borrowAmount_);
    }
    /// @notice repay from manager account
    /// @dev no partial repay.
    /// @param repayToken_ The token address that the manager plans to use to repay the debt.
    function repayFromAccount(address repayToken_) external override onlyManagerAccount{
        LiquidXStakePool stakePool = LiquidXStakePool(poolToToken[repayToken_]);
        IManagerAccount account = IManagerAccount(msg.sender);
        if(address(stakePool) == address(0)) revert LiquidXAggregator__CorrespondingStakePoolNotCreated();
        uint256 repayAmount;
        uint256 borrowedAmount = managerBorrowedAssets[msg.sender][repayToken_];
        if(account.getAccountBalanceAvailable(repayToken_) < borrowedAmount){
            account.updateFreezeState(true);
            repayAmount = account.getAccountBalanceAvailable(repayToken_);
            stakePool.repayFromAggregator(repayAmount);
            stakePool.liquidationValueChange(borrowedAmount - repayAmount, false);
            account.transferOut(address(stakePool), repayToken_, repayAmount);
        }else{
            repayAmount = borrowedAmount;
            stakePool.repayFromAggregator(repayAmount);
            managerMarginAvailable[msg.sender][repayToken_] = account.getAccountBalanceAvailable(repayToken_) - repayAmount;
            managerMarginFrozen[msg.sender][repayToken_] = 0;
            managerBorrowedAssets[msg.sender][repayToken_] = 0;
            account.transferOut(address(stakePool), repayToken_, repayAmount);
            if(account.getAccountFrozen() == true){
                managerMarginAvailable[msg.sender][repayToken_] = 0;
                stakePool.liquidationValueChange(account.getAccountBalanceAvailable(repayToken_), true);
                account.transferOut(address(stakePool), repayToken_, account.getAccountBalanceAvailable(repayToken_));
            }
        }
    }
    /// @notice collect fees and transfer partial fees to corresponding stake pools
    /// @dev this is automatically called whenever manager removes liquidity
    /// @param pairAddress_ LB pair address
    /// @param ids_ id array, same with liquidity book v2
    /// @param tokenX_ The address of the tokenX. Can't be address 0
    /// @param tokenY_ The address of the tokenY. Can't be address 0
    function collectFeesFromAccount(address pairAddress_, uint256[] calldata ids_, IERC20 tokenX_, IERC20 tokenY_) external override onlyManagerAccount {
        IERC20 tokenX = tokenX_;
        IERC20 tokenY = tokenY_;
        (uint256 amountX, uint256 amountY) = ManagerAccount(msg.sender).collectFees(pairAddress_, ids_, tokenX, tokenY);
        address poolX = poolToToken[address(tokenX)];
        address poolY = poolToToken[address(tokenY)];
        uint256 rewardsToPoolX = amountX * 2 / 10;
        uint256 rewardsToPoolY = amountY * 2 / 10;
        LiquidXStakePool(poolX).collectFeesFromAggregator(rewardsToPoolX);
        LiquidXStakePool(poolY).collectFeesFromAggregator(rewardsToPoolY);
        managerMarginAvailable[msg.sender][address(tokenX)] += (amountX - rewardsToPoolX);
        managerMarginAvailable[msg.sender][address(tokenY)] += (amountY - rewardsToPoolY);
        ManagerAccount(msg.sender).transferOut(poolX, address(tokenX), rewardsToPoolX);
        ManagerAccount(msg.sender).transferOut(poolY, address(tokenY), rewardsToPoolY);
    }

    function depositFromAccount(address from_, address token_, uint256 amountIn_) external override onlyManagerAccount{
        if(poolToToken[token_] == address(0)) revert LiquidXAggregator__CorrespondingStakePoolNotCreated();
        managerMarginAvailable[msg.sender][token_] += amountIn_;
        IManagerAccount(msg.sender).transferIn(from_, token_, amountIn_);
    }

    function withdrawFromAccount(address to_, address token_, uint256 amountOut_) external override onlyManagerAccount{
        if(poolToToken[token_] == address(0)) revert LiquidXAggregator__CorrespondingStakePoolNotCreated();
        IManagerAccount account = IManagerAccount(msg.sender);
        if(amountOut_ > managerMarginAvailable[msg.sender][token_] || amountOut_ > account.getAccountBalanceAvailable(token_)) revert LiquidXAggregator__WithdrawAmountExceedsMaxAllowed(token_, amountOut_);
        managerMarginAvailable[msg.sender][token_] -= amountOut_;
        account.transferOut(to_, token_, amountOut_);
    }

    function approveFromAccount(address token_) external override onlyManagerAccount{
        IERC20(token_).approve(msg.sender, type(uint256).max);
    }

    function min(uint256 a, uint256 b) internal pure returns(uint256){
        if(a < b) return a;
        else return b;
    }

    function min32(uint32 a, uint32 b) internal pure returns(uint32){
        if(a < b) return a;
        else return b;
    }
    /// @notice get account credit to turns it leverage
    /// @dev leverage is 16X16 fixed-point number
    function getAccountLeverage(address account_) internal returns(uint32 leverage){
        uint32 credit = uint32(IManagerAccount(account_).getCredit());
        leverage = credit * 10; //never overflow
        if(leverage > (10 << 16)) leverage = (10 << 16);
    }

    function getOwner() public view override returns(address){
        return owner;
    }

    function getGuard() public view override returns(address){
        return guard;
    }

    function getManagerAccountsLength() public view override returns(uint256){
        return allManagerAccounts.length;
    }

    function getManagerAccountByIndex(uint256 index_) public view override returns(address){
        return allManagerAccounts[index_];
    }

    function getStakePoolsLength() public view override returns(uint256){
        return allStakePools.length;
    }

    function getStakePoolByIndex(uint256 index_) public view override returns(address){
        return allStakePools[index_];
    }

    function getLBPairsAllowedLength() public view override returns(uint256){
        return allLBPairsAllowed.length;
    }

    function getLBPairAllowedByIndex(uint256 index_) public view override returns(address){
        return allLBPairsAllowed[index_];
    }

    function getAllLBPairsAllowed() external view override returns(address[] memory){
        return allLBPairsAllowed;
    }

    function getLBPairApprovalIf(address lbPair_) public override view returns(bool){
        return LBPairsToApproval[lbPair_];
    }

    function getAccount(address manager_) public override view returns(address){
        return managerToAccount[manager_];
    }

    function getStakePool(address token_) public override view returns(address){
        return poolToToken[token_];
    }

    function getLBPairInfoMapping(address pair_) public override view returns(IERC20,IERC20,uint256){
        return (LBPairInfoMapping[pair_].tokenX, LBPairInfoMapping[pair_].tokenY, LBPairInfoMapping[pair_].binStep);
    }

    function getLBPairInfoTokenX(address pair_) public view override returns(IERC20){
        return LBPairInfoMapping[pair_].tokenX;
    }

    function getLBPairInfoTokenY(address pair_) public view override returns(IERC20){
        return LBPairInfoMapping[pair_].tokenY;
    }

    function getLBPairInfoTokenBinStep(address pair_) public view override returns(uint256){
        return LBPairInfoMapping[pair_].binStep;
    }

    function getMarginAvailableByAsset(address manager_, address asset_) public view override returns(uint256){
        return managerMarginAvailable[manager_][asset_];
    }

    function getMarginFrozenByAsset(address manager_, address asset_) public view override returns(uint256){
        return managerMarginFrozen[manager_][asset_];
    }

    function getManagerBorrowedAmount(address account_, address asset_) public view override returns(uint256){
        return managerBorrowedAssets[account_][asset_];
    }

}
