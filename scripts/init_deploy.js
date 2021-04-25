require("./_runUtil");

let mdxRouter = '0xED7d5F38C79115ca12fe6C0041abb22F0A06C300'
let ETH = '0x64ff637fb478863b7468bc97d30a5bf3a428a1fd'
let USDT = '0xa71edc38d189767582c38a3145b5873052c3e47a'
let address0 = '0x0000000000000000000000000000000000000000'

async function main() {
    let model = await $deploy('TripleSlopeModel')
    let config = await $deploy('BankConfig')
    let bank = await $deploy('Bank')
    let chef = await $deploy('MdexMasterChef',
        '0xe499ef4616993730ced0f31fa2703b92b50bb536', //hpt
        '10000000000000000',//hptPerBlock
        0,//startBlock
        '0xb0b670fc1f7724119963018db0bfa86adb22d941',//factory
        '0x5545153ccfca01fbd7dd11c0b23ba694d9509a6f',//WHT
        '0xFB03e11D93632D97a8981158A632Dd5986F5E909',//mdxChef
        '1000000000000000000',//mdxProfitRate
        '0x25d2e80cb6b86881fd7e07dd263fb79f4abe033c',//mdx
        '0x2f1178bd9596ab649014441dDB83c2f240B5527C'//treasuryAddress
    )
    let liqStrategy = await $deploy('LiqStrategy');
    let goblin = await $deploy('MdxGoblin',
        bank.address,//operator,
        chef.address,//staking,
        0,//stakingPid,
        mdxRouter,//router,
        ETH,//token0,
        USDT,//token1,
        liqStrategy//liqStrategy
    )
    let mdxAddStrategy = await $deploy('MdxStrategyAddTwoSidesOptimal',
        mdxRouter,
        goblin.address
    )
    let mdxWithdrawStrategy =await $deploy('MdxStrategyWithdrawMinimizeTrading',
        mdxRouter,
    )
    await goblin.setStrategyOk([mdxAddStrategy.address, mdxWithdrawStrategy.address], true)
    await config.setParams(1, 1, model.address);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });

