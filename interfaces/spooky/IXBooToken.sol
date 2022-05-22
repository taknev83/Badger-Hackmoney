// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

interface IXBooToken {
    function enter(uint256 _amount) external;

    function BOOBalance(address _account) external view returns (uint256 booAmount_);

    function xBOOForBOO(uint256 _xBOOAmount) external view returns (uint256 booAmount_);

    function BOOForxBOO(uint256 _booAmount) external view returns (uint256 xBOOAmount_);

    function leave(uint256 _share) external;
}
