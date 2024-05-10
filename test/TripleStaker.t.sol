// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/TripleStaker.sol";

contract TripleStakingToken is ERC20 {
    constructor() ERC20("Triple Staking Token","3xST") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract TripleStakerTest is Test {
    // Contracts
    address payable LIQUIDITY_POOL = payable(0x308861A430be4cce5502d0A12724771Fc6DaF216);
    address WITHDRAW_REQUEST_NFT = 0x7d5706f6ef3F89B3951E23e557CDFBC3239D4E2c;
    address EETH_TOKEN = 0x35fA164735182de50811E8e2E824cFb9B6118ac2;
    // Multisigs
    address LIQUIDITY_POOL_MANAGER = 0x3d320286E014C3e1ce99Af6d6B00f0C1D63E3000;
    address WITHDRAWAL_ADMIN = 0x0EF8fa4760Db8f5Cd4d993f3e3416f30f942D705;
    
    TripleStaker public tripleStaker;
    TripleStakingToken public tripleStakerToken = new TripleStakingToken();

    address alice;
    address bob;

    function setUp() public {
        tripleStaker = new TripleStaker(
            address(tripleStakerToken),
            LIQUIDITY_POOL,
            WITHDRAW_REQUEST_NFT,
            EETH_TOKEN
        );
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
        tripleStakerToken.transfer(alice, 1000 ether);
        tripleStakerToken.transfer(bob, 1000 ether);
    }

    function testEarnYield() public {
        console.log("Staker balance before:");
        console.log(alice.balance);
        tripleStaker.stakeETH{value: 1 ether}();

        // Alice y Bob stakean por 100 días
        vm.startPrank(alice);
        tripleStakerToken.approve(address(tripleStaker), 1000 ether);
        tripleStaker.stake(1000 ether);
        vm.startPrank(bob);
        tripleStakerToken.approve(address(tripleStaker), 0 ether);
        tripleStaker.stake(300 ether);
        skip(100 days);
        vm.startPrank(LIQUIDITY_POOL_MANAGER);
        // Mientras tanto EtherFi aplica el rebase y los ingresos crecen
        ILiquidityPool(LIQUIDITY_POOL).rebase(100_000 ether);
        vm.startPrank(alice);
        // Des-stakeamos
        uint requestId = tripleStaker.claim();
        vm.startPrank(WITHDRAWAL_ADMIN);
        // EtherFi finaliza nuestra request
        IWithdrawRequestNFT(WITHDRAW_REQUEST_NFT).finalizeRequests(requestId);
        vm.startPrank(alice);
        // Claimeamos nuestro ether
        IWithdrawRequestNFT(WITHDRAW_REQUEST_NFT).claimWithdraw(requestId);
        vm.stopPrank();

        console.log("Staker balance after:");
        console.log(alice.balance);
    }
}
