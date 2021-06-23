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
    C_USDT

} = $config;
async function main() {
    let bank = await $getContract('Bank')
    let cLendbridge = await $getContract('CLendbridge')

    // await cLendbridge.$mintCollateral(HUSD, 1000000000);
    // await cLendbridge.$redeemCollateral(C_HUSD, 100000000);

    // await cLendbridge.$manualRepay(USDT);
    // await cLendbridge.$manualRepay(HUSD);
    // await cLendbridge.$manualRepay(ETH);

    // await cLendbridge.$setClaimCTokens([C_USDT, C_HUSD]);
    // await cLendbridge.redeemCollateral(C_HUSD, '1069581543')

    // await cLendbridge.$setCToken(NVALUE, C_NVALUE)
    // await cLendbridge.$manualRepay(NVALUE);

    // await cLendbridge.$setClaimCTokens([C_USDT, C_HUSD, C_ETH]);

    // await cLendbridge.$redeemCollateral(C_HUSD, 10000000);

    // await cLendbridge.$mintCollateral(NVALUE, '100000000000000000000000000');
    // await cLendbridge.$manualRepay(USDT);
    // await cLendbridge.$redeemCollateral(C_NVALUE, '99999999999999999990000000');


    console.log('---done')
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
