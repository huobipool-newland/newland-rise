let {WHT,
    HPT,
    DEP,
    MDX,

    MDX_USD,
    WHT_USD,

    lendCliam,
    lendLens,

    HPT_USD,
    NVALUE,
    C_NVALUE

} = $config;
async function main() {
    let priceOracle = await $deploy("PriceOracle")
    if (priceOracle.$isNew) {
        await priceOracle.$setPriceFeed(WHT, WHT_USD);
        await priceOracle.$setPriceFeed(MDX, MDX_USD);
        await priceOracle.$setPriceFeed(HPT, HPT_USD);
    }

    let bank = await $deploy('Bank')
    let cLendbridge = await $deploy('CLendbridge', bank.address, DEP, lendCliam, HPT, lendLens, WHT)

    await cLendbridge.$setCToken(NVALUE, C_NVALUE)

    let lendChef = await $deploy('LendRewardChef',
        DEP, //dep
        0,//startBlock，
        cLendbridge.address
    )

    let model = await $deploy('CLendInterestModel', cLendbridge.address)

    await $deploy('MdexStakingChef',
        '0xe499ef4616993730ced0f31fa2703b92b50bb536', //hpt
        '10000000000000000',//hptPerBlock
        0,//startBlock
        '0xFB03e11D93632D97a8981158A632Dd5986F5E909',//mdxChef
        '0',//mdxProfitRate
        '0x25d2e80cb6b86881fd7e07dd263fb79f4abe033c',//mdx
        '0x2f1178bd9596ab649014441dDB83c2f240B5527C'//treasuryAddress
    )

    let config = await $deploy('BankConfig')
    if (config.$isNew) {
        await config.$setParams(5000, 200, model.address, '50000000000000000');
    }
    if (bank.$isNew) {
        await bank.$updateLendRewardChef(lendChef.address);
        await bank.$updateConfig(config.address);
        await bank.$updateLendbridge(cLendbridge.address);
        await lendChef.$setOps(bank.address, true)
    }

    let lens = await $deploy('Lens');
    if (lens.$isNew) {
        await lens.$setParams(bank.address, priceOracle.address)
    }
    console.log('---done')
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
