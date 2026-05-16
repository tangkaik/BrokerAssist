const TOKEN_KEY = "brokerassist:web:auth-token";
const API_KEY = "brokerassist:web:api-base-url";
export const ADMIN_ACCOUNT = "administrator";

export function getToken() {
  return localStorage.getItem(TOKEN_KEY) || "";
}

export function getApiBaseUrl() {
  return localStorage.getItem(API_KEY) || `${window.location.origin}/api/v1`;
}

export function buildAdminUrl(path, query = {}) {
  const base = getApiBaseUrl().replace(/\/$/, "");
  const url = new URL(`${base}${path.startsWith("/") ? path : `/${path}`}`);
  Object.entries(query).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== "") {
      url.searchParams.set(key, String(value));
    }
  });
  return url.toString();
}

export async function adminFetch(path, options = {}) {
  const response = await fetch(buildAdminUrl(path, options.query), {
    method: options.method || "GET",
    headers: {
      "Content-Type": "application/json",
      ...(getToken() ? { Authorization: `Bearer ${getToken()}` } : {}),
      ...(options.headers || {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });
  const payload = await response.json().catch(() => null);
  if (!response.ok || !payload?.success) {
    throw new Error(payload?.error?.message || `请求失败 (${response.status})`);
  }
  return payload.data;
}
