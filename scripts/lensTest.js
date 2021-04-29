require("./_runUtil");

async function main() {
    const bankAddress = '0x136d20E70628a27340f94fA58DaAF1ABF9440A9B';
    const bankContract = await ethers.getContractAt("Bank",bankAddress);
    console.log(await $getAddress('PriceOracle', 128))
    
    const lensContract = await $deploy('Lens',bankAddress, await $getAddress('PriceOracle', 128));

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