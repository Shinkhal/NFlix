const { readFileSync, writeFileSync, statSync } = require('node:fs');
const { createHash } = require('node:crypto');
const { version } = require('../package.json');
const arch = process.arch;
const names = arch === 'x64'
  ? [`nflix-desktop-${version}-x86_64.AppImage`, `nflix-desktop-${version}-x64.tar.gz`,
     `nflix-desktop-${version}-amd64.deb`, `nflix-desktop-${version}-x86_64.rpm`]
  : (() => { throw new Error('Release validation currently supports x86_64 only'); })();
for (const name of names) {
  const file = 'release/' + name;
  if (!statSync(file).isFile() || statSync(file).size < 1024) throw new Error('Missing/empty artifact: ' + name);
  const hash = createHash('sha256').update(readFileSync(file)).digest('hex');
  writeFileSync(file + '.sha256', hash + '  ' + name + '\n');
  console.log('Verified artifact:', name);
}
