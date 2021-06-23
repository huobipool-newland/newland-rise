(async () => {
    let bank = await $getContract('Bank')
    let lendBridge = await $getContract('CLendbridge')
    let priceOracle = await $getContract("PriceOracle")

    let lens = await $deploy('Lens');
    if (lens.$isNew) {
        await lens.$setParams(bank.address, priceOracle.address)
    }

    // await bank.$calInterest($config.USDT)
    // await bank.$calInterest($config.HUSD)
    // await bank.$calInterest($config.ETH)
    //
    // let bankUsdt = await bank.$banks($config.USDT)
    // for (let key of Object.keys(bankUsdt)) {
    //     console.log(key, String(bankUsdt[key]))
    // }
    // let bankHusd = await bank.$banks($config.HUSD)
    // for (let key of Object.keys(bankHusd)) {
    //     console.log(key, String(bankHusd[key]))
    // }
    // let bankEth = await bank.$banks($config.ETH)
    // for (let key of Object.keys(bankEth)) {
    //     console.log(key, String(bankEth[key]))
    // }

    // await bank.$liquidate(35)

    // await bank.$withdrawReserve($config.USDT, lendBridge.address, '2844012491453417250')
    // await bank.$withdrawReserve($config.HUSD, lendBridge.address, 205)
    // await bank.$withdrawReserve($config.ETH, lendBridge.address, '28307093146694')
    console.log('---done')
})()