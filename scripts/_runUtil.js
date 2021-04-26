let dataPath = process.cwd() + '/scripts/_data.json'
let fs = require('fs')
let dayJs = require('dayJs')

async function deploy(name, ...args) {
    const [deployer] = await ethers.getSigners();
    console.log(`------Deploying ${name} with the account:`, deployer.address);

    const Contract = await ethers.getContractFactory(name);
    let contract;
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
        let address = getAddress(chainData, name)
        if (address) {
            contract = Contract.attach(address);
        } else {
            let key = name+ '/' + dayJs().format('YYYY-MM-DD hh:mm:ss') + "/" +args.join(',')
            contract = await Contract.deploy(...args)
            chainData[key] = contract.address;
            fs.writeFileSync(dataPath, JSON.stringify(data, null, 2))
        }
    } else {
        contract = await Contract.deploy(...args)
    }

    console.log("Contract address:", contract.address);
    return contract
}

function getAddress(data, name) {
    for (let key of Object.keys(data).reverse()) {
        if (key.startsWith(`${name}/`)) {
            return data[key]
        }
    }
}

global.$deploy = deploy
