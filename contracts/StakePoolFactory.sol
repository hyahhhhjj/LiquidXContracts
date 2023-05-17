// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './LiquidXStakePool.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/// @title LiquidX Stake Pool Factory
/// @author LiquidX Protocol
contract StakePoolFactory {

    address private owner; // creator of this contract
    address private guard; // ultimate controller of this contract
    address private liquidxAggregator;

    address[] private stakePools;

    constructor(address aggregator_) public{
        owner = msg.sender;
        guard = msg.sender;
        liquidxAggregator = aggregator_;
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
    /// @notice performs as a stake pool factory
    /// @dev only called by guard
    /// @param name_ name of share token, this is set as "lx-XXX" by default. If the native token is "USDT", then the share token is "lx-USDT"
    /// @param symbol_ symbol of share token
    /// @param stakeToken_ native token address
    /// @param leverageAllowedMax_ max allowed leverage. This is a 16X16 fixed-point number. By default it's 1048576, which is 16X leverage
    function addStakePool(string memory name_, string memory symbol_, IERC20 stakeToken_, uint32 leverageAllowedMax_) external onlyGuard{
        bytes memory bytecode = type(LiquidXStakePool).creationCode;
        bytes32 salt = keccak256(abi.encode(address(stakeToken_)));
        address stakePool;
        assembly{
            stakePool := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        LiquidXStakePool(stakePool).initializeStakePool(name_, symbol_, stakeToken_, leverageAllowedMax_, liquidxAggregator);
        stakePools.push(stakePool);
    }

    function getStakePoolsLength() public view returns(uint256){
        return stakePools.length;
    }

    function getStakePoolByIndex(uint256 index_) public view returns(address){
        return stakePools[index_];
    }

}
