const fs = require('fs');
const regexDevRemove = /(\#dev\-begin.*?\#dev\-end)\n/mgs;
const regexInclude = /(#include\s+(\S+))/mgs;

try {
    let data = fs.readFileSync('setup.sh', 'utf8');
    data = data.replace(regexDevRemove, '');
    data = data.replace(regexInclude, (_, _2, fileName) => {
        const included = fs.readFileSync(fileName, 'utf8');
        return included
    });
    fs.writeFileSync('install.sh', data);
} catch (err) {
    console.error(err);
}