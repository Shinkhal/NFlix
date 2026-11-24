import { app, BrowserWindow, components, dialog, Menu, screen, session, shell } from 'electron';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { allowPermission, isExternalURL, isNetflixURL, validWindowState, WindowState } from './policy';

const HOME = 'https://www.netflix.com/';
const checkOnly = process.argv.includes('--check-playback');
const smokeTest = process.argv.includes('--smoke-test');
app.setName('nflix-desktop');
app.setDesktopName('io.github.nflixdesktop.desktop');
if (app.commandLine.hasSwitch('no-sandbox') || app.commandLine.hasSwitch('disable-seccomp-filter-sandbox')) {
  console.error('Nflix Desktop requires Chromium sandboxing. Use a system with working user namespaces or a properly installed sandbox helper.');
  app.exit(1);
}
app.enableSandbox();
// Keep the former Qt profile intact. No cookie databases are copied across engines.
const userData = process.env.NFLIX_USER_DATA || path.join(app.getPath('appData'), 'nflix-desktop');
app.setPath('userData', userData);
mkdirSync(userData, { recursive: true });
const stateFile = path.join(userData, 'window.json');
const reportFile = path.join(userData, 'playback-diagnostics.json');
const cdmMarker = path.join(userData, 'widevine-ready.json');
const probePage = path.join(__dirname, '..', 'assets', 'probe.html');
let window: BrowserWindow | undefined;
let mini = false;
let normalBounds: Electron.Rectangle | undefined;
let probeContentsId: number | undefined;
let quitting = false;
let scrollbarStyleKey: string | undefined;

interface Capabilities {
  h264: string;
  aac: string;
  vp9: string;
  widevine: string;
}
const probeScript = `(async () => {
  const video = document.createElement('video');
  const result = {
    h264: video.canPlayType('video/mp4; codecs="avc1.42E01E"'),
    aac: video.canPlayType('audio/mp4; codecs="mp4a.40.2"'),
    vp9: video.canPlayType('video/webm; codecs="vp9"'),
    widevine: 'unavailable'
  };
  try {
    await navigator.requestMediaKeySystemAccess('com.widevine.alpha', [{
      initDataTypes: ['cenc'],
      audioCapabilities: [{contentType: 'audio/mp4; codecs="mp4a.40.2"'}],
      videoCapabilities: [{contentType: 'video/mp4; codecs="avc1.42E01E"'}]
    }]);
    result.widevine = 'available';
  } catch (error) { result.widevine = error.name; }
  return result;
})()`;

function bounded<T>(promise: Promise<T>, milliseconds: number, message: string): Promise<T> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(message)), milliseconds);
    promise.then(value => { clearTimeout(timer); resolve(value); }, error => { clearTimeout(timer); reject(error); });
  });
}

function saveReport(report: Record<string, unknown>): void {
  const data = {
    checkedAt: new Date().toISOString(),
    appVersion: app.getVersion(),
    electron: process.versions.electron,
    chromium: process.versions.chrome,
    platform: process.platform,
    arch: process.arch,
    ...report,
    netflixPlaybackVerified: false,
  };
  writeFileSync(reportFile, JSON.stringify(data, null, 2), { mode: 0o600 });
  console.log(JSON.stringify(data));
}

async function probe(): Promise<Capabilities> {
  const view = new BrowserWindow({
    show: false,
    webPreferences: { sandbox: true, contextIsolation: true, nodeIntegration: false, partition: 'capability-probe' },
  });
  probeContentsId = view.webContents.id;
  view.webContents.session.setPermissionCheckHandler((contents, permission) =>
    contents?.id === probeContentsId && permission === 'mediaKeySystem');
  view.webContents.session.setPermissionRequestHandler((contents, permission, callback) =>
    callback(contents.id === probeContentsId && permission === 'mediaKeySystem'));
  try {
    await bounded(view.loadFile(probePage), 15000, 'Capability page did not load');
    return await bounded(view.webContents.executeJavaScript(probeScript), 20000, 'Capability check timed out');
  } finally {
    probeContentsId = undefined;
    view.destroy();
  }
}

function configureSession(): void {
  const webSession = session.defaultSession;
  webSession.setPermissionCheckHandler((_contents, permission, origin) => allowPermission(permission, origin));
  webSession.setPermissionRequestHandler((contents, permission, callback, details) =>
    callback(allowPermission(permission, details.requestingUrl || contents.getURL())));
  webSession.on('will-download', event => event.preventDefault());
}

function readState(): WindowState {
  try { return validWindowState(JSON.parse(readFileSync(stateFile, 'utf8'))); }
  catch { return validWindowState(null); }
}

