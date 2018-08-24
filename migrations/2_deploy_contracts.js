var Guess = artifacts.require("../contract/Guess.sol");

module.exports = function(deployer) {
  deployer.deploy(Guess);
};