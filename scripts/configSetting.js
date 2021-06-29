(async () => {
    let model = await $getContract('CLendInterestModel')
    let config = await $getContract('BankConfig')
    await config.$setParams(5000, 200, model.address, '360000000000000000000');
    console.log('---done')
})()