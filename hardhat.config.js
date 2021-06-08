require("@nomiclabs/hardhat-waffle");
// require('hardhat-contract-sizer');
require("./scripts/_runUtil.js");
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
        url: "http://172.18.7.1:8545"
      },
      accounts: {
        mnemonic:"rural member business salute sea cook render fire notice solid adapt force"
      },
      blockGasLimit: 900000000000000,
      gasPrice: 1.3 * 1000000000,
      allowUnlimitedContractSize: true
    },
    heco: {
      url: "https://http-mainnet-node.huobichain.com",
      accounts: {
        mnemonic:"rural member business salute sea cook render fire notice solid adapt force"
      },
      gasPrice: 1.3 * 1000000000,
      allowUnlimitedContractSize: true
    },
    hecoTest: {
      url: "https://http-testnet.hecochain.com",
      accounts: {
        mnemonic:"rural member business salute sea cook render fire notice solid adapt force"
      },
      gasPrice: 1.3 * 1000000000,
      allowUnlimitedContractSize: true
    }
  },
  mocha: {
    timeout: 2000000,
  }
};
