require("./_runUtil");

const impersonateAccount = "0xAf4cBbDdd17D1fdAD956663a54eE8960De231348";
const usdt = "0xa71edc38d189767582c38a3145b5873052c3e47a";
const husd = "0x0298c2b32eae4da002a15f36fdf7615bea3da047";
let erc20Artifact = '@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20'

async function main() {
    const addStra = await $getAddress('MdxStrategyAddTwoSidesOptimal');
    const bankAddress = await $getContract('Bank');
    const usdtA = await ethers.getContractAt(erc20Artifact,usdt);
    const husdA = await ethers.getContractAt(erc20Artifact,husd);

    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [impersonateAccount]}
      );

    const signer = await ethers.provider.getSigner(impersonateAccount);
    console.log('Balance: ' + (await signer.getBalance()).toString());
    console.log('USDT: ' + (await usdtA.balanceOf(signer.getAddress())).toString());
    console.log('HUSD: ' + (await husdA.balanceOf(signer.getAddress())).toString());
    //approve bank
    await usdtA.connect(signer).approve(bankAddress.address,"1000000000000000000000");
    await husdA.connect(signer).approve(bankAddress.address,"1000000000000000");
    //approve strategy
    await usdtA.connect(signer).approve(addStra,"1000000000000000000000");
    await husdA.connect(signer).approve(addStra,"1000000000000000");

    //deposit
    await bankAddress.$connect(signer).$deposit(usdt,"3000000000000000000");
    console.log("Bank USDT: " + (await bankAddress.banks(usdt)).totalVal.toString());
    let cPosition = await bankAddress.$currentPos()
    console.log("currentPosition: " + cPosition)
    await bankAddress.$connect(signer).$opPosition(0,1,"1000000000000000000", $opAddData(addStra, husd, usdt, 100000000, 0));

    await bankAddress.$connect(signer).$claim(cPosition);
    await bankAddress.$connect(signer).$claimAll();
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });