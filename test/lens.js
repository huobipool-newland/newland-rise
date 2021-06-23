const { expect } = require("chai");
const impersonateAccount = "0xAf4cBbDdd17D1fdAD956663a54eE8960De231348";
const usdt = "0xa71edc38d189767582c38a3145b5873052c3e47a";
const husd = "0x0298c2b32eae4da002a15f36fdf7615bea3da047";
let erc20Artifact = '@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20'
let signer;
let MDX = '0x25d2e80cb6b86881fd7e07dd263fb79f4abe033c'
let MDX_C

describe("lens", function() {
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
    it('清算池列表', async () => {
        const lensContract = await $deploy('Lens');
        //
        console.log(await lensContract.$getAllUserPos())
    });
    it("test1", async function() {
        const lensContract = await $deploy('Lens');


        // //deposit
        // const bankAddress = await $getContract('Bank');
        // const usdtA = await ethers.getContractAt(erc20Artifact,usdt);

        // //approve bank
        // await usdtA.connect(signer).approve(bankAddress.address,"3000000000000000000");

        // //deposit
        // console.log("Bank USDT: " + (await bankAddress.banks(usdt)).totalVal.toString());
        // await bankAddress.$connect(signer).$deposit(usdt,"3000000000000000000");
        // console.log("Bank USDT: " + (await bankAddress.banks(usdt)).totalVal.toString());
    


        const infoAll =  await lensContract.$infoAll();
        console.log(infoAll[0][0].tokenAddr.toString());
        console.log(infoAll[0][0].totalVal.toString());
        console.log(infoAll[1].toString());

        // //opPosition
        // const addStra = await $getAddress('MdxStrategyAddTwoSidesOptimal');
        // const husdA = await ethers.getContractAt(erc20Artifact,husd);

        // //approve strategy
        // await husdA.connect(signer).approve(addStra,"100000000");

        // let cPosition = await bankAddress.$currentPos()
        // console.log("currentPosition: " + cPosition)
        // await bankAddress.$connect(signer).$opPosition(0,1,"1000000000000000000", $opAddData(addStra, husd, usdt, 100000000, 0));
        // console.log("currentPosition: " + (await bankAddress.$currentPos()))




        //console.log(await bank.$getUserPositions('0x831f6b2a293af9d5c8a6649dd42cc2f6efc2fe96'))
        //check lens
        // const posAll = await lensContract.$getAllUserPos();
        // console.log(posAll.toString());
        // const userAll =  await lensContract.$userAll(impersonateAccount);
        // console.log(userAll[0].toString());
    });
});
