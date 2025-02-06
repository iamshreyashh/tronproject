// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import "interfaces/ITRC20.sol";


/// Interface to fetch decimal of stablecoin
interface ITRC20Metadata is ITRC20 {
    function decimals() external view returns (uint8);
}

/// Interface for the factory contract
interface INuChainFactory {
    function tradingFee() external view returns (uint256);

    function rewardRate() external view returns (uint256);

    function rewardPeriod() external view returns (uint256);

    function paused() external view returns (bool);

    function normalize(uint256 amount, uint256 decimals)
        external
        view
        returns (uint256);

    function denormalize(uint256 amount, uint256 decimals)
        external
        view
        returns (uint256);
}

contract LiquidityPoolTRC20tron 
{
    
   /// TRC20 contract address
   address public owner = msg.sender;
    uint256 public ethcoin;
    INuChainFactory public factory; /// NuChain Factory contract address
    uint256 public totalLiquidityTRC20; /// Returns the value of total liquidity of TRC20
    uint256 public totalLiquidityNativeToken; ///Returns the value of total liquidity of paired stablecoin
    uint8 private NativeoinDecimal; /// Stores the decimal of paired stablecoin
    uint64 private nonce;

    /// @struct store the info of Liquidity provider
    struct LiquidityProviderInfo {
        uint256 liquidityTRC;
        uint256 liquidityStablecoin;
        uint256 rewardLastTime;
    }

    /// Liquidity Provider => Liquidity Provider Info
    mapping(address => LiquidityProviderInfo) public liquidityProviderInfo;

    /// Events of the contract
    event LiquidityAdded(
        address indexed user,
        uint256 amountTRC20,
        uint256 amountStablecoin
    );

    event LiquidityRemoved(
        address indexed user,
        uint256 amountTRC20
    );

    event RecivedTRC20(
        address indexed user,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut,
        uint nonce
    );

    event SwappedETHtoTRC20(
        address indexed user,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    event RewardClaimed(address indexed user, uint256 reward);

    event PegRebalanced(uint256 amount, string direction);

    /// @custom:oz-upgrades-unsafe-allow constructor
    // constructor() {
    //     _disableInitializers();
    // }

    /* 
         @notice initialize the function
         @param _defaultAdmin Default Admin of the contract
         @param _TRC20 contract address of TRC20
         @param _stablecoin paired stable coin contract address
         @param _factory NuChain Factory contract address

    */


    
    //Modifier to ensure valid token amount
    modifier validAmount(uint256 _amount) {
        require(_amount > 0, "Invalid Amount");
        _;
    }

    //Modifier to ensure reward period is complete 
    modifier rewardCoolDown(address _user) {
        LiquidityProviderInfo memory liquidity = liquidityProviderInfo[_user];
        require(
            block.timestamp >=
                liquidity.rewardLastTime + factory.rewardPeriod(),
            "Reward cooldown period not met"
        );
        _;
    }

    modifier restricted() {
    require(
      msg.sender == owner,
      "This function is restricted to the contract's owner"
    );
    _;
  }

    //Modifier to ensure that liquidity pool is not paused
    modifier whenPoolNotPaused() {
        require(factory.paused() == false, "Liquidity Pools are paused");
        _;
    }

    // ======================
    // Liquidity Management
    // ======================

    /*
        @notice Add Liquidity to the pool
        @param _amountTRC20 TRC20 amount that user want to add
        @param _amountStablecoin amount of paired stablecoin that user want to add
    */
    function addLiquidityTRC20(uint256 _amountTRC20, address _tokenAddress)
    external payable
    whenPoolNotPaused
    validAmount(_amountTRC20)
{
    uint256 _amountStablecoin = msg.value;
    require(
        ITRC20(_tokenAddress).transferFrom(msg.sender, address(this), _amountTRC20),
        "TRC20 transfer failed"
    );
    
    uint256 totalReward;
    LiquidityProviderInfo storage liquidity = liquidityProviderInfo[msg.sender];

    // Avoid redundant reward calculation if no liquidity is added/removed
    if (liquidity.liquidityTRC > 0 || liquidity.liquidityStablecoin > 0) {
        totalReward = calculateReward(msg.sender);
        require(
            ITRC20(_tokenAddress).transfer(msg.sender, totalReward),
            "TRC20 transfer failed"
        );
    }

    liquidity.liquidityTRC += _amountTRC20;
    liquidity.liquidityStablecoin += _amountStablecoin;
    totalLiquidityTRC20 += _amountTRC20;
    totalLiquidityNativeToken += _amountStablecoin;

    totalLiquidityTRC20 -= totalReward;  // Deduct reward only after adding liquidity

    liquidity.rewardLastTime = block.timestamp;

    emit LiquidityAdded(msg.sender, _amountTRC20, _amountStablecoin);
}


    /*
        @notice Add Liquidity to the pool
        @param _amountTRC20 TRC20 amount that user want to remove
        @param _amountStablecoin amount of paired stablecoin that user want to remove
    */
    function removeLiquidity(uint256 _amountTRC20, address _tokenAddress)
        external
        whenPoolNotPaused
    
        validAmount(_amountTRC20)
    {
        LiquidityProviderInfo storage liquidity = liquidityProviderInfo[
            msg.sender
        ];

        require(
            liquidity.liquidityTRC >= _amountTRC20,
            "Insufficient TRC20 balance"
        );


        uint256 totalReward = calculateReward(msg.sender);

        require(ITRC20(_tokenAddress).transfer(msg.sender, totalReward), "TRC20 Transfer Failed");

        liquidity.liquidityTRC -= _amountTRC20;
        
        totalLiquidityTRC20 -= _amountTRC20;
        totalLiquidityTRC20 -= totalReward;
        liquidity.rewardLastTime = block.timestamp;

        require(ITRC20(_tokenAddress).transfer(msg.sender, _amountTRC20), "TRC20 transfer Failed");
        emit LiquidityRemoved(msg.sender, _amountTRC20);
    }

    //=====================//
    // Trading(Swapping)   //
    //=====================//

    /*
        @notice Swapping of stablecoins
        @param _tokenIn Address of the token you want to swap in
        @param _tokenOut Address of the token you want to swap out
        @param _amountIn Amount of token you want to swap
    */
    function swapTRC20toUSDN(address _tokenIn, uint256 _amountIn)
    external whenPoolNotPaused  validAmount(_amountIn)
    returns (uint256 _amountOut)
{

    uint256 feeInTRC20 = (_amountIn * factory.tradingFee()) / 10000;
    uint256 amountInAfterFee = _amountIn - feeInTRC20;
    _amountOut = amountInAfterFee;
    
    require(totalLiquidityTRC20 >= _amountOut, "Insufficient Liquidity for Native token");
    totalLiquidityNativeToken -= _amountOut;
    totalLiquidityTRC20 += _amountIn;

    require(ITRC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn), "Input token transfer failed");

    emit RecivedTRC20(msg.sender, _tokenIn, _amountIn, _amountOut,nonce);
    nonce++;
}

function transferTRC(address to, uint256 value, uint256 _nonce) external {
    require(_nonce == (nonce-1), "invalid nonce");
    require(to != address(0), "Invalid recipient address");
    require(value > 0, "Invalid transfer value");
    // Attempt to transfer tokens from the contract to the recipient
    bool success = ITRC20(0x951b0d0B432122A85D3CA3fbeEea96d986543AcC).transfer(to, value);
    require(success, "Token transfer failed");
}

    // ====================
    // Reward Management
    // ====================

    /*
        @notice Fuction to calculate the reward
        @param _user address of the liquidity provider for which we want to calculate reward
        @returns reward of the liquidity provider
    */

   function calculateReward(address _user) public view returns (uint256) {
    LiquidityProviderInfo memory liquidity = liquidityProviderInfo[_user];
    uint256 timeLapse = block.timestamp - liquidity.rewardLastTime;
    uint256 numToMul = timeLapse / factory.rewardPeriod();

    uint256 totalLiquidity = totalLiquidityTRC20 + totalLiquidityNativeToken;
    require(totalLiquidity > 0, "No Liquidity in Pool");

    uint256 userShare = ((liquidity.liquidityTRC + factory.normalize(
        liquidity.liquidityStablecoin,
        NativeoinDecimal
    )) * 1e18) / totalLiquidity;

    // Combine division with multiplication
    return (numToMul * userShare * factory.rewardRate()) / (1e18);
}


    /*
        @notice Fuction to claim the reward
    */
    // function claimReward() external whenPoolNotPaused  rewardCoolDown(msg.sender){
    //     LiquidityProviderInfo storage liquidity = liquidityProviderInfo[
    //         _msgSender()
    //     ];

    //     uint256 reward = calculateReward(msg.sender);
    //     require(reward > 0, "No rewards to claim");
    //     require(ITRC20(_tokenAddress).transfer(msg.sender, reward),"Reward transfer failed");
    //     liquidity.rewardLastTime = block.timestamp;
    //     totalLiquidityTRC20 -= reward;

    //     emit RewardClaimed(msg.sender, reward);

    // }

    // =======================
    // Peg Rebalancing
    // =======================

    /*
        @notice function to rebalance the liquidity pool
        @param _amount The amount default admin want to add
        @param isAddLiquidityToTRC20 true if want to add TRC20 else false
        only default admin can call this function
    */
    function rebalancePegTRC20(uint _amount, address _tokenAddress) external restricted
    {
            require(ITRC20(_tokenAddress).transferFrom(msg.sender,address(this),_amount),"TRC20 transfer failed");
            totalLiquidityTRC20 += _amount;
            emit PegRebalanced(_amount, "Added to TRC20");
        
    }

    function rebalancePegNative(uint _amount) external payable restricted{ 
           _amount = msg.value;
           (bool success, ) = payable(address(this)).call{value: _amount}("");
            require(success, "Native token transfer failed");
            totalLiquidityNativeToken+= _amount;
            emit PegRebalanced(_amount, "Added to Native");
        }


    /*
        @notice function to withdraw the token
        only default admin can call this function
    */
    function withdrawToken(address _to,address _token,uint256 _amount) external restricted{
        require(
            ITRC20(_token).transfer(_to, _amount),
            "Emergency withdrawal failed"
        );
            totalLiquidityTRC20 -= _amount;
      
    }


receive() external payable { }
}
