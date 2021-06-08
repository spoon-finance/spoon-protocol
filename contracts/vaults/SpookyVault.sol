pragma solidity ^0.6.0;

import "./BaseVault.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Router01.sol";


contract SpookyVault is BaseVault {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public lpToken;
    address public token0;
    address public token1;
    uint256 public spookyMasterChefPid;

    address[] public path0;
    address[] public path1;

    address public constant spookyToken = 0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE;
    address public constant spookyMasterChef = 0x2b2929E785374c651a81A63878Ab22742656DcDd;
    address public constant spookyFactory = 0x152eE697f2E276fA89E96742e9bB9aB1F2E61bE3;
    address public constant spookyRouter = 0xF491e7B69E4244ad4002BC14e878a34207E38c29;
    
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
        uint256 _spookyChefPid,
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
        spookyMasterChefPid = _spookyChefPid;
        feeReceiver = _feeReceiver;
        devAddr = msg.sender;
        token0 = IUniswapV2Pair(lpToken).token0();
        token1 = IUniswapV2Pair(lpToken).token1();
        path0 = _path0;
        path1 = _path1;
        IERC20(lpToken).approve(spookyMasterChef, uint256(-1));
        IERC20(spookyToken).approve(spookyMasterChef, uint256(-1));
        IERC20(token0).approve(spookyMasterChef, uint256(-1));
        IERC20(token1).approve(spookyMasterChef, uint256(-1));
    }

    function _harvest() internal override {
        (uint256 stakeAmount, ) = ISpookyMasterChef(spookyMasterChef).userInfo(spookyMasterChefPid, address(this));
        if (stakeAmount > 0) {
            ISpookyMasterChef(spookyMasterChef).withdraw(spookyMasterChefPid, 0);
        }

        uint256 spookyAmount = IERC20(spookyToken).balanceOf(address(this));
        if (spookyAmount > 0) {
            IERC20(spookyToken).safeTransfer(feeReceiver, spookyAmount.mul(feeRate).div(100));
            IERC20(spookyToken).safeTransfer(devAddr, spookyAmount.mul(devRate).div(100));
            spookyAmount = IERC20(spookyToken).balanceOf(address(this));

            if (path0.length > 0) {
                IUniswapV2Router01(spookyRouter).swapExactTokensForTokens(spookyAmount.div(2), 1, path0, address(this), block.timestamp);
            }
            if (path1.length > 0) {
                IUniswapV2Router01(spookyRouter).swapExactTokensForTokens(spookyAmount.div(2), 1, path1, address(this), block.timestamp);
            }
            IUniswapV2Router01(spookyRouter).addLiquidity(token0, token1, 
                IERC20(token0).balanceOf(address(this)), 
                IERC20(token1).balanceOf(address(this)), 
                1, 1, address(this), block.timestamp);
        }
    }

    function _invest() internal override {
        uint256 lpAmount = IERC20(lpToken).balanceOf(address(this));
        if (lpAmount > 0) {
            ISpookyMasterChef(spookyMasterChef).deposit(spookyMasterChefPid, lpAmount);
        }

    }

    function _exit() internal override {
        ISpookyMasterChef(spookyMasterChef).withdrawAll(spookyMasterChefPid);
    }

    function _exitSome(uint256 _amount) internal override {
        ISpookyMasterChef(spookyMasterChef).withdraw(spookyMasterChefPid, _amount);
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
        (uint256 stakeAmount, ) = ISpookyMasterChef(spookyMasterChef).userInfo(spookyMasterChefPid, address(this));
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


interface ISpookyMasterChef {
    function userInfo(uint256 pid, address user) external view returns (uint256, uint256); 
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function withdrawAll(uint256 _pid) external;
}