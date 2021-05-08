let dataPath = process.cwd() + '/scripts/_data.json'
let fs = require('fs')
let artifactPath = process.cwd() + '/artifacts'
let Web3 = require('web3');
let web3 = global.web3 || new Web3('http://localhost:8545')

async function deploy(name, ...args) {
    const [deployer] = await ethers.getSigners();
    console.log(`------Deploying ${name} with the account:`, deployer.address);

    let getContractFactoryName = name
    let flPath = artifactPath + '/contracts/' + name + '_fl.sol'
    if (fs.existsSync(flPath) && fs.readdirSync(flPath).length > 0) {
        getContractFactoryName = 'contracts/' + name + '_fl.sol:' + name
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
    if (chainId === 666) {
        return null
    }

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
}

async function getContract(name, chainId) {
    let getContractFactoryName = name
    let flPath = artifactPath + '/contracts/' + name + '_fl.sol'
    if (fs.existsSync(flPath) && fs.readdirSync(flPath).length > 0) {
        getContractFactoryName = 'contracts/' + name + '_fl.sol:' + name
    }
    const Contract = await ethers.getContractFactory(getContractFactoryName);
    return Contract.attach(await getAddress(name, chainId));
}

async function getDeployInitData(address, chainId) {
    if (chainId !== 0 && !chainId) {
        chainId = (await ethers.provider.getNetwork()).chainId
    }
    if (chainId === 666) {
        return null
    }
    let data = JSON.parse(String(fs.readFileSync(dataPath)))[chainId]
    if (!data) {
        return null
    }
    let name;
    let args;
    for (let key of Object.keys(data)) {
        if (data[key].toLowerCase() === address.toLowerCase()) {
            let strs = key.split('/');
            name = strs[0]
            args = strs[1]
            break
        }
    }
    if (!name || !args) {
        return null
    }

    let sourcePath = process.cwd() + '/contracts/' + name + '.sol'
    let argsArray = args.split(',')

    let source = String(fs.readFileSync(sourcePath))
    let methodArgs = source.split(/constructor\s*\(/g)[1].split(/\)\s*public/g)[0]
    let methodTypes = methodArgs.split(',').filter(s => s).map(s => s.trim().split(/\s+/)[0])

    for(let i = 0;i<methodTypes.length;i++) {
        if (!isBaseType(methodTypes[i])) {
            methodTypes[i] = 'address'
        }
    }
    return web3.eth.abi.encodeParameters(methodTypes, argsArray)
}

function isBaseType(type) {
    for (let prefix of ['address', 'uint', 'int', 'byte', 'string']) {
        if (type.startsWith(prefix)) {
            return true;
        }
    }
    return false
}

global.$deploy = deploy
global.$getAddress = getAddress
global.$getContract = getContract
global.$getDeployInitData = getDeployInitData
