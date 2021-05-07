require("./_runUtil");

async function main() {
    const chefAddress = await $getContract('MdexStakingChef', 128);

    console.log((await chefAddress.poolInfo(0)).lpBalance.toString())
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });