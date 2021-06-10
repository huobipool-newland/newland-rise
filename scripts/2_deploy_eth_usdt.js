let {MDX_ROUTER,
    USDT,
    MDX,
    WHT,

    ETH,
    ETH_USD,
    C_ETH
} = $config;

async function main() {
    let priceOracle = await $getContract("PriceOracle")
    let bank = await $getContract('Bank')
    let cLendbridge = await $getContract('CLendbridge')
    let lendChef = await $getContract('LendRewardChef')
    let chef = await $getContract('MdexStakingChef')
    let lens = await $getContract('Lens');

    await priceOracle.$setPriceFeed(ETH, ETH_USD);

    await cLendbridge.$setCToken(ETH, C_ETH);

    await lendChef.$add(10, ETH);

    // ------ 9 0x78C90d3f8A64474982417cDB490E840c01E516D4 1781
    // ETH 0x64FF637fB478863B7468bc97D30a5bF3A428a1fD
    // USDT 0xa71EdC38d189767582C38A3145b5873052c3e47a
    await chef.$add(
        1,//allocPoint,
        '0x78C90d3f8A64474982417cDB490E840c01E516D4',//lpToken,
        9//mdxChefPid
    );

    let liqStrategy = await $deploy('MdxLiqStrategy', MDX_ROUTER);

    let goblin = await $deploy('MdxGoblin',
        bank.address,//operator,
        chef.address,//staking,
        MDX_ROUTER,//router,
        ETH,//token0,
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
        await goblin.$setSwapPath(ETH, [MDX, ETH]);
    }

    await bank.$addToken(ETH, 'nETH');

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
