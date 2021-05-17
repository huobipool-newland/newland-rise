let Web3 = require('web3');
let web3 = global.web3 || new Web3('http://localhost:8545')

let MdxStrategyAddTwoSidesOptimal_calldata_types = ['address', 'address', 'uint256', 'uint256', 'uint256']
let MdxStrategyWithdrawMinimizeTrading_calldata_types = ['address', 'address', 'uint']
let MdxGoblin_calldata_types = ['address', 'bytes']
let removeSrategyAddress = '0xE90c27bbb9FFA466a193780CCcF06858D117B1b2'

let USDT = '0xa71edc38d189767582c38a3145b5873052c3e47a'
let HUSD = '0x0298c2b32eaE4da002a15f36fdf7615BEa3DA047'
let MDX = '0x25d2e80cb6b86881fd7e07dd263fb79f4abe033c'
let WHT = '0x5545153ccfca01fbd7dd11c0b23ba694d9509a6f'

console.log(opAddData('0xC5649d098F7e87A0e397fe20e5A5f458d8e401ef', HUSD, USDT,100000000,0))
console.log(opRemoveData(  HUSD, USDT, 2))





// -------------------------------
function encode(types, ...args) {
    return web3.eth.abi.encodeParameters(types, args)
}

function decode(types, data) {
    return web3.eth.abi.decodeParameters(types, data)
}

function opAddData(addStrategyAddress, token0Address, token1Address, token0Amount, token1Amount) {
    let data = encode(MdxStrategyAddTwoSidesOptimal_calldata_types,
        token0Address, token1Address,token0Amount,token1Amount,0)
    return encode(MdxGoblin_calldata_types,
        addStrategyAddress, data )
}

function opRemoveData(token0Address, token1Address, whichWantBack) {
    let data = encode(MdxStrategyWithdrawMinimizeTrading_calldata_types,
        token0Address, token1Address, whichWantBack)
    return encode(MdxGoblin_calldata_types,
        removeSrategyAddress, data )
}

