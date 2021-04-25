
async function main() {
    let model = await deploy('TripleSlopeModel')
    let config = await deploy('BankConfig')
    await deploy('Bank')
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });


async function deploy(name, ...args) {
    const [deployer] = await ethers.getSigners();

    console.log(
        "Deploying contracts with the account:",
        deployer.address
    );
    console.log("Account balance:", (await deployer.getBalance()).toString());

    const Contract = await ethers.getContractFactory(name);
    const contract = await Contract.deploy(...args);

    console.log("Contract address:", contract.address);
    return contract
}