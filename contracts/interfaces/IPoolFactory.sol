// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPoolFactory {
    event PoolCreated(address indexed addr, address indexed creator);

    function config() external view returns (address);
}
