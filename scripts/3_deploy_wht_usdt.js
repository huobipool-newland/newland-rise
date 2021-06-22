let {MDX_ROUTER,
    USDT,
    MDX,
    WHT,

    WHT_USD
} = $config;

async function main() {
    let priceOracle = await $getContract("PriceOracle")
    let bank = await $getContract('Bank')
    let chef = await $getContract('MdexStakingChef')
    let lens = await $getContract('Lens');

    await priceOracle.$setPriceFeed(WHT, WHT_USD);

    // ------ 17 0x499B6E03749B4bAF95F9E70EeD5355b138EA6C31 782
    // WHT 0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F
    // USDT 0xa71EdC38d189767582C38A3145b5873052c3e47a
    await chef.$add(
        1,//allocPoint,
        '0x499B6E03749B4bAF95F9E70EeD5355b138EA6C31',//lpToken,
        17//mdxChefPid
    );

    let liqStrategy = await $deploy('MdxLiqStrategy', MDX_ROUTER);

    let goblin = await $deploy('MdxGoblin',
        bank.address,//operator,
        chef.address,//staking,
        MDX_ROUTER,//router,
        WHT,//token0,
        USDT,//token1,
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
        await goblin.$setSwapPath(WHT, [MDX, WHT]);
    }

    // todo min
    await bank.$opProduction(0, true, true, USDT, goblin.address, 1, 7000, 8500, 0, false);

    await lens.$setStrategyInfo(goblin.address, mdxAddStrategy.address, mdxWithdrawStrategy.address);
    console.log('---done')
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
