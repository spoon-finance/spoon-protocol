pragma solidity ^0.6.0;

import "./BaseVault.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Router01.sol";


contract SpiritVault is BaseVault {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public lpToken;
    address public token0;
    address public token1;
    uint256 public spiritMasterChefPid;

    address[] public path0;
    address[] public path1;

    address public constant spiritToken = 0x5Cc61A78F164885776AA610fb0FE1257df78E59B;
    address public constant spiritMasterChef = 0x9083EA3756BDE6Ee6f27a6e996806FBD37F6F093;
    address public constant spiritFactory = 0xEF45d134b73241eDa7703fa787148D9C9F4950b0;
    address public constant spiritRouter = 0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52;
    
    address public feeReceiver;
    address public devAddr;

    uint256 public feeRate = 0;
    uint256 public devRate = 0;

    uint256 public freePeriod = 0;
    uint256 public exitFeeRate = 0;

    constructor(
        address _lpToken,
        string memory _name,
        string memory _symbol,
        address[] memory _path0,
        address[] memory _path1,
        uint256 _spiritChefPid,
        address _feeReceiver
    ) 
        public 
        BaseVault(
            _name,
            _symbol,
            _lpToken
        )
    {
        lpToken = _lpToken;
        spiritMasterChefPid = _spiritChefPid;
        feeReceiver = _feeReceiver;
        devAddr = msg.sender;
        token0 = IUniswapV2Pair(lpToken).token0();
        token1 = IUniswapV2Pair(lpToken).token1();
        path0 = _path0;
        path1 = _path1;
        IERC20(lpToken).safeApprove(spiritMasterChef, 10**60);
    }

    function _harvest() internal override {
        (uint256 stakeAmount, ) = ISpiritMasterChef(spiritMasterChef).userInfo(spiritMasterChefPid, address(this));
        if (stakeAmount > 0) {
            ISpiritMasterChef(spiritMasterChef).withdraw(spiritMasterChefPid, 0);
        }

        uint256 spiritAmount = IERC20(spiritToken).balanceOf(address(this));
        if (spiritAmount > 0) {
            IERC20(spiritToken).safeTransfer(feeReceiver, spiritAmount.mul(feeRate).div(100));
            IERC20(spiritToken).safeTransfer(devAddr, spiritAmount.mul(devRate).div(100));
            spiritAmount = IERC20(spiritToken).balanceOf(address(this));

            if (path0.length > 0) {
                IUniswapV2Router01(spiritRouter).swapExactTokensForTokens(spiritAmount.div(2), 1, path0, address(this), block.timestamp);
            }
            if (path1.length > 0) {
                IUniswapV2Router01(spiritRouter).swapExactTokensForTokens(spiritAmount.div(2), 1, path1, address(this), block.timestamp);
            }
            IUniswapV2Router01(spiritRouter).addLiquidity(token0, token1, 
                IERC20(token0).balanceOf(address(this)), 
                IERC20(token1).balanceOf(address(this)), 
                1, 1, address(this), block.timestamp);
        }
    }

    function _invest() internal override {
        uint256 lpAmount = IERC20(lpToken).balanceOf(address(this));
        if (lpAmount > 0) {
            ISpiritMasterChef(spiritMasterChef).deposit(spiritMasterChefPid, lpAmount);
        }

    }

    function _exit() internal override {
        ISpiritMasterChef(spiritMasterChef).withdrawAll(spiritMasterChefPid);
    }

    function _exitSome(uint256 _amount) internal override {
        ISpiritMasterChef(spiritMasterChef).withdraw(spiritMasterChefPid, _amount);
    }

    function _withdrawFee(uint256 _withdrawAmount, uint256 _lastDepositTime) internal override returns (uint256) {
        if (_lastDepositTime.add(freePeriod) <= block.timestamp) {
            return 0;
        }
        uint256 feeAmount = _withdrawAmount.mul(exitFeeRate).div(1000);
        IERC20(lpToken).safeTransfer(feeReceiver, feeAmount);
        return feeAmount;
    }

    function _totalTokenBalance() internal view override returns (uint256) {
        (uint256 stakeAmount, ) = ISpiritMasterChef(spiritMasterChef).userInfo(spiritMasterChefPid, address(this));
        return IERC20(lpToken).balanceOf(address(this)).add(stakeAmount);
    }

    function setPath(address[] calldata _path0, address[] calldata _path1) public onlyOwner {
        path0 = _path0;
        path1 = _path1;
    }

    function setFeeReceiver(address _addr) public onlyOwner {
        feeReceiver = _addr;
    }

    function setFeeRate(uint256 _rate) public onlyOwner {
        require(_rate <= 50, "invalid rate");
        feeRate = _rate;
    }

    function setDevRate(uint256 _rate) public onlyOwner {
        require(_rate <= 10, "invalid");
        devRate = _rate;
    }

    function setExitFeeRate(uint256 _rate) public onlyOwner {
        require(_rate <= 5, "invalid");
        exitFeeRate = _rate;
    }

    function setFreePeriod(uint256 _period) public onlyOwner {
        require(_period <= 15 days, "invalid period");
        freePeriod = _period;
    }

    function dev(address _dev) public {
        require(msg.sender == devAddr || msg.sender == owner(), "dev: wut?");
        devAddr = _dev;
    }
    
}


interface ISpiritMasterChef {
    function userInfo(uint256 pid, address user) external view returns (uint256, uint256); 
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function withdrawAll(uint256 _pid) external;
}