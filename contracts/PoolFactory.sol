// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Pool.sol";
import "./interfaces/IPoolFactory.sol";
import "./interfaces/IKCCConfig.sol";

contract PoolFactory is Ownable, IPoolFactory {
    uint256 public poolsCount;
    address[] public pools;
    mapping(address => bool) public isPool;

    address public override config;

    constructor(IKCCConfig _config) {
        require(address(_config) != address(0), "Invalid config address");

        config = address(_config);
    }

    function setConfigAddress(IKCCConfig _config) external onlyOwner {
        require(address(_config) != address(0), "Invalid config address");
        config = address(_config);
    }

    /*
     * @param saleToken          Address of Sale Token
     * @param saleTokenTarget    Amount of Sale Token to sell
     * @param fundToken          Address of fundToken: 0x000.000: KuCoin, Other KRC20
     */
    function createPool(
        uint256 saleTarget,
        address fundToken,
        uint256 fundTarget,
        uint256 startTime,
        uint256 endTime,
        uint256 claimTime,
        uint256 maxAllocation,
        uint256 allocationRatio,
        string memory meta
    ) external returns (address) {
        Pool pool = new Pool(this, saleTarget, fundToken, fundTarget);

        pool.setBaseData(startTime, endTime, claimTime, maxAllocation, allocationRatio, meta);

        pools.push(address(pool));
        isPool[address(pool)] = true;

        pool.transferOwnership(msg.sender);

        poolsCount = poolsCount + 1;

        emit PoolCreated(address(pool), msg.sender);

        return address(pool);
    }
}
