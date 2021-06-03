const { expect } = require("chai");

const impersonateAccount = "0x7381712B04A28f7639026dE8250a0A91153f2Dc9";
const usdt = "0xa71edc38d189767582c38a3145b5873052c3e47a";
const husd = "0x0298c2b32eae4da002a15f36fdf7615bea3da047";
let erc20Artifact = '@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20'
let signer;
let MDX = '0x25d2e80cb6b86881fd7e07dd263fb79f4abe033c'
let MDX_C
let openPosition
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

        MDX_C = await ethers.getContractAt(erc20Artifact,MDX);
    });
    it("开仓", async () => {
        const addStra = await $getAddress('MdxStrategyAddTwoSidesOptimal');
        const bankAddress = await $getContract('Bank');

        const usdtA = await ethers.getContractAt(erc20Artifact,usdt);
        //approve bank
        await usdtA.connect(signer).approve(addStra,"3000000000000000000");

        openPosition = await bankAddress.$currentPos()
        console.log("currentPosition: " + openPosition)
        await bankAddress.$connect(signer).$opPosition(0,1,"0", $opAddData(addStra, husd, usdt, 0, '200000000000000000'));
    });
    it("复投", async () => {
        const addStra = await $getAddress('MdxStrategyAddTwoSidesOptimal');
        const bankAddress = await $getContract('Bank');

        await bankAddress.$connect(signer).$reInvest(openPosition, usdt, openPosition,1,"0", $opAddData(addStra, husd, usdt, 0, '73469695954510'));
    });
});
