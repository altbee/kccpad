// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenLocker is Ownable, ReentrancyGuard {
    using Address for address;

    struct LockInfo {
        IERC20 token;
        address beneficiary;
        uint256 duration;
        uint256 periodicity;
        uint256 amount;
        uint256 cliffTime;
        uint256 released;
    }

    event TokenLocked(
        address beneficiary,
        uint256 duration,
        uint256 periodicity,
        uint256 amount,
        uint256 cliffTime,
        uint256 lockId
    );

    event TokenReleased(address token, address beneficiary, uint256 amount, uint256 lockId);

    uint256 public lockCount;
    LockInfo[] public lockInfos;
    mapping(address => uint256[]) public lockIds;

    modifier validateLockId(uint256 lockId) {
        require(lockId < lockInfos.length, "Invalid lockId");
        _;
    }

    /**
     * get available amount of a certain lock
     */
    function getAvailableAmount(uint256 lockId) public view validateLockId(lockId) returns (uint256) {
        uint256 amount = lockInfos[lockId].amount;
        uint256 periodicity = lockInfos[lockId].periodicity;
        uint256 cliffTime = lockInfos[lockId].cliffTime;
        uint256 duration = lockInfos[lockId].duration;
        uint256 released = lockInfos[lockId].released;
        uint256 finalTime = cliffTime + (duration) - (periodicity);
        if (finalTime < block.timestamp) {
            return amount - (released);
        } else if (cliffTime > block.timestamp) {
            return uint256(0);
        } else {
            uint256 totalPeridicities = duration / (periodicity);
            uint256 periodicityAmount = amount / (totalPeridicities);
            uint256 currentperiodicityCount = (block.timestamp - cliffTime) / (periodicity) + (1);
            uint256 availableAmount = periodicityAmount * (currentperiodicityCount);
            return availableAmount - (released);
        }
    }

    function getLockIds(address beneficiary) external view returns (uint256[] memory) {
        require(beneficiary != address(0), "Invalid address!");
        return lockIds[beneficiary];
    }

    function _releaseFromLockId(uint256 lockId, address beneficiary) private nonReentrant {
        require(lockInfos.length > lockId, "Invalid lockId");
        require(beneficiary != address(0), "Invalid beneficiary address");

        uint256 available = getAvailableAmount(lockId);

        if (available > 0) {
            lockInfos[lockId].released = lockInfos[lockId].released + available;
            lockInfos[lockId].token.transfer(beneficiary, available);
            emit TokenReleased(address(lockInfos[lockId].token), beneficiary, available, lockId);
        }
    }

    function releaseFromLockId(uint256 lockId) external {
        _releaseFromLockId(lockId, msg.sender);
    }

    function releaseToBeneficiaryFromLockId(uint256 lockId, address beneficiary) external {
        _releaseFromLockId(lockId, beneficiary);
    }

    function _releaseAllAvailableTokens(address beneficiary) private returns (uint256) {
        uint256 available = uint256(0);
        uint256 length = lockIds[beneficiary].length;
        require(length > 0, "You don't have any locked token to release");
        for (uint256 index = 0; index < length; ++index) {
            uint256 lockId = lockIds[beneficiary][index];
            uint256 subAvailable = getAvailableAmount(lockId);
            if (subAvailable > 0) {
                
                available = available + (subAvailable);
                lockInfos[lockId].released = lockInfos[lockId].released + (subAvailable);
                lockInfos[lockId].token.transfer(beneficiary, subAvailable);
                emit TokenReleased(address(lockInfos[lockId].token), beneficiary, subAvailable, lockId);
            }
        }
        return available;
    }

    function releaseAllAvailableTokens() external nonReentrant {
        uint256 releasedAmount = _releaseAllAvailableTokens(msg.sender);
        require(releasedAmount > 0, "You don't have any releasable amount yet");
    }

    function releaseAllAvailableTokensToBeneficiary(address beneficiary) external nonReentrant onlyOwner {
        require(beneficiary != address(0), "Beneficiary can't be zero address");
        _releaseAllAvailableTokens(beneficiary);
    }

    function batchReleaseAllAvailableTokensToBeneficiaries(address[] calldata beneficiaries)
        external
        nonReentrant
        onlyOwner
    {
        uint256 total = beneficiaries.length;

        for (uint256 index = 0; index < total; index++) {
            require(beneficiaries[index] != address(0), "Beneficiary can't be zero address");
            _releaseAllAvailableTokens(beneficiaries[index]);
        }
    }

    function batchLockTokens(
        IERC20[] calldata tokens,
        address[] calldata beneficiaries,
        uint256[] calldata durations,
        uint256[] calldata peridicities,
        uint256[] calldata amounts,
        uint256[] calldata cliffTimes
    ) external onlyOwner {
        require(beneficiaries.length == tokens.length, "Invalid params");
        require(beneficiaries.length == durations.length, "Invalid params");
        require(beneficiaries.length == peridicities.length, "Invalid params");
        require(beneficiaries.length == amounts.length, "Invalid params");
        require(beneficiaries.length == cliffTimes.length, "Invalid params");
        uint256 total = beneficiaries.length;

        for (uint256 index = 0; index < total; index++) {
            _lockTokens(
                tokens[index],
                beneficiaries[index],
                durations[index],
                peridicities[index],
                amounts[index],
                cliffTimes[index]
            );
        }
    }

    /**
     * Lock Tokens
     *
     * @param token                     address of token to lock
     * @param beneficiary               address of beneficiary
     * @param duration                  total duration
     * @param periodicity                periodicity
     * @param amount                    total amount of token
     * @param cliffTime                 timestamp of cliffTime
     */
    function lockTokens(
        IERC20 token,
        address beneficiary,
        uint256 duration,
        uint256 periodicity,
        uint256 amount,
        uint256 cliffTime
    ) external onlyOwner {
        _lockTokens(token, beneficiary, duration, periodicity, amount, cliffTime);
    }

    function _lockTokens(
        IERC20 token,
        address beneficiary,
        uint256 duration,
        uint256 periodicity,
        uint256 amount,
        uint256 cliffTime
    ) private {
        require(address(token) != address(0), "Invalid Token");
        require(cliffTime > block.timestamp, "CliffTime should be greater than current time");
        require(periodicity > 0, "Periodicity should be greater than zero");
        require(duration >= periodicity, "Duration should be greater than periodicity");
        require(
            duration - ((duration / (periodicity)) * (periodicity)) == 0,
            "Duration should be divided by periodicity completely"
        );
        require(amount > 0, "Amount should be greater than zero");
        require(beneficiary != address(0), "Beneficiary can't be zero address");

        uint256 lockLength = lockInfos.length;
        lockInfos.push(
            LockInfo({
                token: token,
                beneficiary: beneficiary,
                duration: duration,
                periodicity: periodicity,
                amount: amount,
                cliffTime: cliffTime,
                released: uint256(0)
            })
        );
        lockIds[beneficiary].push(lockLength);
        lockCount = lockCount + 1;

        emit TokenLocked(beneficiary, duration, periodicity, amount, cliffTime, lockLength);
        token.transferFrom(msg.sender, address(this), amount);
    }
}
