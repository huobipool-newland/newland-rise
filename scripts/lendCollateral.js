let {WHT,
    HPT,
    DEP,
    HUSD,
    ETH,
    USDT,
    C_HUSD,
    NVALUE,
    C_NVALUE,
    lendCliam,
    lendLens,
    C_ETH,
    C_USDT,
    address0

} = $config;
async function main() {
    let bank = await $getContract('Bank')
    let cLendbridge = await $getContract('CLendbridge')

    // await cLendbridge.$mintCollateral(USDT, '500000000000000000');
    // await cLendbridge.$redeemCollateral(C_HUSD, 100000000);

    // await cLendbridge.$manualRepay(USDT);
    // await cLendbridge.$manualRepay(HUSD);
    // await cLendbridge.$manualRepay(ETH);

    // await cLendbridge.$setClaimCTokens([C_USDT, C_HUSD]);

    // await cLendbridge.$setCToken(NVALUE, C_NVALUE)
    // await cLendbridge.$manualRepay(NVALUE);

    // await cLendbridge.$manualRepay(NVALUE);

    // await cLendbridge.$mintCollateral(NVALUE, '100000000000000000000000000');
    // await cLendbridge.$redeemCollateral(C_NVALUE, '1000000000000000000000');

    await cLendbridge.$manualRepay(USDT);
    console.log('---done')
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
