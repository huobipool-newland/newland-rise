let dataPath = process.cwd() + '/scripts/_data.json'
let fs = require('fs')
let artifactPath = process.cwd() + '/artifacts'
let Web3 = require('web3');
let web3 = global.web3 || new Web3('http://localhost:8545')
let MdxStrategyAddTwoSidesOptimal_calldata_types = ['address', 'address', 'uint256', 'uint256', 'uint256']
let MdxStrategyWithdrawMinimizeTrading_calldata_types = ['address', 'address', 'uint']
let MdxGoblin_calldata_types = ['address', 'bytes']

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
        console.log(`Exist Contract ${name} address: ${contract.address}`);
    } else {
        contract = await Contract.deploy(...args)
        contract.$isNew = true
        console.log('\x1B[32m%s\x1B[39m', `Deploy Contract ${name} address: ${contract.address}`);
        chainData[key] = contract.address;
        fs.writeFileSync(dataPath, JSON.stringify(data, null, 2))
    }

    loggerObj(name, contract)
    return contract
}

async function getAddress(name, chainId) {
    if (chainId !== 0 && !chainId) {
        chainId = (await ethers.provider.getNetwork()).chainId
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

    let contract = Contract.attach(await getAddress(name, chainId));
    loggerObj(name, contract);
    contract.$connect = signer => loggerObj(name, contract.connect(signer));
    return contract;
}

async function getDeployInitData(address, chainId) {
    if (chainId !== 0 && !chainId) {
        chainId = (await ethers.provider.getNetwork()).chainId
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

function loggerObj(name, obj) {
    for (let key of Object.keys(obj)) {
        if (typeof obj[key] === "function") {
            let origin = obj[key]
            obj["$" + key] = async (...args) => {
                console.log('\x1B[32m%s\x1B[39m', `#${name}.${key} ${args}`);
                return await origin(...args);
            }
        }
    }
    return obj
}

function encodeParams(types, ...args) {
    return web3.eth.abi.encodeParameters(types, args)
}

function decodeParams(types, data) {
    return web3.eth.abi.decodeParameters(types, data)
}

function opDataDecode(data) {
    let goblinData = decodeParams(MdxGoblin_calldata_types, data)
    console.log(data)
}

function opAddData(addStrategyAddress, token0Address, token1Address, token0Amount, token1Amount) {
    let data = encodeParams(MdxStrategyAddTwoSidesOptimal_calldata_types,
        token0Address, token1Address,token0Amount,token1Amount,0)
    return encodeParams(MdxGoblin_calldata_types,
        addStrategyAddress, data )
}

function opRemoveData(removeSrategyAddress, token0Address, token1Address, whichWantBack) {
    let data = encodeParams(MdxStrategyWithdrawMinimizeTrading_calldata_types,
        token0Address, token1Address, whichWantBack)
    return encodeParams(MdxGoblin_calldata_types,
        removeSrategyAddress, data )
}

async function evmGoSec(seconds) {
    console.log('\x1B[32m%s\x1B[39m', "#evm_increaseTime " + seconds)
    return await ethers.provider.send("evm_increaseTime", [seconds])
}


global.$deploy = deploy
global.$getAddress = getAddress
global.$getContract = getContract
global.$getDeployInitData = getDeployInitData
global.$opAddData = opAddData
global.$opRemoveData = opRemoveData
global.$opDataDecode = opDataDecode
global.$encodeParams = encodeParams
global.$decodeParams = decodeParams
global.$evmGoSec = evmGoSec
global.$config = Object.values(require('./_config')).filter(item => item.$import)[0]


