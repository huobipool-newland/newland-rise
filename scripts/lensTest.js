require("./_runUtil");

async function main() {
    const bank = await $getContract('Bank', 128);
    const oracle = await $getContract('PriceOracle', 128);

    const lensContract = await $deploy('Lens',bank.address, oracle.address);

    // const infoAll =  await lensContract.$infoAll();
    // console.log(infoAll);

    //console.log(await bank.$getUserPositions('0x831f6b2a293af9d5c8a6649dd42cc2f6efc2fe96'))
    const userAll =  await lensContract.$userAll('0x831f6b2a293af9d5c8a6649dd42cc2f6efc2fe96');
    console.log(userAll[0][0].lpValue.toString());
}

main()
.then(() => process.exit(0))
.catch(error => {
  console.error(error);
  process.exit(1);
});