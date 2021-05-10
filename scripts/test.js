require("./_runUtil");

//ethers.provider.getBlockNumber().then(console.log);
//ethers.provider.getNetwork().then(console.log);


// ethers.provider.getCode('0x136d20E70628a27340f94fA58DaAF1ABF9440A9B').then(console.log)

// $getDeployInitData('0xE721096c166777eb45b0FDCab62463B03e13f870', 128).then(console.log)

(async () => {
    let USDT = '0xa71edc38d189767582c38a3145b5873052c3e47a'
    let HUSD = '0x0298c2b32eaE4da002a15f36fdf7615BEa3DA047'
    let MDX = '0x25d2e80cb6b86881fd7e07dd263fb79f4abe033c'
    let WHT = '0x5545153ccfca01fbd7dd11c0b23ba694d9509a6f'

    let HUSD_USD = '0x45f86CA2A8BC9EBD757225B19a1A0D7051bE46Db'
    let USDT_USD = '0xF0D3585D8dC9f1D1D1a7dd02b48C2630d9DD78eD'
    let MDX_USD = '0xaC4600b8F42317eAF056Cceb06cFf987c294840B'
    let WHT_USD = '0x8EC213E7191488C7873cEC6daC8e97cdbAdb7B35'

    let priceOracle = await $deploy("PriceOracle")

    // await priceOracle.$setPriceFeed(USDT, USDT_USD);
    // await priceOracle.$setPriceFeed(HUSD, HUSD_USD);
    // await priceOracle.$setPriceFeed(WHT, WHT_USD);
    // await priceOracle.$setPriceFeed(MDX, MDX_USD);
    // await priceOracle.$setOps('e38d716995cb7f181f29258aa392dc3665d418e4', true)
    console.log(await priceOracle.$getOpRecords())
})()