let fs = require('fs')
let dataJson = require('./_data')

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
`;
}

fs.writeFileSync('../README.md', doc)
