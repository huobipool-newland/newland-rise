let fs = require('fs')
let dataJson = require('./_data')
let abiHome = '../artifacts/contracts/'

let doc = '### 合约信息 \n'
for (let key of Object.keys(dataJson["128"])) {
    let ss = key.split('/')
    let name = ss[0]
    let args = '['+ss[1].split(',').join(',\n')+']'
    let address = dataJson["128"][key]
    doc += `
#### ${name}
- 合约地址 ${address}     
- 初始化参数
\`\`\`
${args}     
\`\`\`  
- 合约ABI
\`\`\`
${JSON.stringify(require(abiHome + `${name}.sol/${name}.json`).abi)}
\`\`\`        
`;
}

fs.writeFileSync(process.cwd() + '/README.md', doc)
