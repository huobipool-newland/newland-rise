(async () => {
    $eachContract(async (c,n,a) => {
        if (c.$transferOwnership) {
            c.$transferOwnership("0x2f1178bd9596ab649014441dDB83c2f240B5527C")
        }
    })
    console.log('---done')
})()