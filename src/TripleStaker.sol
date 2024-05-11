// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IeETH {
    function shares(address _user) external view returns (uint256);
}

interface ILiquidityPool { 
    function deposit() external payable returns (uint256);
    function requestWithdraw(address _recipient, uint256 _amount) external returns (uint256);
    function rebase(int128 _accruedRewards) external;
    function getTotalEtherClaimOf(address _user) external view returns (uint256);
    function amountForShare(uint256 _share) external view returns (uint256);
}

interface IWithdrawRequestNFT {
    function getClaimableAmount(uint256 tokenId) external view returns (uint256);
    function claimWithdraw(uint256 tokenId) external;
    function finalizeRequests(uint256 requestId) external;
}

// ERC20 interface used to interact with the staking token, which is DAI on this tutorial
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

struct StakerData {
    uint lastClaimTimestamp;
    uint amount;
}

contract TripleStaker {
    address payable LIQUIDITY_POOL;
    address WITHDRAW_REQUEST_NFT;
    IERC20 public eETH;
    IERC20 public tripleStakingToken;

    // Staking data
    uint public totalDeposits;
    uint public pendingClaim;
    mapping(address => StakerData) public stakerData;

    // Daily history
    uint public lastDayCalculated;
    uint public lastDayCalculatedTimestamp;
    mapping(uint => uint) public dayTotalRewards;
    mapping(uint => uint) public dayTotalDeposited;

    // Launch state
    uint public rewardGenesisTiemstamp;

    // Mechanics
    uint STAKING_CLOSE_PERIOD = 1 days;
    uint public rewardRateDailyPercentage = 1000;

    constructor(address tripleStakingTokenAddress,
                address liquidityPool, address withdrawRequestNFT, address eETHAddress // Etherfi
                ) {
        eETH = IERC20(eETHAddress);
        tripleStakingToken = IERC20(tripleStakingTokenAddress);

        // Initialize claim
        rewardGenesisTiemstamp = lastDayCalculatedTimestamp = block.timestamp;

        // Etherfi
        LIQUIDITY_POOL = payable(liquidityPool);
        WITHDRAW_REQUEST_NFT = withdrawRequestNFT;
    }

    // Modifiers

    modifier updateReward() {
        uint daysSinceLastDayRewardCalculation = (block.timestamp - lastDayCalculatedTimestamp)/(STAKING_CLOSE_PERIOD);
        if(totalDeposits > 0 && daysSinceLastDayRewardCalculation > 0)
        {
            for(uint i=0; i<daysSinceLastDayRewardCalculation; i++)
            {
                uint currentContractTokenSupply = eETH.balanceOf(address(this)) - pendingClaim;
                uint currentDayReward = ((currentContractTokenSupply * rewardRateDailyPercentage) / 10000);
                dayTotalRewards[lastDayCalculated + i] = currentDayReward;
                dayTotalDeposited[lastDayCalculated + i] = totalDeposits;
                pendingClaim += currentDayReward;
            }
            lastDayCalculated = lastDayCalculated + daysSinceLastDayRewardCalculation;
            lastDayCalculatedTimestamp = block.timestamp;
        }
        _;
    }
    // External functions

    function stake3X(uint amount) external updateReward() {
        require(amount > 0, "Amount must be greater than 0.");
        totalDeposits += amount;

        uint firstDayToClaim = (block.timestamp - rewardGenesisTiemstamp) / (STAKING_CLOSE_PERIOD);
        stakerData[msg.sender].lastClaimTimestamp = firstDayToClaim;
        
        stakerData[msg.sender].amount += amount;
        tripleStakingToken.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint amount) external updateReward() {
        require(amount > 0, "No amount sent.");
        require(stakerData[msg.sender].amount > 0, "Sender has no deposits.");
        require(stakerData[msg.sender].amount >= amount, "Sender has no enough Triple Staking Token deposited to match withdraw amount.");
        totalDeposits -= amount;
        stakerData[msg.sender].amount -= amount;
        tripleStakingToken.transfer(msg.sender, amount);
    }

    function claim() public updateReward() returns(uint requestId) {
        uint reward;
        uint daysClaimed;
        while(stakerData[msg.sender].lastClaimTimestamp + daysClaimed < lastDayCalculated)
        {
            if(dayTotalDeposited[stakerData[msg.sender].lastClaimTimestamp + daysClaimed] != 0)
            {
                reward += (dayTotalRewards[stakerData[msg.sender].lastClaimTimestamp + daysClaimed] * stakerData[msg.sender].amount)
                    / dayTotalDeposited[stakerData[msg.sender].lastClaimTimestamp + daysClaimed];
            }
            daysClaimed += 1;
        }

        stakerData[msg.sender].lastClaimTimestamp += daysClaimed;
        pendingClaim -= reward;
        eETH.approve(LIQUIDITY_POOL, reward);
        return ILiquidityPool(LIQUIDITY_POOL).requestWithdraw(msg.sender, reward);
    }

    function calculateClaim(address participant) public view returns(uint)
    {
        if(stakerData[participant].amount == 0)
        {
            return 0;
        }
        uint reward;
        uint daysClaimed;
        while(dayTotalDeposited[stakerData[participant].lastClaimTimestamp + daysClaimed] != 0)
        {
            reward += (dayTotalRewards[stakerData[participant].lastClaimTimestamp + daysClaimed] * stakerData[participant].amount)
                / dayTotalDeposited[stakerData[participant].lastClaimTimestamp + daysClaimed];
            daysClaimed+=1;
        }

        uint daysSinceLastDayRewardCalculation = (block.timestamp - lastDayCalculatedTimestamp)/(STAKING_CLOSE_PERIOD);
        uint pendingClaimAux = pendingClaim;
        uint totalDepositsAux = totalDeposits;
        for(uint i=0; i<daysSinceLastDayRewardCalculation; i++)
        {
            uint currentContractTokenSupply = eETH.balanceOf(address(this)) - pendingClaimAux;
            uint currentDayReward = ((currentContractTokenSupply * rewardRateDailyPercentage) / 10000);
            reward += (currentDayReward * stakerData[participant].amount)
                / totalDepositsAux;
            pendingClaimAux += currentDayReward;
        }
        return reward;
    }

    function updateRewardFunction() public updateReward() {
    }

    // Etherfi

    function stakeETH() public payable {
        ILiquidityPool(LIQUIDITY_POOL).deposit{value: msg.value}();
    }
}