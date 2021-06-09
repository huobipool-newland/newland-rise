let {WHT,
    HPT,
    DEP,
    HUSD,

    lendCliam,
    lendLens} = $config;
async function main() {
    let bank = await $deploy('Bank')
    let cLendbridge = await $deploy('CLendbridge', bank.address, DEP, lendCliam, HPT, lendLens)

    await cLendbridge.$mintCollateral(HUSD, 80000000);
    // await cLendbridge.$redeemCollateral(C_HUSD, 100000000);


    console.log('---done')
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
