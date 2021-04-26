
ethers.provider.getBlockNumber().then((blockNumber) => {
    console.log("Current block number: " + blockNumber);
});

console.log(ethers.provider)

console.log(process.env.network)