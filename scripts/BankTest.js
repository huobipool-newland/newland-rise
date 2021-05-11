require("./_runUtil");


const impersonateAccount = "0xAf4cBbDdd17D1fdAD956663a54eE8960De231348";
const usdt = "0xa71edc38d189767582c38a3145b5873052c3e47a";
const husd = "0x0298c2b32eae4da002a15f36fdf7615bea3da047";

async function main() {
    
    const bankAddress = await $getContract('Bank', 128);
    const usdtA = await ethers.getContractAt("IERC20",usdt); 
    const husdA = await ethers.getContractAt("IERC20",husd); 

    // const usdtContract = await erc20.attach(usdt);
    // const husdContract = await erc20.attach(husd);

    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [impersonateAccount]}
      );

    const signer = await ethers.provider.getSigner(impersonateAccount);
    console.log((await signer.getBalance()).toString());
    console.log((await usdtA.balanceOf(signer.getAddress())).toString());
    console.log((await husdA.balanceOf(signer.getAddress())).toString());
    //approve
    await usdtA.connect(signer).approve(bankAddress.address,"1000000000000000000000");
    await husdA.connect(signer).approve(bankAddress.address,"1000000000000000");

    //deposit
    await bankAddress.connect(signer).deposit(usdt,"3000000000000000000");
    console.log((await bankAddress.banks(usdt)).totalVal.toString());
    
    await bankAddress.connect(signer).opPosition(0,1,"1000000000000000000","0x000000000000000000000000c732cee78bd5fb04c58aab3fc5e3f54cc338b63b000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000298c2b32eae4da002a15f36fdf7615bea3da047000000000000000000000000a71edc38d189767582c38a3145b5873052c3e47a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");


}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });