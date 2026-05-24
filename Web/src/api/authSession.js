const ADMIN_SESSION_TTL_MS = 15 * 60 * 1000;
const ADMIN_SESSION_EXPIRES_AT_KEY = 'adminSessionExpiresAt';
const ADMIN_2FA_VERIFIED_KEY = 'admin2FAVerified';

export function saveAdminSession(userData) {
  const expiresAt = Date.now() + ADMIN_SESSION_TTL_MS;

  localStorage.setItem('accessToken', userData?.accessToken || '');
  localStorage.setItem('refreshToken', userData?.refreshToken || '');
  localStorage.setItem('userRole', userData?.role || 'admin');
  localStorage.setItem(ADMIN_SESSION_EXPIRES_AT_KEY, String(expiresAt));
  localStorage.setItem(ADMIN_2FA_VERIFIED_KEY, 'true');
}

export function clearAdminSession() {
  localStorage.removeItem('accessToken');
  localStorage.removeItem('refreshToken');
  localStorage.removeItem('userRole');
  localStorage.removeItem(ADMIN_SESSION_EXPIRES_AT_KEY);
  localStorage.removeItem(ADMIN_2FA_VERIFIED_KEY);
}

export function isAdminSessionActive() {
  const token = localStorage.getItem('accessToken');
  const expiresAt = Number(localStorage.getItem(ADMIN_SESSION_EXPIRES_AT_KEY));
  const is2FAVerified = localStorage.getItem(ADMIN_2FA_VERIFIED_KEY) === 'true';

  if (!token || !expiresAt || !is2FAVerified || Date.now() >= expiresAt) {
    clearAdminSession();
    return false;
  }

  return true;
}

export function getAdminAccessToken() {
  return isAdminSessionActive() ? localStorage.getItem('accessToken') : null;
}
