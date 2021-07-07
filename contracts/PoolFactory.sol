pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Pool.sol";
import "./interfaces/IPoolFactory.sol";

contract PoolFactory is Ownable, IPoolFactory {
    uint256 public poolsCount;
    address[] public pools;
    mapping(address => bool) public isPool;

    // usds for launch holder participants
    IERC20 public baseToken;
    uint256 public baseAmount;

    // fee
    address public feeRecipient;
    uint256 public feePercent; // 10: 1%, 15: 1.5%

    constructor(
        IERC20 _baseToken,
        uint256 _baseAmount,
        address _feeRecipient,
        uint256 _feePercent
    ) {
        baseToken = _baseToken;
        baseAmount = _baseAmount;
        feePercent = _feePercent;
        feeRecipient = _feeRecipient;
    }

    function updateFeeInfo(address _feeRecipient, uint256 _feePercent) external onlyOwner {
        feePercent = _feePercent;
        feeRecipient = _feeRecipient;
    }

    function updateBaseInfo(IERC20 _baseToken, uint256 _baseAmount) external onlyOwner {
        require(_baseAmount > 0, "BaseAmount should be greater than 0!");
        baseToken = _baseToken;
        baseAmount = _baseAmount;
    }

    function getFeeInfo() external view override returns (address, uint256) {
        return (feeRecipient, feePercent);
    }

    function getBaseInfo() external view override returns (IERC20, uint256) {
        return (baseToken, baseAmount);
    }

    /*
     * @param saleToken          Address of Sale Token
     * @param saleTokenTarget    Amount of Sale Token to sell
     * @param fundToken          Address of fundToken: 0x000.000: KuCoin, Other KRC20
     */
    function createPool(
        IERC20 saleToken,
        uint256 saleTarget,
        address fundToken,
        uint256 fundTarget,
        uint256 startTime,
        uint256 endTime,
        uint256 claimTime,
        uint256 allocationRatio,
        string memory meta
    ) external returns (address) {
        Pool pool = new Pool(address(this), saleToken, saleTarget, fundToken, fundTarget);

        pool.setBaseData(startTime, endTime, claimTime, allocationRatio, meta);

        pools.push(address(pool));
        isPool[address(pool)] = true;

        pool.transferOwnership(msg.sender);

        poolsCount = poolsCount + 1;

        emit PoolCreated(address(pool), msg.sender);

        return address(pool);
    }
}
