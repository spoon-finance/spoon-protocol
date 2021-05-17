pragma solidity ^0.6.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/math/SafeMath.sol";
import '@openzeppelin/contracts/access/Ownable.sol';

import './interfaces/IRewardMinter.sol';

contract RewardMinter is Ownable {
    using SafeMath for uint256;

    address public token;
    address public minter;
    mapping (address => uint256) public lockBalances;
    mapping (address => uint256) public claimAmounts;

    uint256 public lockEndTime;
    uint256 public lockRate;

    uint256 public startReleaseTime;
    uint256 public releasePeriod;

    constructor(address _token) public {
        token = _token;
    }

    function setLock(uint256 _lockEndTime, uint256 _lockRate) public onlyOwner {
        lockEndTime = _lockEndTime;
        lockRate = _lockRate;
    }

    function setRelease(uint256 _time, uint256 _period) public onlyOwner {
        startReleaseTime = _time;
        releasePeriod = _period;
    }

    function setMinter(address _minter) public onlyOwner {
        minter = _minter;
    }

    function mint(address to, uint256 amount, uint256 fromTs, uint256 toTs) public {
        require(msg.sender == minter, "no minter");
        IRewardMinter(token).mint(address(this), amount);
        uint256 lockAmount = amount.mul(lockRate).div(100);
        if (fromTs > lockEndTime) {
            lockAmount = 0;
        } else if (toTs > lockEndTime) {
            lockAmount = lockAmount.mul(lockEndTime.sub(fromTs)).div(toTs.sub(fromTs));
        }
        IERC20(token).transfer(to, amount.sub(lockAmount));
        lockBalances[to] = lockBalances[to].add(lockAmount);
    }

    function canClaim(address user) public view returns(uint256) {
        if (block.timestamp <= startReleaseTime) {
            return 0;
        }
        if (block.timestamp >= startReleaseTime.add(releasePeriod)) {
            return lockBalances[user].sub(claimAmounts[user]);
        }
        uint256 releaseAmount = lockBalances[user].mul(block.timestamp.sub(startReleaseTime)).div(releasePeriod);
        return releaseAmount.sub(claimAmounts[user]);
    }

    function claim(uint256 amount) public {
        require(canClaim(msg.sender) >= amount, "invalid amount");
        IERC20(token).transfer(msg.sender, amount);
        claimAmounts[msg.sender] = claimAmounts[msg.sender].add(amount);
    }

}

