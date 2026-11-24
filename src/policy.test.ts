import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isNetflixURL, isExternalURL, allowPermission, validWindowState } from './policy';

test('Netflix navigation accepts HTTPS Netflix hosts only', () => {
  for (const url of ['https://netflix.com/', 'https://www.netflix.com/browse', 'https://WWW.NETFLIX.COM:443/']) assert.ok(isNetflixURL(url));
  for (const url of ['', 'https://netflix.com.evil.com', 'https://evilnetflix.com', 'http://netflix.com', 'file:///tmp/a', 'javascript:alert(1)', 'https://netflix.com@evil.com', 'https://user:password@netflix.com', 'https://netflix.com:444']) assert.equal(isNetflixURL(url), false, url);
});
test('external links cannot launch arbitrary protocols', () => {
  assert.ok(isExternalURL('https://help.netflix.com/'));
  for (const url of ['file:///etc/passwd', 'javascript:alert(1)', 'intent://app', 'mailto:user@example.com']) assert.equal(isExternalURL(url), false);
});
test('DRM permission is restricted to Netflix; other permissions denied', () => {
  assert.ok(allowPermission('mediaKeySystem', 'https://www.netflix.com'));
  assert.equal(allowPermission('mediaKeySystem', 'https://example.com'), false);
  for (const permission of ['media', 'geolocation', 'notifications', 'clipboard-read', 'display-capture']) assert.equal(allowPermission(permission, 'https://netflix.com'), false);
});
test('corrupt or unreasonable geometry cannot prevent launch', () => {
  assert.deepEqual(validWindowState(null), { width: 1280, height: 800 });
  assert.deepEqual(validWindowState({ width: 'oops', height: 600 }), { width: 1280, height: 800 });
  assert.equal(validWindowState({ width: -1, height: 999999 }).width, 800);
  assert.equal(validWindowState({ width: 800, height: 999999 }).height, 2160);
});
