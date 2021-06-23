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
    address0,
    C_HUSD} = $config;

async function main() {
    let lendChef = await $getContract('LendRewardChef')

    // await lendChef.$add(10, HUSD);
    // await lendChef.$add(10, USDT);
    await lendChef.$add(10, address0);

    console.log('---done')
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
