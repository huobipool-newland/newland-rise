require("@nomiclabs/hardhat-waffle");
// require('hardhat-contract-sizer');
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.6.12",
    settings: {
      optimizer: {
        enabled: true,
      }
    }
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true
  },
  networks: {
    hardhat: {
      chainId: 666,
      forking: {
        url: "https://http-mainnet-node.huobichain.com"
      },
      accounts: {
        mnemonic:"rural member business salute sea cook render fire notice solid adapt force"
      },
      blockGasLimit: 900000000000000,
      allowUnlimitedContractSize: true
    },
    heco: {
      url: "https://http-mainnet-node.huobichain.com",
      accounts: {
        mnemonic:"rural member business salute sea cook render fire notice solid adapt force"
      },
      allowUnlimitedContractSize: true
    }
  }
};
