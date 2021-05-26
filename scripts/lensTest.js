require("./_runUtil");

async function main() {
    const bank = await $getContract('Bank');
    const oracle = await $getContract('PriceOracle');

    const lensContract = await $deploy('Lens',bank.address, oracle.address);

    const infoAll =  await lensContract.$infoAll();
    console.log(infoAll);

    console.log(await bank.$getUserPositions('0xAf4cBbDdd17D1fdAD956663a54eE8960De231348'))
    const userAll =  await lensContract.$userAll('0xAf4cBbDdd17D1fdAD956663a54eE8960De231348');
    console.log(userAll);
}

main()
.then(() => process.exit(0))
.catch(error => {
  console.error(error);
  process.exit(1);
});