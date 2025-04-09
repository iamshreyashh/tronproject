// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "interfaces/ITRC20.sol";

interface ITRC20Metadata is ITRC20 {
    function decimals() external view returns (uint8);
}

interface IFactory {
    function tradingFee() external view returns (uint256);
    function rewardRate() external view returns (uint256);
    function rewardPeriod() external view returns (uint256);
    function paused() external view returns (bool);
    function normalize(uint256 amount, uint256 decimals) external view returns (uint256);
    function denormalize(uint256 amount, uint256 decimals) external view returns (uint256);
}

contract GenericLiquidityPool {
    address public owner = msg.sender;
    uint256 public totalLiquidityToken;
    uint256 public totalLiquidityNative;
    uint8 private nativeTokenDecimals;
    uint64 private nonce;
    IFactory public factory;

    struct LiquidityProvider {
        uint256 tokenAmount;
        uint256 nativeAmount;
        uint256 lastRewardTime;
    }

    mapping(address => LiquidityProvider) public providers;

    event LiquidityAdded(address indexed user, uint256 tokenAmount, uint256 nativeAmount);
    event LiquidityRemoved(address indexed user, uint256 tokenAmount);
    event TokenSwapIn(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut, uint nonce);
    event NativeToTokenSwap(address indexed user, address tokenOut, uint256 amountIn, uint256 amountOut);
    event RewardClaimed(address indexed user, uint256 reward);
    event PoolRebalanced(uint256 amount, string direction);

    modifier validAmount(uint256 _amount) {
        require(_amount > 0, "Amount must be greater than zero");
        _;
    }

    modifier rewardCooldown(address _user) {
        require(
            block.timestamp >= providers[_user].lastRewardTime + factory.rewardPeriod(),
            "Reward cooldown active"
        );
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can execute");
        _;
    }

    modifier poolActive() {
        require(!factory.paused(), "Pool is paused");
        _;
    }

    function addLiquidity(uint256 _tokenAmount, address _tokenAddress)
        external
        payable
        poolActive
        validAmount(_tokenAmount)
    {
        uint256 nativeAmount = msg.value;
        require(ITRC20(_tokenAddress).transferFrom(msg.sender, address(this), _tokenAmount), "Token transfer failed");

        uint256 reward;
        LiquidityProvider storage lp = providers[msg.sender];

        if (lp.tokenAmount > 0 || lp.nativeAmount > 0) {
            reward = calculateReward(msg.sender);
            require(ITRC20(_tokenAddress).transfer(msg.sender, reward), "Reward transfer failed");
        }

        lp.tokenAmount += _tokenAmount;
        lp.nativeAmount += nativeAmount;
        lp.lastRewardTime = block.timestamp;

        totalLiquidityToken += _tokenAmount - reward;
        totalLiquidityNative += nativeAmount;

        emit LiquidityAdded(msg.sender, _tokenAmount, nativeAmount);
    }

    function removeLiquidity(uint256 _tokenAmount, address _tokenAddress)
        external
        poolActive
        validAmount(_tokenAmount)
    {
        LiquidityProvider storage lp = providers[msg.sender];
        require(lp.tokenAmount >= _tokenAmount, "Insufficient balance");

        uint256 reward = calculateReward(msg.sender);
        require(ITRC20(_tokenAddress).transfer(msg.sender, reward), "Reward transfer failed");

        lp.tokenAmount -= _tokenAmount;
        totalLiquidityToken -= (_tokenAmount + reward);
        lp.lastRewardTime = block.timestamp;

        require(ITRC20(_tokenAddress).transfer(msg.sender, _tokenAmount), "Token return failed");

        emit LiquidityRemoved(msg.sender, _tokenAmount);
    }

    function swapTokens(address _tokenIn, uint256 _amountIn)
        external
        poolActive
        validAmount(_amountIn)
        returns (uint256 outputAmount)
    {
        uint256 fee = (_amountIn * factory.tradingFee()) / 10000;
        uint256 netAmount = _amountIn - fee;

        outputAmount = netAmount;
        require(totalLiquidityToken >= outputAmount, "Insufficient liquidity");

        require(ITRC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn), "Transfer failed");

        totalLiquidityNative -= outputAmount;
        totalLiquidityToken += _amountIn;

        emit TokenSwapIn(msg.sender, _tokenIn, _amountIn, outputAmount, nonce++);
    }

    function transferTokens(address to, uint256 value, uint256 _nonce) external {
        require(_nonce == nonce - 1, "Invalid nonce");
        require(to != address(0), "Invalid recipient");
        require(value > 0, "Amount must be positive");

        // NOTE: Replace the token address with your deployed token address when using this function
        address tokenAddress = address(0); // <-- Replace with actual token address
        require(ITRC20(tokenAddress).transfer(to, value), "Transfer failed");
    }

    function calculateReward(address user) public view returns (uint256) {
        LiquidityProvider memory lp = providers[user];
        uint256 timeElapsed = block.timestamp - lp.lastRewardTime;
        uint256 intervals = timeElapsed / factory.rewardPeriod();

        uint256 totalPool = totalLiquidityToken + totalLiquidityNative;
        require(totalPool > 0, "Empty pool");

        uint256 userShare = (
            lp.tokenAmount + factory.normalize(lp.nativeAmount, nativeTokenDecimals)
        ) * 1e18 / totalPool;

        return (intervals * userShare * factory.rewardRate()) / 1e18;
    }

    function rebalanceTokenPool(uint256 amount, address tokenAddr) external onlyOwner {
        require(ITRC20(tokenAddr).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        totalLiquidityToken += amount;
        emit PoolRebalanced(amount, "Token Pool");
    }

    function rebalanceNativePool(uint256 amount) external payable onlyOwner {
        amount = msg.value;
        (bool success, ) = payable(address(this)).call{value: amount}("");
        require(success, "Native transfer failed");
        totalLiquidityNative += amount;
        emit PoolRebalanced(amount, "Native Pool");
    }

    function emergencyWithdraw(address to, address token, uint256 amount) external onlyOwner {
        require(ITRC20(token).transfer(to, amount), "Emergency withdrawal failed");
        totalLiquidityToken -= amount;
    }

    receive() external payable {}
}
