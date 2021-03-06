// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IPoolFactory.sol";
import "./interfaces/IKCCConfig.sol";

contract Pool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct User {
        uint256 totalFunded; // total funded amount of user
        uint256 totalSaleToken; // total sale token amount to receive
        uint256 released; // currently released token amount
    }

    IPoolFactory public factory;

    IERC20 public saleToken;
    uint256 public saleTarget;
    uint256 public saleRaised;

    // 0x0000...000 KuCoin, other: KRC20
    address public fundToken;
    uint256 public fundTarget;
    uint256 public fundRaised;

    // min allocation per wallet = allocationRatio * teamToken.balanceOf(user)
    // 2ether => 2
    uint256 public allocationRatio;
    uint256 public maxAllocation;

    uint256 public startTime;
    uint256 public endTime;
    uint256 public claimTime;

    string public meta;

    mapping(address => User) public funders;
    address[] public funderAddresses;

    // vesting info
    uint256 public cliffTime;
    // 15 = 1.5%, 1000 = 100%
    uint256 public distributePercentAtClaim;
    uint256 public vestingDuration;
    uint256 public vestingPeriodicity;

    event PoolInitialized(uint256 saleTarget, address fundToken, uint256 fundTarget);

    event PoolBaseDataChanged(
        uint256 startTime,
        uint256 endTime,
        uint256 claimTime,
        uint256 maxAllocation,
        uint256 allocationRatio,
        string meta
    );

    event PoolTokenInfoChanged(uint256 saleTarget, uint256 fundTarget);

    event SaleTokenAddressSet(address saleToken);

    event VestingSet(
        uint256 cliffTime,
        uint256 distributePercentAtClaim,
        uint256 vestingDuration,
        uint256 vestingPeriodicity
    );

    event PoolProgressChanged(address buyer, uint256 amount, uint256 fundRaised, uint256 saleRaised);

    event PoolClaimed(address to, uint256 amount);

    constructor(
        IPoolFactory _factory,
        uint256 _saleTarget,
        address _fundToken,
        uint256 _fundTarget
    ) {
        require(address(_factory) != address(0), "Invalid factory address");
        require(_saleTarget > 0, "Sale Token target can't be zero!");
        require(_fundToken != address(0), "Invalid FundToken address");
        require(_fundTarget > 0, "Fund Token target can't be zero!");

        saleTarget = _saleTarget;

        fundToken = _fundToken;
        fundTarget = _fundTarget;

        factory = _factory;

        emit PoolInitialized(saleTarget, fundToken, fundTarget);
    }

    function setBaseData(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _claimTime,
        uint256 _maxAllocation,
        uint256 _allocationRatio,
        string memory _meta
    ) external onlyOwner {
        require(_allocationRatio > 0, "AllocationRatio can't be zero!");
        require(_maxAllocation > 0, "MaxAllocation can't be zero!");

        require(startTime > block.timestamp, "You can't set past time!");
        require(startTime < endTime, "EndTime can't be earlier than startTime");
        require(endTime < claimTime, "ClaimTime can't be earlier than endTime");

        uint256 minAmount = getMinAllocation();
        require(_maxAllocation > minAmount, "MaxAllocation should be greater than min allocation");

        startTime = _startTime;
        endTime = _endTime;
        claimTime = _claimTime;
        maxAllocation = _maxAllocation;
        allocationRatio = _allocationRatio;
        meta = _meta;

        emit PoolBaseDataChanged(startTime, endTime, claimTime, maxAllocation, allocationRatio, meta);
    }

    function getFeeInfo() private view returns (address, uint256) {
        IKCCConfig config = IKCCConfig(factory.config());
        return (config.feeRecipient(), config.feePercent());
    }

    function canParticate(address user) public view returns (bool) {
        IKCCConfig config = IKCCConfig(factory.config());
        uint256 total = config.getAllInToken(user);

        if (total >= config.baseAmount()) {
            return true;
        }
        return false;
    }

    function getMinAllocation() public view returns (uint256) {
        IKCCConfig config = IKCCConfig(factory.config());
        return config.baseAmount() * allocationRatio;
    }

    function getMaxAllocation(address user) public view returns (uint256) {
        IKCCConfig config = IKCCConfig(factory.config());
        uint256 total = config.getAllInToken(user);

        require(total >= config.baseAmount(), "You don't have enough 1STEP");

        if (total * allocationRatio > maxAllocation) {
            return maxAllocation;
        }
        return total * allocationRatio;
    }

    function setStartTime(uint256 _startTime) external onlyOwner {
        require(startTime > block.timestamp, "You can't change startTime");

        startTime = _startTime;

        emit PoolBaseDataChanged(startTime, endTime, claimTime, maxAllocation, allocationRatio, meta);
    }

    function setEndTime(uint256 _endTime) external onlyOwner {
        require(_endTime > block.timestamp, "You can't change endTime");
        require(_endTime > startTime, "EndTime should be greater than startTime");

        endTime = _endTime;

        emit PoolBaseDataChanged(startTime, endTime, claimTime, maxAllocation, allocationRatio, meta);
    }

    function setClaimTime(uint256 _claimTime) external onlyOwner {
        require(_claimTime > block.timestamp, "You can't change claimTime");
        require(_claimTime > endTime, "Claim Time should be greater than endTime");

        claimTime = _claimTime;

        emit PoolBaseDataChanged(startTime, endTime, claimTime, maxAllocation, allocationRatio, meta);
    }

    function setMeta(string memory _meta) external onlyOwner {
        meta = _meta;

        emit PoolBaseDataChanged(startTime, endTime, claimTime, maxAllocation, allocationRatio, meta);
    }

    function setSaleToken(IERC20 _saleToken) external onlyOwner {
        require(address(_saleToken) != address(0), "Invalid SaleToken!");
        require(address(saleToken) == address(0), "SaleToken is already set!");

        saleToken = _saleToken;
        emit SaleTokenAddressSet(address(saleToken));
    }

    function setAllocationRatio(uint256 _allocationRatio) external onlyOwner {
        require(block.timestamp > startTime, "IDO is already started!");
        require(_allocationRatio > 0, "Allocation Ratio can't be zero!");

        allocationRatio = _allocationRatio;

        emit PoolBaseDataChanged(startTime, endTime, claimTime, maxAllocation, allocationRatio, meta);
    }

    function setMaxAllocation(uint256 _maxAllocation) external onlyOwner {
        require(_maxAllocation > 0, "Max Allocation can't be zero!");
        uint256 minAmount = getMinAllocation();
        require(_maxAllocation > minAmount, "MaxAllocation should be greater than min allocation");

        maxAllocation = _maxAllocation;

        emit PoolBaseDataChanged(startTime, endTime, claimTime, maxAllocation, allocationRatio, meta);
    }

    function setSaleTarget(uint256 _saleTarget) external onlyOwner {
        require(_saleTarget > 0, "Sale Token target can't be zero!");
        saleTarget = _saleTarget;
        emit PoolTokenInfoChanged(saleTarget, fundTarget);
    }

    function setFundTarget(uint256 _fundTarget) external onlyOwner {
        require(_fundTarget > 0, "Fund Token target can't be zero!");
        fundTarget = _fundTarget;
        emit PoolTokenInfoChanged(saleTarget, fundTarget);
    }

    function setVestingInfo(
        uint256 _cliffTime,
        uint256 _distributePercentAtClaim,
        uint256 _vestingDuration,
        uint256 _vestingPeriodicity
    ) external onlyOwner {
        require(_cliffTime > block.timestamp, "CliffTime should be greater than now");
        require(_distributePercentAtClaim <= 1000, "DistributePcercentAtClaim should be less than 1000");
        require(_vestingDuration > 0, "Vesting Duration should be greater than 0");
        require(_vestingPeriodicity > 0, "Vesting Periodicity should be greater than 0");
        require(
            (_vestingDuration - (_vestingDuration / _vestingPeriodicity) * _vestingPeriodicity) == 0,
            "Vesting Duration should be divided by vestingPeriodicity fully!"
        );

        cliffTime = _cliffTime;
        distributePercentAtClaim = _distributePercentAtClaim;
        vestingDuration = _vestingDuration;
        vestingPeriodicity = _vestingPeriodicity;

        emit VestingSet(cliffTime, distributePercentAtClaim, vestingDuration, vestingPeriodicity);
    }

    function withdrawRemainingToken() external onlyOwner {
        require(block.timestamp > endTime, "Pool has not yet ended");
        saleToken.transfer(msg.sender, saleToken.balanceOf(address(this)) - fundRaised);
    }

    function withdrawFundedKuc(address payable to) external payable onlyOwner {
        require(block.timestamp > endTime, "Pool has not yet ended");
        require(fundToken == address(0), "It's not Kuc-buy pool!");

        uint256 balance = address(this).balance;

        (address feeRecipient, uint256 feePercent) = getFeeInfo();

        uint256 fee = (balance * (feePercent)) / (1000);
        uint256 restAmount = balance - (fee);

        payable(feeRecipient).transfer(fee);
        payable(to).transfer(restAmount);
    }

    function withdrawFundedToken(address payable to) external onlyOwner {
        require(block.timestamp > endTime, "Pool has not yet ended");
        require(fundToken != address(0), "It's not token-buy pool!");

        uint256 balance = IERC20(fundToken).balanceOf(address(this));

        (address feeRecipient, uint256 feePercent) = getFeeInfo();

        uint256 fee = (balance * feePercent) / 1000;
        uint256 restAmount = balance - fee;

        IERC20(fundToken).transfer(feeRecipient, fee);
        IERC20(fundToken).transfer(to, restAmount);
    }

    function getClaimableAmount(address addr) public view returns (uint256) {
        require(addr != address(0), "Invalid address!");

        if (block.timestamp < claimTime) return 0;

        uint256 distributeAmountAtClaim = (funders[addr].totalSaleToken * distributePercentAtClaim) / 1000;
        uint256 prevReleased = funders[addr].released;
        if (cliffTime > block.timestamp) {
            return distributeAmountAtClaim - prevReleased;
        }

        uint256 finalTime = cliffTime + vestingDuration - vestingPeriodicity;

        if (block.timestamp >= finalTime) {
            return funders[addr].totalSaleToken - prevReleased;
        }

        uint256 lockedAmount = funders[addr].totalSaleToken - distributeAmountAtClaim;

        uint256 totalPeridicities = vestingDuration / vestingPeriodicity;
        uint256 periodicityAmount = lockedAmount / totalPeridicities;
        uint256 currentperiodicityCount = (block.timestamp - cliffTime) / vestingPeriodicity + 1;
        uint256 availableAmount = periodicityAmount * currentperiodicityCount;

        return distributeAmountAtClaim + availableAmount - prevReleased;
    }

    function _claimTo(address to) private nonReentrant {
        require(to != address(0), "Invalid address");
        uint256 claimableAmount = getClaimableAmount(to);
        if (claimableAmount > 0) {
            funders[to].released = funders[to].released + claimableAmount;
            saleToken.transfer(to, claimableAmount);
            emit PoolClaimed(to, claimableAmount);
        }
    }

    function claim() external {
        require(block.timestamp > claimTime, "claiming not allowed yet");
        uint256 claimableAmount = getClaimableAmount(msg.sender);
        require(claimableAmount > 0, "Nothing to claim");
        _claimTo(msg.sender);
    }

    function batchClaim(address[] calldata addrs) external {
        for (uint256 index = 0; index < addrs.length; index++) {
            _claimTo(addrs[index]);
        }
    }

    modifier checkBeforeBuy(address addr, uint256 amount) {
        require(startTime != 0 && block.timestamp > startTime, "Pool has not yet started");
        require(endTime != 0 && block.timestamp < endTime, "Pool already ended");

        uint256 max = getMaxAllocation(addr);
        uint256 min = getMinAllocation();

        require(amount > 0, "Amount should be great than zero");

        require(fundRaised + amount <= fundTarget, "Target hit!");

        uint256 personalTotal = amount + funders[addr].totalFunded;

        require(personalTotal >= min, "Amount is too small");

        require(personalTotal <= max, "Amount is too big");

        _;
    }

    function buyWithKuc() public payable checkBeforeBuy(msg.sender, msg.value) {
        require(fundToken == address(0), "It's not Kuc-buy pool!");

        uint256 amount = msg.value;
        uint256 saleTokenAmount = (msg.value * saleTarget) / fundTarget;

        fundRaised = fundRaised + amount;
        saleRaised = saleRaised + saleTokenAmount;

        if (funders[msg.sender].totalFunded == 0) {
            funderAddresses.push(msg.sender);
        }

        funders[msg.sender].totalFunded = funders[msg.sender].totalFunded + amount;
        funders[msg.sender].totalSaleToken = funders[msg.sender].totalSaleToken + saleTokenAmount;

        emit PoolProgressChanged(msg.sender, amount, fundRaised, saleRaised);
    }

    function buy(uint256 amount) public checkBeforeBuy(msg.sender, amount) {
        uint256 saleTokenAmount = (amount * saleTarget) / fundTarget;
        fundRaised = fundRaised + amount;
        saleRaised = saleRaised + saleTokenAmount;

        if (funders[msg.sender].totalFunded == 0) {
            funderAddresses.push(msg.sender);
        }

        funders[msg.sender].totalFunded = funders[msg.sender].totalFunded + amount;
        funders[msg.sender].totalSaleToken = funders[msg.sender].totalSaleToken + saleTokenAmount;

        IERC20(fundToken).transferFrom(msg.sender, address(this), amount);

        emit PoolProgressChanged(msg.sender, amount, fundRaised, saleRaised);
    }

    fallback() external payable {
        revert("Something went wrong!");
    }

    receive() external payable {
        require(fundToken == address(0), "It's not a KUC-buy IDO!");
        buyWithKuc();
    }
}
