"""Probe the selected Python runtime's codecs and DRM without using account data.

Run with the app's Python in a graphical session. This tests capabilities,
not Netflix playback or service acceptance.
"""

import os
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import nflix_desktop  # Runs the same CDM discovery as the app, before WebEngine.
import PySide6
from PySide6.QtCore import QTimer, QUrl, qVersion
from PySide6.QtWidgets import QApplication
from PySide6.QtWebEngineCore import QWebEnginePage
print("Runtime:", PySide6.__version__, "Qt:", qVersion(), flush=True)
print("Chromium flags:", os.environ.get("QTWEBENGINE_CHROMIUM_FLAGS", ""), flush=True)
app = QApplication([])
exit_code = 2
class Page(QWebEnginePage):
    def javaScriptConsoleMessage(self, level, message, line, source):
        if message.startswith('PROBE:'):
            global exit_code
            import json
            result = json.loads(message[6:])
            exit_code = 0 if (result.get('h264') and result.get('aac')
                              and result.get('h264Widevine') == 'available') else 1
            print(message, flush=True)
            app.quit()
p = Page()
def loaded(ok):
    if not ok:
        app.quit()
        return
    p.runJavaScript('''(async () => {
      const v = document.createElement('video');
      const result = {vp9:v.canPlayType('video/webm; codecs="vp9"'), h264:v.canPlayType('video/mp4; codecs="avc1.42E01E"'), aac:v.canPlayType('audio/mp4; codecs="mp4a.40.2"'), eme:!!navigator.requestMediaKeySystemAccess};
      for (const [name, type] of Object.entries({vp9:'video/webm; codecs="vp9"', h264:'video/mp4; codecs="avc1.42E01E"'})) {
        try { await navigator.requestMediaKeySystemAccess('com.widevine.alpha', [{initDataTypes:[name === 'vp9' ? 'webm' : 'cenc'], videoCapabilities:[{contentType:type}]}]); result[name+'Widevine']='available'; }
        catch(e) { result[name+'Widevine']=e.name+': '+e.message; }
      }
      console.log('PROBE:'+JSON.stringify(result));
    })()''')
p.loadFinished.connect(loaded)
p.setHtml('<html><body>Media capability probe</body></html>', QUrl('https://www.netflix.com/'))
def timed_out():
    print("Capability probe timed out", flush=True)
    app.quit()

QTimer.singleShot(20000, timed_out)
app.exec()
raise SystemExit(exit_code)
