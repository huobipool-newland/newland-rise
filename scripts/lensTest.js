require("./_runUtil");

async function main() {
    const bankAddress = await $getAddress('Bank', 128);
    const oracleAddress = await $getAddress('PriceOracle', 128);

    const lensContract = await $deploy('Lens',bankAddress, oracleAddress);

    const infoAll =  await lensContract.infoAll();
    console.log(infoAll);

    const userAll =  await lensContract.userAll('0xd0D6e0e58fE68bd495B4FD56bfF3B19676460272');
    console.log(userAll);
}

main()
.then(() => process.exit(0))
.catch(error => {
  console.error(error);
  process.exit(1);
});