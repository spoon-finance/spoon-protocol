pragma solidity ^0.6.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import '@openzeppelin/contracts/access/Ownable.sol';

import './interfaces/IStrategy.sol';

contract Vault is ERC20, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public want;
    address public strategy;

    event Deposit(address indexed user, uint256 amount, uint256 mintAmount);
    event Withdraw(address indexed user, uint256 amount, uint256 wantAmount);

    constructor(
        address _want,
        address _strategy,
        string memory name,
        string memory symbol
    ) 
        public 
        ERC20(name, symbol) 
    {
        want = _want;
        strategy = _strategy;
        IERC20(_want).safeApprove(_strategy, uint256(-1));
    }

    function deposit(uint256 amount) public {
        IERC20(want).safeTransferFrom(msg.sender, address(this), amount);
        uint256 mintAmount = amount;
        if (totalSupply() > 0) {
            mintAmount = totalSupply().mul(amount).div(IStrategy(strategy).totalBalance());
        }
        IStrategy(strategy).deposit(amount);
        _mint(msg.sender, mintAmount);
        emit Deposit(msg.sender, amount, mintAmount);
    }

    function withdraw(uint256 amount) public {
        uint256 wantAmount = IStrategy(strategy).totalBalance().mul(amount).div(totalSupply());
        IStrategy(strategy).withdraw(wantAmount);
        IERC20(want).safeTransfer(msg.sender, wantAmount);
        emit Withdraw(msg.sender, amount, wantAmount);
    }

    function withdrawAll() public {
        withdraw(balanceOf(msg.sender));
    }

    function setStrategy(address _strategy) public onlyOwner {
        IStrategy(strategy).withdrawAll();
        strategy = _strategy;
        IERC20(want).safeApprove(_strategy, uint256(-1));
        IStrategy(strategy).deposit(IERC20(want).balanceOf(address(this)));
    }

}