// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/ILPMining.sol";

contract LockUpMining is Ownable, ReentrancyGuard, ILPMining {
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 pendingRewards;
        uint256 lastClaim;
    }

    struct PoolInfo {
        IERC20 lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accTokenPerShare;
        uint256 lockupDuration;
    }

    IERC20 public token;
    uint256 public tokenPerBlock;

    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    uint256 public totalAllocPoint = 0;
    uint256 public startBlock;

    mapping(address => bool) isLPPoolAdded;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Claim(address indexed user, uint256 indexed pid, uint256 amount);
    event RewardPerBlockChanged(uint256 reward);

    constructor(
        IERC20 _token,
        uint256 _tokenPerBlock,
        uint256 _startBlock
    ) public {
        require(address(_token) != address(0), "Invalid token address!");

        token = _token;
        tokenPerBlock = _tokenPerBlock;
        startBlock = _startBlock;

        emit RewardPerBlockChanged(_tokenPerBlock);
    }

    modifier validatePoolByPid(uint256 _pid) {
        require(_pid < poolInfo.length, "Pool does not exist");
        _;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to - (_from);
    }

    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        require(!isLPPoolAdded[address(_lpToken)], "There's already a pool with that LP token!");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint + (_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accTokenPerShare: 0,
                lockupDuration: 30 days
            })
        );

        isLPPoolAdded[address(_lpToken)] = true;
    }

    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner validatePoolByPid(_pid) {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint - (poolInfo[_pid].allocPoint) + (_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function pendingToken(uint256 _pid, address _user) external view validatePoolByPid(_pid) returns (uint256) {
        require(_user != address(0), "Invalid address!");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 tokenReward = (multiplier * (tokenPerBlock) * (pool.allocPoint)) / (totalAllocPoint);
            accTokenPerShare = accTokenPerShare + ((tokenReward * (1e12)) / (lpSupply));
        }
        return (user.amount * (accTokenPerShare)) / (1e12) - (user.rewardDebt) + (user.pendingRewards);
    }

    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public validatePoolByPid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 tokenReward = (multiplier * (tokenPerBlock) * (pool.allocPoint)) / (totalAllocPoint);
        pool.accTokenPerShare = pool.accTokenPerShare + ((tokenReward * (1e12)) / (lpSupply));
        pool.lastRewardBlock = block.number;
    }

    function deposit(
        uint256 _pid,
        uint256 _amount,
        bool _withdrawRewards
    ) public nonReentrant validatePoolByPid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = (user.amount * (pool.accTokenPerShare)) / (1e12) - (user.rewardDebt);

            if (pending > 0) {
                user.pendingRewards = user.pendingRewards + (pending);

                if (_withdrawRewards) {
                    safeTokenTransfer(msg.sender, user.pendingRewards);
                    emit Claim(msg.sender, _pid, user.pendingRewards);
                    user.pendingRewards = 0;
                }
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount + (_amount);
        }
        user.rewardDebt = (user.amount * (pool.accTokenPerShare)) / (1e12);
        user.lastClaim = block.timestamp;
        emit Deposit(msg.sender, _pid, _amount);
    }

    function withdraw(
        uint256 _pid,
        uint256 _amount,
        bool _withdrawRewards
    ) public nonReentrant validatePoolByPid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(block.timestamp > user.lastClaim + pool.lockupDuration, "You cannot withdraw yet!");

        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = (user.amount * (pool.accTokenPerShare)) / (1e12) - (user.rewardDebt);
        if (pending > 0) {
            user.pendingRewards = user.pendingRewards + (pending);

            if (_withdrawRewards) {
                safeTokenTransfer(msg.sender, user.pendingRewards);
                emit Claim(msg.sender, _pid, user.pendingRewards);
                user.pendingRewards = 0;
            }
        }
        if (_amount > 0) {
            user.amount = user.amount - (_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = (user.amount * (pool.accTokenPerShare)) / (1e12);
        user.lastClaim = block.timestamp;
        emit Withdraw(msg.sender, _pid, _amount);
    }

    function claim(uint256 _pid) public nonReentrant validatePoolByPid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        uint256 pending = (user.amount * (pool.accTokenPerShare)) / (1e12) - (user.rewardDebt);
        if (pending > 0 || user.pendingRewards > 0) {
            user.pendingRewards = user.pendingRewards + (pending);
            safeTokenTransfer(msg.sender, user.pendingRewards);
            emit Claim(msg.sender, _pid, user.pendingRewards);
            user.pendingRewards = 0;
            user.lastClaim = block.timestamp;
        }

        user.rewardDebt = (user.amount * (pool.accTokenPerShare)) / (1e12);
    }

    function safeTokenTransfer(address _to, uint256 _amount) internal {
        uint256 tokenBal = token.balanceOf(address(this));
        if (_amount > tokenBal) {
            token.transfer(_to, tokenBal);
        } else {
            token.transfer(_to, _amount);
        }
    }

    function setTokenPerBlock(uint256 _tokenPerBlock) public onlyOwner {
        require(_tokenPerBlock > 0, "!tokenPerBlock-0");
        tokenPerBlock = _tokenPerBlock;

        emit RewardPerBlockChanged(_tokenPerBlock);
    }

    function getDepositedAmount(address user) external view override returns (uint256) {
        uint256 amount = 0;
        for (uint256 index = 0; index < poolInfo.length; index++) {
            amount = amount + userInfo[index][user].amount;
        }
        return amount;
    }
}
