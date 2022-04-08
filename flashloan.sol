// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.5.0;

import "./IERC20.sol";

interface pair {
  function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external ;
}

interface uniRoutr {
  function swapExactTokensForTokens(
      uint amountIn,
      uint amountOutMin,
      address[] calldata path,
      address to,
      uint deadline
      ) external  returns (uint[] memory amounts);

  function getAmountsIn(uint amountOut, address[] calldata path) external returns (uint[] memory amounts);
}

interface IWETH {
  function deposit() external payable;
  function transfer(address to, uint value) external returns (bool);
  function withdraw(uint) external;
}


contract Flashswap {
  // UniswapV2Router02 合约地址
  address public ROUTE = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

  // UniswapV2Pair 合约地址
  address public USDTWETH = 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852;
  address public WETH  = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address public USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7; 
  address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

  uint256 public swapamount;
  uint256 public ETHamount;

  bytes _data = bytes("flashswap");

  event Blance(uint256 amount);

  constructor() public {
    safeApprove(WETH, ROUTE, uint(-1));
    safeApprove(USDT, ROUTE, uint(-1));
    safeApprove(USDC, ROUTE, uint(-1));
  }

  function deposit() public payable {
    // 获取存款金额
    ETHamount = msg.value;
    // 将ETH存入 WETH 合约
    IWETH(WETH).deposit.value(ETHamount)();
    emit Blance(IERC20(WETH).balanceOf(address(this)));
  }

  function getCurrBlance() public view returns (uint){
    return IERC20(WETH).balanceOf(address(this)); 
  }

  function uniswapV2Call(address sender, uint amount0, uint amount1, bytes memory data) public {
    // 获取当前地址的  借入的USDT余额
    uint256 balance0 = IERC20(USDT).balanceOf(address(this));
    emit Blance(balance0);

    // 创建交易路由 UDST-USDC
    address[] memory path1 = new address[](2);
    path1[0] = USDT;
    path1[1] = USDC;
    // 将USDT换成USDC amounts1[1] 为USDC 
    uint[] memory amounts1 = uniRoutr(ROUTE).swapExactTokensForTokens(balance0, uint(0), path1, address(this), block.timestamp + 1800);
    emit Blance(uint256(amounts1[1]));

    // 创建交易路由 USDC-ETH
    address[] memory path2 = new address[](2);
    path2[0] = USDC;
    path2[1] = WETH;
    // 将USDC换成ETH amounts1[1] 为ETH
    uint[] memory amounts2 = uniRoutr(ROUTE).swapExactTokensForTokens(amounts1[1], uint(0), path2, address(this), block.timestamp + 1800);
    emit Blance(amounts2[1]);

    address[] memory path3 = new address[](2);
    path3[0] = WETH;
    path3[1] = USDT;
    // 获取借入 swapamount USDT 需要还多少ETH
    uint[] memory amounts3 = uniRoutr(ROUTE).getAmountsIn(swapamount, path3);
    emit Blance(amounts3[0]);

    // 向USDTWETH合约还WETH 
    IERC20(WETH).transfer(USDTWETH, amounts3[0]);
    emit Blance(ETHamount - amounts2[0]);
  }

  function swap (uint256 _swapamount) public {
    swapamount = _swapamount; 
    pair(USDTWETH).swap(uint(0), _swapamount, address(this), _data);
  }

  function safeApprove(address token, address to, uint value) internal {
    (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
    require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
  }
}
