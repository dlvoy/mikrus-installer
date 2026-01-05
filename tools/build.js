const fs = require('fs');
const path = require('path');
const regexDevRemove = /(\#dev\-begin.*?\#dev\-end)\n/mgs;
const regexInclude = /(#include\s+(\S+))/mgs;
const regexVer = /(###\s+version:\s+)([0-9]+\.[0-9]+\.[0-9]+)/mgs;
const regexScrVer = /(SCRIPT_VERSION\s*=\s*\")([0-9]+\.[0-9]+\.[0-9]+)(\"\s+#auto-update)/mgs;
const regexDate = /(SCRIPT_BUILD_TIME\s*=\s*\")([0-9.]+)(\"\s+#auto-update)/mgs;

const srcDir = fs.realpathSync(__dirname + path.sep + '..' + path.sep + 'src')
const baseDir = fs.realpathSync(__dirname + path.sep + '..' )
const manifest = require(baseDir + path.sep + 'package.json'  )

console.log(`Version from manifest: ${manifest.version}`)
const event = new Date();
const dateFormated = event.toISOString().substr(0, 10).replaceAll('-', '.');

try {
    let data = fs.readFileSync(srcDir + path.sep + 'setup.sh', 'utf8');
    while (data.includes('#include') || data.includes('#dev-begin')) {
        data = data.replace(regexDevRemove, '');
        data = data.replace(regexInclude, (_, _2, fileName) => {
            const included = fs.readFileSync(srcDir + path.sep + fileName, 'utf8');
            return included+"\n\n"
        });
    
        data = data.replace(regexVer, '$1'+manifest.version);
        data = data.replace(regexScrVer, '$1'+manifest.version+'$3');
        data = data.replace(regexDate, '$1'+dateFormated+'$3');
    }
    fs.writeFileSync(baseDir + path.sep + 'install.sh', data);
} catch (err) {
    console.error(err);
}

fs.writeFileSync(baseDir + path.sep + 'updated', event.toISOString());
