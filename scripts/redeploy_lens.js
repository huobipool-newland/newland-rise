(async ()=> {
    let bank = await $getContract('Bank')
    let priceOracle = await $getContract("PriceOracle")

    let lens = await $deploy('Lens');
    if (lens.$isNew) {
        await lens.$setParams(bank.address, priceOracle.address)
    }

    let goblins = await $selectContracts('MdxGoblin')
    let withdraw = await $getContract('MdxStrategyWithdrawMinimizeTrading')
    for (let goblin of goblins) {
        let add = (await $selectContracts('MdxStrategyAddTwoSidesOptimal', {1: goblin.address}))[0]
        await lens.$setStrategyInfo(goblin.address, add.address, withdraw.address);
    }

    console.log('---done')
})()