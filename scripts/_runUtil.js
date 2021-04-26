let dataPath = process.cwd() + '/scripts/_data.json'
let fs = require('fs')
let dayJs = require('dayJs')


async function deploy(name, ...args) {
    const [deployer] = await ethers.getSigners();

    console.log(
        `------Deploying ${name} with the account:`,
        deployer.address
    );
    // console.log("Account balance:", (await deployer.getBalance()).toString());

    const Contract = await ethers.getContractFactory(name);
    const contract = await Contract.deploy(...args);

    console.log("Contract address:", contract.address);

    let chainId = (await ethers.provider.getNetwork()).chainId
    if (chainId !== 666) {
        if (!fs.existsSync(dataPath)) {
            fs.writeFileSync(dataPath, JSON.stringify({}, null, 2))
        }
        let data = JSON.parse(String(fs.readFileSync(dataPath)))

        if (!data[chainId]) {
            data[chainId] = {}
        }
        let chainData = data[chainId]
        let key = name+ '/' + dayJs().format('YYYY-MM-DD hh:mm:ss') + "/" +args.join(',')
        chainData[key] = contract.address;
        fs.writeFileSync(dataPath, JSON.stringify(data, null, 2))

    }

    return contract
}

global.$deploy = deploy
