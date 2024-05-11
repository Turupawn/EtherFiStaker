// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

interface ILiquidityPool { 
    function deposit() external payable returns (uint256);
    function requestWithdraw(address _recipient, uint256 _amount) external returns (uint256);
    function rebase(int128 _accruedRewards) external;
    function getTotalEtherClaimOf(address _user) external view returns (uint256);
    function amountForShare(uint256 _share) external view returns (uint256);
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract NFTRestaker is ERC721 {
    string public baseTokenURI = "https://nftrestaker.xyz/";
    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public price = 0.01 ether;
    uint supply;
    address public teamWallet;

    // EtherFi Stuff
    address payable LIQUIDITY_POOL;
    address EETH_TOKEN;

    constructor (address liquidityPool, address eETH) ERC721 ("NFT Restaker", "RE") {
        teamWallet = msg.sender;
        LIQUIDITY_POOL = payable(liquidityPool);
        EETH_TOKEN = eETH;
    }

    function mint() public payable {
        require(supply < MAX_SUPPLY,    "Can't mint more than max supply");
        require(msg.value == price,     "Wrong amount of ETH sent");
        supply += 1;
        _mint( msg.sender, supply );
        ILiquidityPool(LIQUIDITY_POOL).deposit{value: msg.value}();
    }

    function withdrawTeam() public payable returns(uint requestId) {
        require(msg.sender == teamWallet, "Only withdrawal address can withdraw");
        IERC20(EETH_TOKEN).approve(LIQUIDITY_POOL, IERC20(EETH_TOKEN).balanceOf(address(this)));
        return ILiquidityPool(LIQUIDITY_POOL).requestWithdraw(msg.sender, IERC20(EETH_TOKEN).balanceOf(address(this)));
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }
}