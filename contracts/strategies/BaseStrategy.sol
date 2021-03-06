pragma solidity ^0.6.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import '@openzeppelin/contracts/access/Ownable.sol';


import '../interfaces/IStrategy.sol';

contract BaseStrategy is IStrategy, Ownable {
    using SafeMath for uint256; 
    using SafeERC20 for IERC20;

    address public want;

    constructor(address _want) public {
        want = _want;
    }

    function deposit(uint256 amount) external override onlyOwner {
        IERC20(want).safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) public override onlyOwner {
        IERC20(want).safeTransfer(msg.sender, amount);
    }

    function withdrawAll() external override onlyOwner {
        withdraw(totalBalance());
    }

    function totalBalance() public view override returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

}