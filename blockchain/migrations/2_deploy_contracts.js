const PaymentRegistry = artifacts.require("PaymentRegistry");

module.exports = function (deployer) {
    deployer.deploy(PaymentRegistry);
};