function toggleMini(): void {
  if (!window) return;
  mini = !mini;
  if (mini) {
    normalBounds = window.getBounds();
    window.setFullScreen(false);
    window.unmaximize();
    window.setMinimumSize(400, 225);
    window.setSize(640, 360);
  } else {
    window.setMinimumSize(800, 600);
    if (normalBounds) window.setBounds(normalBounds);
  }
  window.setAlwaysOnTop(mini);
}

async function runPlaybackCommand(command: 'volume-up' | 'volume-down' | 'fullscreen'): Promise<void> {
  if (!window || window.isDestroyed()) return;
  const script = `(async () => {
    const video = document.querySelector('video');
    if (!video) return false;
    if (${JSON.stringify(command)} === 'volume-up' || ${JSON.stringify(command)} === 'volume-down') {
      const direction = ${JSON.stringify(command)} === 'volume-up' ? 1 : -1;
      video.muted = false;
      video.volume = Math.min(1, Math.max(0, video.volume + direction * 0.1));
      return true;
    }
    if (document.fullscreenElement) {
      await document.exitFullscreen();
    } else {
      await (video.closest('[class*="watch-video"]') || video).requestFullscreen();
    }
    return true;
  })()`;
  try { await window.webContents.executeJavaScript(script, true); } catch { /* Netflix may replace the player during navigation. */ }
}

async function hideScrollbars(): Promise<void> {
  if (!window || window.isDestroyed()) return;
  if (scrollbarStyleKey) {
    try { await window.webContents.removeInsertedCSS(scrollbarStyleKey); } catch { /* page may have gone away */ }
  }
  scrollbarStyleKey = await window.webContents.insertCSS(`
    html, body, * { scrollbar-width: none !important; }
    html::-webkit-scrollbar, body::-webkit-scrollbar, *::-webkit-scrollbar {
      width: 0 !important; height: 0 !important; display: none !important;
    }
  `);
}

async function openExternal(url: string): Promise<void> {
  if (!isExternalURL(url) || !window) return;
  const answer = await dialog.showMessageBox(window, {
    type: 'question', message: 'Open this link in your browser?',
    detail: new URL(url).origin, buttons: ['Cancel', 'Open browser'], defaultId: 0, cancelId: 0,
  });
  if (answer.response === 1) await shell.openExternal(url);
}

function createWindow(): BrowserWindow {
  const state = readState();
  // Restore a position only if it still intersects a connected display.
  if (typeof state.x === 'number' && typeof state.y === 'number') {
    const visible = screen.getAllDisplays().some(({ workArea: a }) =>
      state.x! + state.width > a.x && state.y! + state.height > a.y &&
      state.x! < a.x + a.width && state.y! < a.y + a.height);
    if (!visible) { delete state.x; delete state.y; }
  }
  const win = new BrowserWindow({
    ...state, minWidth: 800, minHeight: 600, show: false,
    title: 'Nflix Desktop', backgroundColor: '#141414',
    icon: path.join(__dirname, '..', 'assets', 'icon-512.png'),
    autoHideMenuBar: true,
    webPreferences: { sandbox: true, contextIsolation: true, nodeIntegration: false, webSecurity: true },
  });
  win.once('ready-to-show', () => { win.show(); if (state.maximized) win.maximize(); });
  win.on('page-title-updated', event => { event.preventDefault(); win.setTitle('Nflix Desktop'); });
  win.webContents.on('did-finish-load', () => { void hideScrollbars(); });
  const navigate = (event: Electron.Event, url: string) => {
    if (!isNetflixURL(url)) event.preventDefault();
  };
  win.webContents.on('will-navigate', (event, url) => {
    if (!isNetflixURL(url)) { event.preventDefault(); void openExternal(url); }
  });
  win.webContents.on('will-redirect', navigate);
  win.webContents.on('will-attach-webview', event => event.preventDefault());
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (isNetflixURL(url)) void win.loadURL(url).catch(() => {});
    else void openExternal(url);
    return { action: 'deny' };
  });
  win.webContents.on('before-input-event', (event, input) => {
    if (input.type !== 'keyDown') return;
    if (input.control && input.shift && input.key.toLowerCase() === 'p') { event.preventDefault(); toggleMini(); }
    if (input.key === 'F11' || (input.control && input.shift && input.key.toLowerCase() === 'f')) {
      event.preventDefault();
      win.setFullScreen(!win.isFullScreen());
    }
    if (input.key === 'Escape' && win.isFullScreen()) win.setFullScreen(false);
    if (input.key === 'ArrowUp' || input.key === 'ArrowDown') {
      event.preventDefault();
      void runPlaybackCommand(input.key === 'ArrowUp' ? 'volume-up' : 'volume-down');
    }
  });
  win.webContents.on('render-process-gone', (_event, details) => {
    if (!quitting) dialog.showErrorBox('Nflix Desktop', 'The page stopped responding (' + details.reason + '). Restart Nflix Desktop to try again.');
  });
  win.on('close', () => {
    const bounds = mini && normalBounds ? normalBounds : win.getNormalBounds();
    writeFileSync(stateFile, JSON.stringify({ ...bounds, maximized: win.isMaximized() }), { mode: 0o600 });
  });
  win.on('closed', () => { window = undefined; });
  Menu.setApplicationMenu(Menu.buildFromTemplate([
    { label: 'Nflix Desktop', submenu: [
      { label: 'Netflix Home', accelerator: 'Alt+Home', click: () => { void win.loadURL(HOME).catch(() => {}); } },
      { role: 'reload' },
      { label: 'Compact window', click: toggleMini },
      { role: 'togglefullscreen' },
      { type: 'separator' },
      { label: 'Playback diagnostics', click: () => { void shell.openPath(reportFile); } },
      { role: 'quit' },
    ] },
  ]));
  return win;
}

