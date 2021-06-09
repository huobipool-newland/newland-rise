let {MDX_ROUTER,
    USDT,
    HUSD,
    MDX,
    WHT,
    HPT,
    DEP,

    HUSD_USD,
    USDT_USD,

    C_USDT,
    C_HUSD} = $config;

async function main() {
    let priceOracle = await $getContract("PriceOracle")
    let bank = await $getContract('Bank')
    let cLendbridge = await $getContract('CLendbridge')
    let lendChef = await $getContract('LendRewardChef')
    let chef = await $getContract('MdexStakingChef')
    let lens = await $getContract('Lens');

    await priceOracle.$setPriceFeed(USDT, USDT_USD);
    await priceOracle.$setPriceFeed(HUSD, HUSD_USD);

    await cLendbridge.$setCToken(USDT, C_USDT);
    await cLendbridge.$setCToken(HUSD, C_HUSD);
    await cLendbridge.$setClaimCTokens([C_USDT, C_HUSD]);

    await lendChef.$add(10, HUSD);
    await lendChef.$add(10, USDT);

    // ------ 10 0xdff86B408284dff30A7CAD7688fEdB465734501C 193
    // HUSD 0x0298c2b32eaE4da002a15f36fdf7615BEa3DA047
    // USDT 0xa71EdC38d189767582C38A3145b5873052c3e47a
    await chef.$add(
        1,//allocPoint,
        '0xdff86B408284dff30A7CAD7688fEdB465734501C',//lpToken,
        10//mdxChefPid
    );

    let liqStrategy = await $deploy('MdxLiqStrategy', MDX_ROUTER);

    let goblin = await $deploy('MdxGoblin',
        bank.address,//operator,
        chef.address,//staking,
        MDX_ROUTER,//router,
        USDT,//token0,
        HUSD,//token1,
        liqStrategy.address,//liqStrategy
        priceOracle.address
    )
    let mdxAddStrategy = await $deploy('MdxStrategyAddTwoSidesOptimal',
        MDX_ROUTER,
        goblin.address
    )
    let mdxWithdrawStrategy =await $deploy('MdxStrategyWithdrawMinimizeTrading',
        MDX_ROUTER,
    )

    if (goblin.$isNew) {
        await goblin.$setStrategyOk([mdxAddStrategy.address, mdxWithdrawStrategy.address], true)
        await chef.$setOps(goblin.address, true)
        await goblin.$setSwapPath(USDT, [MDX, USDT]);
        await goblin.$setSwapPath(HUSD, [MDX, HUSD]);
    }

    await bank.$addToken(USDT, 'nUSDT');
    await bank.$addToken(HUSD, 'nHUSD');
    // todo min
    await bank.$opProduction(0, true, true, USDT, goblin.address, 1, 7000, 8500, 0, false);
    // todo min
    await bank.$opProduction(0, true, true, HUSD, goblin.address, 1, 7000, 8500, 0, false);

    await lens.$setStrategyInfo(goblin.address, mdxAddStrategy.address, mdxWithdrawStrategy.address);
    console.log('---done')
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
