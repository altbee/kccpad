// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IKoffeeSwapPair.sol";
import "./interfaces/IKCCConfig.sol";
import "./interfaces/IStaking.sol";
import "./interfaces/ILPMining.sol";

contract KCCConfig is Ownable, IKCCConfig {
    // launch holder participants
    address public override baseToken;
    uint256 public override baseAmount;

    //
    IKoffeeSwapPair public pair;

    //
    IStaking public staking;
    ILPMining public lpMining;

    // fee
    address public override feeRecipient;
    uint256 public override feePercent; // 10: 1%, 15: 1.5%

    constructor(
        IKoffeeSwapPair _pair,
        IStaking _staking,
        ILPMining _lpMining,
        IERC20 _baseToken,
        uint256 _baseAmount,
        address _feeRecipient,
        uint256 _feePercent
    ) {
        require(address(_baseToken) != address(0), "Invalid baseToken address");
        require(_baseAmount > 0, "Base amount should be greater than 0");

        require(_feeRecipient != address(0), "Invalid _feeRecipient address");
        require(_feePercent < 1000, "Too big fee percent");

        require(address(_pair) != address(0), "Invalid pair address");
        require(
            _pair.token0() == address(_baseToken) || _pair.token1() == address(_baseToken),
            "Pair is not related to baseToken"
        );

        require(address(_staking) != address(0), "Invalid staking address");
        require(address(_lpMining) != address(0), "Invalid lpMining address");

        baseToken = address(_baseToken);
        baseAmount = _baseAmount;
        feePercent = _feePercent;
        feeRecipient = _feeRecipient;
        pair = _pair;
        staking = _staking;
        lpMining = _lpMining;
    }

    function updateFeeInfo(address _feeRecipient, uint256 _feePercent) external onlyOwner {
        require(_feeRecipient != address(0), "Invalid _feeRecipient address");
        require(_feePercent < 1000, "Too big fee percent");

        feePercent = _feePercent;
        feeRecipient = _feeRecipient;
    }

    function updateBaseAmount(uint256 _baseAmount) external onlyOwner {
        require(_baseAmount > 0, "BaseAmount should be greater than 0!");

        baseAmount = _baseAmount;
    }

    /*
     * sum of LP owned and staked
     */
    function getTotalLPBalance(address user) public view returns (uint256) {
        require(user != address(0), "Invalid user address");

        return pair.balanceOf(user) + lpMining.getDepositedAmount(user);
    }

    /*
     * sum of token owned and staked
     */
    function getTotalTokenBalance(address user) public view returns (uint256) {
        require(user != address(0), "Invalid user address");

        return IERC20(baseToken).balanceOf(user) + staking.getDepositedAmount(user);
    }

    /*
     * sum of LP owned and staked
     */
    function getTokenValueOfLP(uint256 lpAmount) private view returns (uint256) {
        uint256 lpTotalSupply = pair.totalSupply();
        address token0 = pair.token0();
        address token1 = pair.token1();
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();

        if (token0 == address(baseToken)) {
            return (reserve0 * 2 * lpAmount) / lpTotalSupply;
        } else if (token1 == address(baseToken)) {
            return (reserve1 * 2 * lpAmount) / lpTotalSupply;
        } else {
            return 0;
        }
    }

    function getAllInToken(address user) external view override returns (uint256) {
        uint256 token = getTotalTokenBalance(user);
        uint256 lpAmount = getTotalLPBalance(user);

        return token + getTokenValueOfLP(lpAmount);
    }
}
