const fs = require('fs');
const path = require('path');
const regexDevRemove = /(\#dev\-begin.*?\#dev\-end)\n/mgs;
const regexInclude = /(#include\s+(\S+))/mgs;

const srcDir = fs.realpathSync(__dirname + path.sep + '..' + path.sep + 'src')
const baseDir = fs.realpathSync(__dirname + path.sep + '..' )

try {
    let data = fs.readFileSync(srcDir + path.sep + 'setup.sh', 'utf8');
    data = data.replace(regexDevRemove, '');
    data = data.replace(regexInclude, (_, _2, fileName) => {
        const included = fs.readFileSync(srcDir + path.sep + fileName, 'utf8');
        return included
    });
    fs.writeFileSync(baseDir + path.sep + 'install.sh', data);
} catch (err) {
    console.error(err);
}

const event = new Date();
fs.writeFileSync(baseDir + path.sep + 'updated', event.toISOString());
