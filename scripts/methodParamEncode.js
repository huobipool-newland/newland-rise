let Web3 = require('web3');
let web3 = global.web3 || new Web3('http://localhost:8545')

let MdxStrategyAddTwoSidesOptimal_calldata_types = ['address', 'address', 'uint256', 'uint256', 'uint256']
let MdxStrategyWithdrawMinimizeTrading_calldata_types = ['address', 'address', 'uint']
let MdxGoblin_calldata_types = ['address', 'bytes']

let data = encode(MdxStrategyWithdrawMinimizeTrading_calldata_types,
    '0xE1e9670D7AC114D145fdbc9D150c943ac8C1F828', '0xE1e9670D7AC114D145fdbc9D150c943ac8C1F828', 123)
console.log(data)
console.log(decode(MdxStrategyWithdrawMinimizeTrading_calldata_types, data))














// -------------------------------
function encode(types, ...args) {
    return web3.eth.abi.encodeParameters(types, args)
}

function decode(types, data) {
    return web3.eth.abi.decodeParameters(types, data)
}



