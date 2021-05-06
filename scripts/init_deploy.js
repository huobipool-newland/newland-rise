require("./_runUtil");

let MDX_ROUTER = '0xED7d5F38C79115ca12fe6C0041abb22F0A06C300'
let USDT = '0xa71edc38d189767582c38a3145b5873052c3e47a'
let HUSD = '0x0298c2b32eaE4da002a15f36fdf7615BEa3DA047'
let MDX = '0x25d2e80cb6b86881fd7e07dd263fb79f4abe033c'
let WHT = '0x5545153ccfca01fbd7dd11c0b23ba694d9509a6f'

let HUSD_USD = '0x45f86CA2A8BC9EBD757225B19a1A0D7051bE46Db'
let USDT_USD = '0xF0D3585D8dC9f1D1D1a7dd02b48C2630d9DD78eD'
let MDX_USD = '0xaC4600b8F42317eAF056Cceb06cFf987c294840B'
let WHT_USD = '0x8EC213E7191488C7873cEC6daC8e97cdbAdb7B35'


async function main() {
    let model = await $deploy('TripleSlopeModel')
    let config = await $deploy('BankConfig')
    let bank = await $deploy('Bank')
    let chef = await $deploy('MdexStakingChef',
        '0xe499ef4616993730ced0f31fa2703b92b50bb536', //hpt
        '10000000000000000',//hptPerBlock
        0,//startBlock
        '0xb0b670fc1f7724119963018db0bfa86adb22d941',//factory
        '0x5545153ccfca01fbd7dd11c0b23ba694d9509a6f',//WHT
        '0xFB03e11D93632D97a8981158A632Dd5986F5E909',//mdxChef
        '1000000000000000000',//mdxProfitRate
        '0x25d2e80cb6b86881fd7e07dd263fb79f4abe033c',//mdx
        '0x2f1178bd9596ab649014441dDB83c2f240B5527C'//treasuryAddress
    )
    // ------ 10 0xdff86B408284dff30A7CAD7688fEdB465734501C 193
    // HUSD 0x0298c2b32eaE4da002a15f36fdf7615BEa3DA047
    // USDT 0xa71EdC38d189767582C38A3145b5873052c3e47a
    if (chef.$isNew) {
        await chef.add(
            1,//allocPoint,
            '0xdff86B408284dff30A7CAD7688fEdB465734501C',//lpToken,
            10//mdxChefPid
        );
    }

    let liqStrategy = await $deploy('LiqStrategy');

    let goblin = await $deploy('MdxGoblin',
        bank.address,//operator,
        chef.address,//staking,
        MDX_ROUTER,//router,
        USDT,//token0,
        HUSD,//token1,
        liqStrategy.address//liqStrategy
    )
    let mdxAddStrategy = await $deploy('MdxStrategyAddTwoSidesOptimal',
        MDX_ROUTER,
        goblin.address
    )
    let mdxWithdrawStrategy =await $deploy('MdxStrategyWithdrawMinimizeTrading',
        MDX_ROUTER,
    )

    if (goblin.$isNew) {
        await goblin.setStrategyOk([mdxAddStrategy.address, mdxWithdrawStrategy.address], true)
    }
    if (config.$isNew) {
        await config.setParams(1, 1, model.address);
    }
    if (bank.$isNew) {
        await bank.updateConfig(config.address);
        await bank.addToken(USDT, 'nUSDT');
        await bank.addToken(HUSD, 'nHUSD');
        await bank.opProduction(0, true, true, USDT, goblin.address, 1, 7000, 8500, 0);
        await bank.opProduction(0, true, true, HUSD, goblin.address, 1, 7000, 8500, 0);
    }

    let priceOracle = await $deploy("PriceOracle")
    if (priceOracle.$isNew) {
        await priceOracle.setPriceFeed(USDT, USDT_USD);
        await priceOracle.setPriceFeed(HUSD, HUSD_USD);
        await priceOracle.setPriceFeed(WHT, WHT_USD);
        await priceOracle.setPriceFeed(MDX, MDX_USD);
    }

    await $deploy('Lens', bank.address, priceOracle.address);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
