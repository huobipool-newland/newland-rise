
const bankAddress = '0xEb736cC865945725f329309a488E652A2d44Dc0E';
const lensAddress = '0xEb736cC865945725f329309a488E652A2d44Dc0E';



async function main() {
    const lensContract = await ethers.getContractAt("Lens",lensAddress);

    await lensContract.infoAll(bankAddress);

    
}

main()
.then(() => process.exit(0))
.catch(error => {
  console.error(error);
  process.exit(1);
});