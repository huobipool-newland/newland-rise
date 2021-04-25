async function deploy(name, ...args) {
    const [deployer] = await ethers.getSigners();

    console.log(
        `------Deploying ${name} with the account:`,
        deployer.address
    );
    console.log("Account balance:", (await deployer.getBalance()).toString());

    const Contract = await ethers.getContractFactory(name);
    const contract = await Contract.deploy(...args);

    console.log("Contract address:", contract.address);
    return contract
}

global.$deploy = deploy