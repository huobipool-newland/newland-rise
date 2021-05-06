let dataPath = process.cwd() + '/scripts/_data.json'
let fs = require('fs')
let artifactPath = process.cwd() + '/artifacts'

async function deploy(name, ...args) {
    const [deployer] = await ethers.getSigners();
    console.log(`------Deploying ${name} with the account:`, deployer.address);

    let getContractFactoryName = name
    let flPath = artifactPath + '/contracts/' + name + '_fl.sol'
    if (fs.existsSync(flPath) && fs.readdirSync(flPath).length > 0) {
        getContractFactoryName = name + '_fl.sol/' + name
        console.log(getContractFactoryName)
    }
    const Contract = await ethers.getContractFactory(getContractFactoryName);
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
        let key = name+ '/' +args.join(',')
        let chainData = data[chainId]
        let address = chainData[key]
        if (address) {
            contract = Contract.attach(address);
            console.log("Exist Contract address:", contract.address);
        } else {
            contract = await Contract.deploy(...args)
            contract.$isNew = true
            console.log("Deploy Contract address:", contract.address);
            chainData[key] = contract.address;
            fs.writeFileSync(dataPath, JSON.stringify(data, null, 2))
        }
    } else {
        contract = await Contract.deploy(...args)
        contract.$isNew = true
        console.log("Deploy Contract address:", contract.address);
    }

    return contract
}

async function getAddress(name, chainId) {
    if (chainId !== 0 && !chainId) {
        chainId = (await ethers.provider.getNetwork()).chainId
    }
    if (chainId !== 666) {
        if (!fs.existsSync(dataPath)) {
            return null
        }
        let data = JSON.parse(String(fs.readFileSync(dataPath)))

        if (!data[chainId]) {
            data[chainId] = {}
        }
        let chainData = data[chainId]

        for (let key of Object.keys(chainData).reverse()) {
            if (key.startsWith(`${name}/`)) {
                return chainData[key]
            }
        }
    } else {
        return null
    }
}

async function getContract(name) {
    const Contract = await ethers.getContractFactory(name);
    return Contract.attach(await getAddress(name));
}

global.$deploy = deploy
global.$getAddress = getAddress
global.$getContract = getContract
