require("@nomiclabs/hardhat-waffle");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.6.12",
  networks: {
    hardhat: {
      chainId: 1,
      // forking: {
      //   url: "https://eth-mainnet.alchemyapi.io/v2/s_wCrA62gAffVHfvW_66rQr9Nq_diDCp"
      // },
      accounts: {
        mnemonic:"rural member business salute sea cook render fire notice solid adapt force"
      },
      blockGasLimit: 900000000000000,
      allowUnlimitedContractSize: true
    }
  }
};
