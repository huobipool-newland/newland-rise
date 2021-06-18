(async () => {
    let bank = await $getContract('Bank')
    let lendBridge = await $getContract('CLendbridge')
    let bankHusd = await bank.$banks($config.HUSD)
    for (let key of Object.keys(bankHusd)) {
        console.log(key, String(bankHusd[key]))
    }
    await bank.$calInterest($config.USDT)
    await bank.$calInterest($config.HUSD)
    // await bank.$liquidate(35)
    // await bank.$withdrawReserve($config.HUSD, lendBridge.address, 103000000)

    console.log('---done')
})()