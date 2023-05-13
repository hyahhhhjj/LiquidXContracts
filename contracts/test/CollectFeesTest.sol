pragma solidity ^0.8.0;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '../library/LowLevelCallHelper.sol';

contract CollectFeesTest {
    using LowLevelCallHelper for address;
    uint256 private amountXStorage;

    uint256 private amountYStorage;

    function collectFees(address pairAddress_, uint256[] calldata ids_, IERC20 tokenX_, IERC20 tokenY_) external returns(uint256 amountX, uint256 amountY){
        bytes memory data = abi.encodeWithSignature("collectFees(address,uint256[])", address(this), ids_);
        bytes memory results = pairAddress_._callAndCatchError(data);
        (amountX, amountY) = abi.decode(results, (uint256, uint256));
        amountXStorage += amountX;
        amountYStorage += amountY;
    }

    function getAmountXStorage() public view returns(uint256){
        return amountXStorage;
    }

    function getAmountYStorage() public view returns(uint256){
        return amountYStorage;
    }
}
