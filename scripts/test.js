require("./_runUtil");

//ethers.provider.getBlockNumber().then(console.log);
//ethers.provider.getNetwork().then(console.log);


// ethers.provider.getCode('0x136d20E70628a27340f94fA58DaAF1ABF9440A9B').then(console.log)

$getDeployInitData('0xE721096c166777eb45b0FDCab62463B03e13f870', 128).then(console.log)
