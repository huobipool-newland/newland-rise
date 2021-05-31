const { expect } = require("chai");

const impersonateAccount = "0xAf4cBbDdd17D1fdAD956663a54eE8960De231348";
const usdt = "0xa71edc38d189767582c38a3145b5873052c3e47a";
const husd = "0x0298c2b32eae4da002a15f36fdf7615bea3da047";
let erc20Artifact = '@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20'
let signer;
let MDX = '0x25d2e80cb6b86881fd7e07dd263fb79f4abe033c'
let MDX_C

describe("BANK_LENDBRIDGE", function() {
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

        MDX_C = await ethers.getContractAt(erc20Artifact,MDX);
    });
    it('设置借款桥USDT', async () => {
        const usdtA = await ethers.getContractAt(erc20Artifact,usdt);
        let cLendbridge = await $getContract('CLendbridge')

        await usdtA.connect(signer).transfer(cLendbridge.address, '10000000000000000000')
        await cLendbridge.$mintCollateral(usdt, '10000000000000000000')
    });
    it("银行借款开仓",async () => {
        const addStra = await $getAddress('MdxStrategyAddTwoSidesOptimal');
        const bankAddress = await $getContract('Bank');
        const husdA = await ethers.getContractAt(erc20Artifact,husd);

        //approve strategy
        await husdA.connect(signer).approve(addStra,"100000000");

        let cPosition = await bankAddress.$currentPos()
        console.log("currentPosition: " + cPosition)
        await bankAddress.$connect(signer).$opPosition(0,1,"1000000000000000000", $opAddData(addStra, husd, usdt, 100000000, 0));
        console.log("currentPosition: " + (await bankAddress.$currentPos()))
    });
    it("加仓",async () => {
        const addStra = await $getAddress('MdxStrategyAddTwoSidesOptimal');
        const bankAddress = await $getContract('Bank');
        const husdA = await ethers.getContractAt(erc20Artifact,husd);

        const lens = await $getContract('Lens');

        //approve strategy
        await husdA.connect(signer).approve(addStra,"100000000");

        let cPosition = await bankAddress.$currentPos()
        console.log("currentPosition: " + cPosition)
        console.log(await lens.userPosition(cPosition));
        
        await bankAddress.$connect(signer).$opPosition(cPosition,1,"1000000000000000000", $opAddData(addStra, husd, usdt, 100000000, 0));
        console.log("currentPosition: " + (await bankAddress.$currentPos()))
    });
});
