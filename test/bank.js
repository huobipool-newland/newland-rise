const { expect } = require("chai");

const impersonateAccount = "0xAf4cBbDdd17D1fdAD956663a54eE8960De231348";
const usdt = "0xa71edc38d189767582c38a3145b5873052c3e47a";
const husd = "0x0298c2b32eae4da002a15f36fdf7615bea3da047";
let erc20Artifact = '@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20'
let signer;

describe("BANK", function() {
    before('INIT SIGNER',async () => {
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [impersonateAccount]}
        );
        signer = await ethers.provider.getSigner(impersonateAccount);

        const usdtA = await ethers.getContractAt(erc20Artifact,usdt);
        const husdA = await ethers.getContractAt(erc20Artifact,husd);
        console.log('impersonateAccount:' + impersonateAccount);
        console.log('Balance: ' + (await signer.getBalance()).toString());
        console.log('USDT: ' + (await usdtA.balanceOf(signer.getAddress())).toString() + ' ' + (await usdtA.decimals()));
        console.log('HUSD: ' + (await husdA.balanceOf(signer.getAddress())).toString() + ' ' + (await husdA.decimals()));
    });
    it('DEPOSIT', async () => {
        const bankAddress = await $getContract('Bank');
        const usdtA = await ethers.getContractAt(erc20Artifact,usdt);

        //approve bank
        await usdtA.connect(signer).approve(bankAddress.address,"3000000000000000000");

        //deposit
        console.log("Bank USDT: " + (await bankAddress.banks(usdt)).totalVal.toString());
        await bankAddress.$connect(signer).$deposit(usdt,"3000000000000000000");
        console.log("Bank USDT: " + (await bankAddress.banks(usdt)).totalVal.toString());
    });
    it("开仓", async () => {
        const addStra = await $getAddress('MdxStrategyAddTwoSidesOptimal');
        const bankAddress = await $getContract('Bank');
        const husdA = await ethers.getContractAt(erc20Artifact,husd);

        //approve strategy
        await husdA.connect(signer).approve(addStra,"100000000");

        let cPosition = await bankAddress.$currentPos()
        console.log("currentPosition: " + cPosition)
        await bankAddress.$connect(signer).$opPosition(0,1,"1000000000000000000", $opAddData(addStra, husd, usdt, 100000000, 0));
        console.log("currentPosition: " + (await bankAddress.$currentPos()))
        await $evmGoSec(100)
        await bankAddress.$connect(signer).$claim(cPosition);
        await bankAddress.$connect(signer).$claimAll();
    });
});