async function start(): Promise<void> {
  configureSession();
  if (!checkOnly) {
    window = createWindow();
    await window.loadFile(probePage);
  }
  const ready = await bounded(components.whenReady([components.WIDEVINE_CDM_ID]), 120000,
    'Widevine could not be prepared within two minutes. Check your connection and restart.');
  const cdm = ready.find(component => component.id === components.WIDEVINE_CDM_ID);
  if (!cdm?.version) throw new Error('Widevine did not report an installed version.');
  // ECS documents a Linux restart after first installation. Persist the observed
  // version before restarting, so a broken component can never create a loop.
  let previous: string | undefined;
  try { previous = JSON.parse(readFileSync(cdmMarker, 'utf8')).version; } catch {}
  if (process.platform === 'linux' && previous !== cdm.version) {
    writeFileSync(cdmMarker, JSON.stringify({ version: cdm.version }), { mode: 0o600 });
    console.log('Widevine installed/updated; restarting once to activate it.');
    if (checkOnly || smokeTest) { app.exit(3); return; }
    app.relaunch();
    app.quit();
    return;
  }
  const capabilities = await probe();
  saveReport({ widevineVersion: cdm.version, capabilities });
  const supported = Boolean(capabilities.h264 && capabilities.aac && capabilities.widevine === 'available');
  if (checkOnly) { app.exit(supported ? 0 : 1); return; }
  if (!supported) throw new Error('This runtime did not pass the H.264, AAC and Widevine checks. See Playback diagnostics in the menu.');
  if (window && !window.isDestroyed()) {
    await window.loadURL(HOME);
    if (smokeTest) {
      await new Promise(resolve => setTimeout(resolve, 2000));
      // Electron exposes this diagnostic at runtime but omits it from public typings.
      const preferences = (window.webContents as Electron.WebContents & {
        getLastWebPreferences(): Electron.WebPreferences;
      }).getLastWebPreferences();
      if (!preferences.sandbox || preferences.nodeIntegration || !preferences.contextIsolation) {
        throw new Error('Unsafe renderer preferences');
      }
      writeFileSync(path.join(userData, 'startup.png'), (await window.webContents.capturePage()).toPNG());
      console.log(JSON.stringify({ smokeTest: 'passed', origin: new URL(window.webContents.getURL()).origin,
        sandbox: preferences.sandbox, contextIsolation: preferences.contextIsolation, nodeIntegration: preferences.nodeIntegration }));
      app.exit(0);
    }
  }
}

app.on('before-quit', () => { quitting = true; });
app.on('window-all-closed', () => app.quit());
if (!app.requestSingleInstanceLock()) {
  if (checkOnly || smokeTest) {
    console.error('Close the running app or use NFLIX_USER_DATA with a separate profile before testing.');
    app.exit(2);
  } else app.quit();
} else {
  app.on('second-instance', () => { window?.restore(); window?.show(); window?.focus(); });
  void app.whenReady().then(start).catch(error => {
    saveReport({ error: error instanceof Error ? error.message : 'Playback initialization failed' });
    if (checkOnly || smokeTest) { app.exit(2); return; }
    dialog.showErrorBox('Nflix Desktop could not start playback', String(error instanceof Error ? error.message : error));
    app.quit();
  });
}
