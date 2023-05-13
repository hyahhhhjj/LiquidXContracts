// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './library/Math512Bits.sol';
import './library/LowLevelCallHelper.sol';

import './interfaces/ILiquidXAggregator.sol';
import './interfaces/IManagerAccount.sol';


/// @title LiquidX Protocol Accounts Guard
/// @author Yuang Huang
/// @notice Contract used to check manager assets and force liquidation if assets condition is not healthy.
/// It need to be deployed before LiquidXAggregator
contract AccountsGuard {

    using Math512Bits for uint256;
    using LowLevelCallHelper for address;

    address private owner;
    address private guard;

    ILiquidXAggregator private aggregator;

    mapping(address => uint256) private virtualBalance; /// convert lb token to erc20 token

    constructor() public {
        owner = msg.sender;
        guard = msg.sender;
    }

    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    modifier onlyGuard(){
        require(msg.sender == guard);
        _;
    }

    function updateGuard(address guard_) external onlyOwner{
        guard = guard_;
    }
    /// @notice set the LiquidXAggregator address for AccountsGuard
    /// @dev Needs to be called by the owner
    function updateAggregator(address aggregator_) external onlyOwner{
        aggregator = ILiquidXAggregator(aggregator);
    }
    /// @notice check the assets condition of single manager account and execute liquidation
    /// @dev only called by accounts guard
    /// @param account_ the address of account
    /// @param checkTokenArray_ the address array of tokens need to be checked
    function healthCheck(IManagerAccount account_, address[] calldata checkTokenArray_) external onlyGuard{
        for (uint i = 0; i < aggregator.getLBPairsAllowedLength(); i++) {
            address pairAddress = aggregator.getLBPairAllowedByIndex(i);
            IERC20 tokenX = aggregator.getLBPairInfoTokenX(pairAddress);
            IERC20 tokenY = aggregator.getLBPairInfoTokenY(pairAddress);
            /// should be replaced by ILBPair interface
            bytes memory data = abi.encodeWithSignature("getReservesAndId()");
            bytes memory results = pairAddress._callAndCatchError(data);
            (,, uint256 activeId) = abi.decode(results, (uint256, uint256, uint256));

            for (uint256 j = 0; j < account_.getMMLBPairToIdSetLength(pairAddress); j++) {
                uint256 id = account_.getMMLBPairToIdSetAtValue(pairAddress, j);
                /// based on liquidity book mechanism, id < active, reserves in Y token, id > active, reserves in X token,  id = active, reserves in combination, satisfying P * X + Y = L
                if (id < activeId) virtualBalance[address(tokenY)] += account_.getMMLBPairToIdToAmount(pairAddress, id);
                else if (id > activeId) virtualBalance[address(tokenX)] += account_.getMMLBPairToIdToAmount(pairAddress, id);
                else {
                    data = abi.encodeWithSignature("getBin(uint24)", uint24(id));
                    results = pairAddress._callAndCatchError(data);
                    (uint256 activeBinReserveX, uint256 activeBinReserveY) = abi.decode(results, (uint256, uint256));

                    data = abi.encodeWithSignature("totalSupply(uint256)", id);
                    results = pairAddress._callAndCatchError(data);
                    uint256 totalSupply = abi.decode(results, (uint256));

                    uint256 lbtAmount = account_.getMMLBPairToIdToAmount(pairAddress, id);
                    virtualBalance[address(tokenY)] += lbtAmount.mulDivRoundDown(activeBinReserveY, totalSupply);
                    virtualBalance[address(tokenX)] += lbtAmount.mulDivRoundDown(activeBinReserveX, totalSupply);
                }
            }
        }
        /// check if this account is capital adequate
        /// using safe math to make sure debt <= 2^248, ratio <= 2^8
        bool repayIf = false;
        for(uint i = 0; i < checkTokenArray_.length; i++){
            address token = checkTokenArray_[i];
            if (virtualBalance[token] + account_.getAccountBalanceAvailable(token) < aggregator.getManagerBorrowedAmount(address(account_), token) * 105 / 100){
                repayIf = true;
            }
            virtualBalance[checkTokenArray_[i]] = 0;
        }

        if(repayIf){
            forceRemoveLiquidity(account_);
            repayAll(account_,checkTokenArray_);
        }
    }
    /// @notice internal function to force specific account remove liquidity
    /// @param account_ the address of account
    function forceRemoveLiquidity(IManagerAccount account_) internal {
        for(uint256 i = 0; i < aggregator.getLBPairsAllowedLength(); i++){
            uint256 deadline = block.timestamp + 60 * 60 * 24; /// deadline should not be close to current timestamp
            /// bytes32[] to uint256[] conversion
            address pairAddress = aggregator.getLBPairAllowedByIndex(i);
            uint256 idLength = account_.getMMLBPairToIdSetLength(pairAddress);
            uint256[] memory ids = new uint256[](idLength); // 20230501update:dynamic sized array not work in function
            uint256[] memory amounts = new uint256[](idLength);
            uint256 id;
            for (uint j = 0; j < idLength; j++){
                id = account_.getMMLBPairToIdSetAtValue(pairAddress, j);
                ids[j] = id;
                amounts[j] = account_.getMMLBPairToIdToAmount(pairAddress, id);
            }
            account_.removeLiquidity(aggregator.getLBPairAllowedByIndex(i), ids, amounts, deadline);
        }
    }
    /// @notice internal function to force account repay debts on specific assets
    /// @param account_ the address of account
    /// @param repayTokenArray_ the address array of tokens need to repay
    function repayAll(IManagerAccount account_, address[] calldata repayTokenArray_) internal {
        for (uint i = 0; i < repayTokenArray_.length; i++){
            account_.repay(repayTokenArray_[i]);
        }
    }

}
