(async () => {
    $eachContract(async (c,n,a) => {
        if (c.$transferOwnership) {
            console.log(await c.$owner())
            c.$transferOwnership("0x2484de6894b5f7ea8278b1883ed3e5a58c93a038")
        }
    })
    console.log('---done')
})()