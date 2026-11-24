// ECS downloads lazily on require(); CI must do this before electronDist is copied.
const fs = require('node:fs');
const path = require('node:path');
const executable = require('electron');
const expected = require('electron/package.json').version;
const runtime = fs.readFileSync(path.join(path.dirname(executable), 'version'), 'utf8').trim();
if (!expected.endsWith('+wvcus') || runtime !== expected) {
  throw new Error('The installed runtime is not the pinned Castlabs Electron distribution');
}
console.log('Castlabs runtime ready:', runtime);
