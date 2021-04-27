require("./_runUtil");

let USDT = '0xa71edc38d189767582c38a3145b5873052c3e47a'
let HUSD = '0x0298c2b32eaE4da002a15f36fdf7615BEa3DA047'

let HUSD_USD = '0x45f86CA2A8BC9EBD757225B19a1A0D7051bE46Db'
let USDT_USD = '0xF0D3585D8dC9f1D1D1a7dd02b48C2630d9DD78eD'

async function main() {
    let oracle = await $deploy("Oracle")
    if (oracle.$isNew) {
        await oracle.setPriceFeed(USDT, USDT_USD);
        await oracle.setPriceFeed(HUSD, HUSD_USD);
    }

    let usdtPrice = await oracle.getPrice(USDT);
    let husdPrice = await oracle.getPrice(HUSD);
    console.log(usdtPrice[0].toNumber(), usdtPrice[1].toNumber());
    console.log(husdPrice[0].toNumber(), husdPrice[1].toNumber());
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
