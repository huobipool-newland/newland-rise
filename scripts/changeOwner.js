(async () => {
    await $eachContract(async (c,n,a) => {
        if (c.$transferOwnership) {
            console.log(await c.$owner())
            await c.$transferOwnership("0x276bb442d11b0edb5191bb28b81b6374b187bcc2")
        }
    })
    console.log('---done')
})()