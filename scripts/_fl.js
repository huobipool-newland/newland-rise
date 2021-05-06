const exec = require('child_process').exec;
let fs = require('fs')
let solHome = process.cwd() + "/contracts";

for (let name of fs.readdirSync(solHome)) {
    if (!name.endsWith('.sol')) {
        continue
    }
    if (name.endsWith('_fl.sol')) {
        continue
    }
    let path = solHome +'/' + name
    let flPath = solHome +'/' + name.replace(/\.sol$/, '') + '_fl.sol'
    e(`npx hardhat flatten ${path} > ${flPath}`).then(() => {
        wrapper(flPath)
        console.log(`${name} done`)
    });
}

function wrapper(flPath) {
    let text = String(fs.readFileSync(flPath))
    text = text.replace(/\/\/ SPDX-License-Identifier: MIT/g, '')
    text = '// SPDX-License-Identifier: MIT\n' + text

    if (text.match(/pragma experimental ABIEncoderV2;/)) {
        text = text.replace(/pragma experimental ABIEncoderV2;/g, '')
        text = 'pragma experimental ABIEncoderV2;\n' + text
    }
    fs.writeFileSync(flPath, text)
}

function e(cmd, mbNum){
    return new Promise((resolve, reject) => {
        exec(`${cmd}`, {
                maxBuffer: 1024 * 1024 * (mbNum || 3) //quick fix
            },
            function (err, stdout, stderr) {
                resolve(stdout ? String(stdout).trim():'')
            });
    })
}


