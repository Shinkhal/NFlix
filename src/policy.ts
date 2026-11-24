export function isNetflixURL(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && !url.username && !url.password
      && (url.port === '' || url.port === '443')
      && (url.hostname === 'netflix.com' || url.hostname.endsWith('.netflix.com'));
  } catch { return false; }
}

export function isExternalURL(value: string): boolean {
  try { return ['http:', 'https:'].includes(new URL(value).protocol); }
  catch { return false; }
}

export function allowPermission(permission: string, origin: string): boolean {
  return permission === 'mediaKeySystem' && isNetflixURL(origin);
}

export interface WindowState { x?: number; y?: number; width: number; height: number; maximized?: boolean }
export function validWindowState(value: unknown): WindowState {
  const fallback = { width: 1280, height: 800 };
  if (!value || typeof value !== 'object') return fallback;
  const v = value as Record<string, unknown>;
  if (![v.width, v.height].every(n => typeof n === 'number' && Number.isInteger(n))) return fallback;
  return {
    width: Math.min(3840, Math.max(800, v.width as number)),
    height: Math.min(2160, Math.max(600, v.height as number)),
    ...(typeof v.x === 'number' && Number.isInteger(v.x) ? { x: v.x } : {}),
    ...(typeof v.y === 'number' && Number.isInteger(v.y) ? { y: v.y } : {}),
    maximized: v.maximized === true,
  };
}
