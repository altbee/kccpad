// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IKCCConfig {
    function getAllInToken(address user) external view returns (uint256);

    function feeRecipient() external view returns (address);

    function feePercent() external view returns (uint256);

    function baseToken() external view returns (address);

    function baseAmount() external view returns (uint256);
}
