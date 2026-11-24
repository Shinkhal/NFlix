const { spawn } = require('node:child_process');
const path = require('node:path');
const env = { ...process.env };
delete env.ELECTRON_RUN_AS_NODE;
function launch(restarted = false) {
  const child = spawn(require('electron'), [path.resolve(__dirname, '..'), ...process.argv.slice(2)], { env, stdio: 'inherit' });
  child.on('error', error => { console.error(error.message); process.exitCode = 1; });
  child.on('exit', code => {
    if (code === 3 && !restarted && (process.argv.includes('--check-playback') || process.argv.includes('--smoke-test'))) launch(true);
    else process.exitCode = code ?? 1;
  });
}
launch();
