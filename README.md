### Newland-rise

- 是一个杠杆挖矿项目，支持用户存款获取收益，支持用户借款进行挖矿

#### 合约介绍

- Bank.sol

主合约，主要功能为用户存款，用户取款，杠杆挖矿开补仓，杠杆挖矿赎回，领取奖励，添加银行币种，配置产品

- BankConfig.sol 

银行参数配置合约，如挖矿利润系数，清算利润系数，借款利率

- TripleSlopeModel.sol

借款利率具体实现

- MdxGoblin.sol

针对Mdex的挖矿合约，主要功能为

- MdxStrategyAddTwoSidesOptimal.sol

- MdxStrategyWithdrawMinimizeTrading.sol

- LiqStrategy.sol

- MdexStakingChef.sol

- BankConfig.sol 

- Treasury.sol

- PriceOracle.sol


