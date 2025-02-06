var MyContract = artifacts.require('LiquidityPoolTRC20tron.sol');
 
module.exports = function (deployer) {
  deployer.deploy(MyContract);
};
