let Web3 = require('web3');
let web3 = global.web3 || new Web3('http://localhost:8545')

let MdxStrategyAddTwoSidesOptimal_calldata_types = ['address', 'address', 'uint256', 'uint256', 'uint256']
let MdxStrategyWithdrawMinimizeTrading_calldata_types = ['address', 'address', 'uint']
let MdxGoblin_calldata_types = ['address', 'bytes']

let data = encode(MdxStrategyAddTwoSidesOptimal_calldata_types,
    '0x0298c2b32eaE4da002a15f36fdf7615BEa3DA047', '0xa71EdC38d189767582C38A3145b5873052c3e47a',100000000,0,0 )
console.log(data)
console.log(decode(MdxStrategyWithdrawMinimizeTrading_calldata_types, data))

let data2 = encode(MdxGoblin_calldata_types,
    '0xC5649d098F7e87A0e397fe20e5A5f458d8e401ef', data )
console.log(data2)














// -------------------------------
function encode(types, ...args) {
    return web3.eth.abi.encodeParameters(types, args)
}

function decode(types, data) {
    return web3.eth.abi.decodeParameters(types, data)
}



