// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

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

contract EtherFiStaker {
    address payable LIQUIDITY_POOL;
    address WITHDRAW_REQUEST_NFT;
    address EETH_TOKEN;
    mapping(address account => uint amount) public sharesByAccount;

    constructor(address payable liquidityPool, address withdrawRequestNFT, address eETH) {
        LIQUIDITY_POOL = liquidityPool;
        WITHDRAW_REQUEST_NFT = withdrawRequestNFT;
        EETH_TOKEN = eETH;
    }

    function stake() public payable { // Prevent reentrancy
        uint shares = ILiquidityPool(LIQUIDITY_POOL).deposit{value: msg.value}();
        sharesByAccount[msg.sender] += shares;
    }

    function unstake(uint shares) public returns(uint requestId) {
        require(shares <= sharesByAccount[msg.sender], "Not enough shares");
        sharesByAccount[msg.sender] -= shares;
        uint amount = ILiquidityPool(LIQUIDITY_POOL).amountForShare(shares);
        IERC20(EETH_TOKEN).approve(LIQUIDITY_POOL, amount);
        return ILiquidityPool(LIQUIDITY_POOL).requestWithdraw(msg.sender, amount);
    }
}
