// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/NFTRestaker.sol";

interface IWithdrawRequestNFT {
    function getClaimableAmount(uint256 tokenId) external view returns (uint256);
    function claimWithdraw(uint256 tokenId) external;
    function finalizeRequests(uint256 requestId) external;
}

contract NFTRestakerTest is Test {
    // Contracts
    address payable LIQUIDITY_POOL = payable(0x308861A430be4cce5502d0A12724771Fc6DaF216);
    address WITHDRAW_REQUEST_NFT = 0x7d5706f6ef3F89B3951E23e557CDFBC3239D4E2c;
    address EETH_TOKEN = 0x35fA164735182de50811E8e2E824cFb9B6118ac2;
    // Multisigs
    address LIQUIDITY_POOL_MANAGER = 0x3d320286E014C3e1ce99Af6d6B00f0C1D63E3000;
    address WITHDRAWAL_ADMIN = 0x0EF8fa4760Db8f5Cd4d993f3e3416f30f942D705;
    
    NFTRestaker public nftRestaker;

    address team;
    address alice;
    address bob;

    function setUp() public {
        team = makeAddr("team");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        vm.deal(team, 1 ether);
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
    }

    function testEarnYield() public {
        console.log("Team balance before:");
        console.log(team.balance);

        vm.startPrank(team);
        nftRestaker = new NFTRestaker(
            LIQUIDITY_POOL,
            EETH_TOKEN
        );
        // El team compra un NFT, simplemente porque startPrank requiere al menos una tx
        nftRestaker.mint{value: 0.01 ether}();
        // Alice y Bob compran 100 NFTs cada uno
        vm.stopPrank();
        vm.startPrank(alice);
        for(uint i=0; i<100; i++)
            nftRestaker.mint{value: 0.01 ether}();
        vm.stopPrank();
        vm.startPrank(bob);
        for(uint i=0; i<100; i++)
            nftRestaker.mint{value: 0.01 ether}();
        skip(100 days);
        vm.stopPrank();
        vm.startPrank(LIQUIDITY_POOL_MANAGER);
        // Mientras tanto EtherFi aplica el rebase y los ingresos crecen
        ILiquidityPool(LIQUIDITY_POOL).rebase(100_000 ether);
        vm.stopPrank();
        vm.startPrank(team);
        // Des-stakeamos
        uint requestId = nftRestaker.withdrawTeam();
        vm.stopPrank();
        vm.startPrank(WITHDRAWAL_ADMIN);
        // EtherFi finaliza nuestra request
        IWithdrawRequestNFT(WITHDRAW_REQUEST_NFT).finalizeRequests(requestId);
        vm.stopPrank();
        vm.startPrank(team);
        // Claimeamos nuestro ether
        IWithdrawRequestNFT(WITHDRAW_REQUEST_NFT).claimWithdraw(requestId);
        vm.stopPrank();

        console.log("Team balance after:");
        console.log(team.balance);
    }
}
