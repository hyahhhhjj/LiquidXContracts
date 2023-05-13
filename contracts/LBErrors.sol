// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/** Math512Bits errors */

error Math512Bits__MulDivOverflow(uint256 prod1, uint256 denominator);
error Math512Bits__OffsetOverflows(uint256 offset);
error Math512Bits__MulShiftOverflow(uint256 prod1, uint256 offset);

/** LowLevelCall errors */

error LowLevelCall__NonContract();
error LowLevelCall__CallFailed();
