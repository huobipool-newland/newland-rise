require("./_runUtil");

async function main() {
    const bankAddress = '0x136d20E70628a27340f94fA58DaAF1ABF9440A9B';
    const bankContract = await ethers.getContractAt("Bank",bankAddress);
    const lensContract = await $deploy('Lens');

    const infoAll =  await lensContract.infoAll(bankContract.address);

   //address userAddr, Bank bankContract
//    const userPostionAll = lensContract.userPostionAll(lensAddress, );

    console.log("lens Test infoAll:", infoAll);
//    console.log("lens Test userPostionAll:", userPostionAll);


    
}

main()
.then(() => process.exit(0))
.catch(error => {
  console.error(error);
  process.exit(1);
});