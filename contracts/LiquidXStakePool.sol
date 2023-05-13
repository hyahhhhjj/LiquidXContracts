// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import './ERC20.sol';
import './LiquidXErrors.sol';
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import './library/Math512Bits.sol';


/// @title LiquidX Protocol Stake Pool
/// @author Yuang Huang
/// @notice this contract is the implementation of LiquidXStakePool that also acts as the receipt token for minted shares
contract LiquidXStakePool is ERC20, ReentrancyGuard{
    using Math512Bits for uint256;
    address private liquidxAggregator; // this is the same as liquidxAggregator
    address private factory;
    IERC20 private stakeToken;
    uint32 private leverageAllowedMax; // 16X16 Fixed-point number.
    uint256 private totalReserve;
    uint256 private extractableReserve;

    event ShareMinted(address to_, uint256 amount_);

    modifier onlyLiquidXAggregator(){
        require(msg.sender == liquidxAggregator);
        _;
    }

    modifier onlyFactory(){
        require(msg.sender == factory);
        _;
    }

    /// @notice update reserve state before withdraw or stake happened
    modifier updateReserve(uint256 amount_, bool increment_){
        if(increment_){
            totalReserve += amount_;
            extractableReserve += amount_;
        }
        else{
            require(amount_ < extractableReserve);
            totalReserve -= amount_;
            extractableReserve -= amount_;
        }
        _;
    }
    /// @notice update only extractable state before withdraw or stake happened
    modifier updateOnlyExtractable(uint256 amount_, bool increment_){
        if(increment_){
            extractableReserve += amount_;
        }
        else{
            require(amount_ < extractableReserve);
            extractableReserve -= amount_;
        }
        _;
    }

    constructor() public {
        factory = msg.sender;
    }

    /// @dev using create2 to instantiate contract LiquidXStakePool and then call this function to initialize the contract.
    /// params
    /// - name_: the name of pool share token corresponding to the token as assets staked in the pool.
    /// - symbol_: abbreviation of 'name_'
    /// - stakeToken_: address of token as assets staked in the pool.
    /// - leverageAllowedMax_: max allowed leverage to use for Aggregator to borrow money on behalf of managers;
    function initializeStakePool(string memory name_, string memory symbol_, IERC20 stakeToken_, uint32 leverageAllowedMax_, address liquidxAggregator_) external onlyFactory {
        initializeERC20(name_, symbol_);
        stakeToken = stakeToken_;
        leverageAllowedMax = leverageAllowedMax_;
        liquidxAggregator = liquidxAggregator_;
    }

    /// @notice update reserve state after withdraw or stake happened
    /// @dev internal function
    /// @param amount_ amount of tokens that are in or out
    /// @param increment_ true for plus, false for minus
    function updateReserveAfter(uint256 amount_, bool increment_) internal {
        if(increment_){
            totalReserve += amount_;
            extractableReserve += amount_;
        }
        else{
            require(amount_ < extractableReserve);
            totalReserve -= amount_;
            extractableReserve -= amount_;
        }
    }
    /// @notice stake assets and get corresponding pool share token
    /// @dev transfer in native token in exchange of lx version of that token
    /// @param amountIn_ the amount of native token user transfer in
    /// @return shareMinted the amount of lx version token that contract minted
    function mintShare(uint256 amountIn_) external nonReentrant returns(uint256 shareMinted){
        stakeToken.transferFrom(msg.sender, address(this), amountIn_);
        if(totalSupply() > 0){
            ///shareMinted = amountIn_ * totalSupply() / totalReserve;
            shareMinted = amountIn_.mulDivRoundDown(totalSupply(), totalReserve);
        }else{
            shareMinted = amountIn_;
        }
        updateReserveAfter(amountIn_, true);
        _mint(msg.sender, shareMinted);
    }
    /// @notice burn minted lx version token in exchange of native token
    /// @param amountOut_ the amount of native token user will receive
    /// @return shareBurned the amount of lx version token has been burned
    function burnShare(uint256 amountOut_) external nonReentrant returns(uint256 shareBurned){
        if(totalSupply() > 0){
            ///shareBurned = amountOut_ * totalSupply() / totalReserve;
            shareBurned = amountOut_.mulDivRoundDown(totalSupply(), totalReserve);
            updateReserveAfter(amountOut_, false);
            _burn(msg.sender, shareBurned);
            stakeToken.transfer(msg.sender, amountOut_);
        }
        else{
            revert LiquidXStakePool__PoolNotEstablished();
        }
    }

    function borrowFromAggregator(address to_, uint256 amountOut_) external onlyLiquidXAggregator updateOnlyExtractable(amountOut_, false) nonReentrant {
        stakeToken.transfer(to_, amountOut_);
    }

    function repayFromAggregator(uint256 amountIn_) external onlyLiquidXAggregator updateOnlyExtractable(amountIn_, true) nonReentrant{
        /// Aggregator need transfer first, then update reserve
    }

    function collectFeesFromAggregator(uint256 amountIn_) external onlyLiquidXAggregator updateReserve(amountIn_, true) nonReentrant {
        /// Aggregator need transfer first, then update reserve
    }

    function liquidationValueChange(uint256 amount_, bool increment_) external onlyLiquidXAggregator nonReentrant{
        if(increment_) totalReserve += amount_;
        else totalReserve -= amount_;
    }

    function getLiquidXAggregator() public view returns(address){
        return liquidxAggregator;
    }

    function getStakeTokenAddress() public view returns(address){
        return address(stakeToken);
    }

    function getLeverageAllowedMax() public view returns(uint32){
        return leverageAllowedMax;
    }

    function getTotalReserve() public view returns(uint256){
        return totalReserve;
    }

    function getExtractableReserve() public view returns(uint256){
        return extractableReserve;
    }
}
