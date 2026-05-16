import { DEFAULT_API_BASE_URL, STORAGE_KEY, state } from "./state.js";

let unauthorizedHandler = () => {};

export function setUnauthorizedHandler(handler) {
  unauthorizedHandler = typeof handler === "function" ? handler : () => {};
}

export function buildUrl(path, query = {}) {
  const normalizedBase = state.apiBaseUrl.replace(/\/$/, "");
  const normalizedPath = path.startsWith("/") ? path : `/${path}`;
  const url = new URL(`${normalizedBase}${normalizedPath}`);

  Object.entries(query).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== "") {
      url.searchParams.set(key, String(value));
    }
  });

  return url.toString();
}

function isStaleLocalApiBaseUrl(apiBaseUrl) {
  try {
    const url = new URL(apiBaseUrl);
    return (
      url.pathname.replace(/\/$/, "") === "/api/v1" &&
      ["8000", "8001"].includes(url.port) &&
      ["127.0.0.1", "localhost", "0.0.0.0", window.location.hostname].includes(
        url.hostname
      )
    );
  } catch {
    return false;
  }
}

function switchToDefaultApiBaseUrl() {
  if (!isStaleLocalApiBaseUrl(state.apiBaseUrl)) return false;
  if (
    state.apiBaseUrl.replace(/\/$/, "") ===
    DEFAULT_API_BASE_URL.replace(/\/$/, "")
  ) {
    return false;
  }
  state.apiBaseUrl = DEFAULT_API_BASE_URL;
  localStorage.setItem(STORAGE_KEY, DEFAULT_API_BASE_URL);
  return true;
}

async function fetchWithApiRecovery(path, requestInit, query) {
  try {
    return await fetch(buildUrl(path, query), requestInit);
  } catch (error) {
    if (!switchToDefaultApiBaseUrl()) {
      throw error;
    }
    return fetch(buildUrl(path, query), requestInit);
  }
}

export async function apiFetch(path, options = {}) {
  let response = await fetchWithApiRecovery(path, {
    method: options.method || "GET",
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-cache, no-store, must-revalidate",
      "Pragma": "no-cache",
      ...(state.authToken ? { Authorization: `Bearer ${state.authToken}` } : {}),
      ...(options.headers || {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  }, options.query);

  let payload = await response.json().catch(() => null);

  if (
    (!response.ok || !payload?.success) &&
    isStaleLocalApiBaseUrl(state.apiBaseUrl) &&
    switchToDefaultApiBaseUrl()
  ) {
    response = await fetch(buildUrl(path, options.query), {
      method: options.method || "GET",
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "no-cache, no-store, must-revalidate",
        "Pragma": "no-cache",
        ...(state.authToken ? { Authorization: `Bearer ${state.authToken}` } : {}),
        ...(options.headers || {}),
      },
      body: options.body ? JSON.stringify(options.body) : undefined,
    });
    payload = await response.json().catch(() => null);
  }

  if (!response.ok || !payload?.success) {
    const message =
      payload?.error?.message ||
      payload?.message ||
      `请求失败 (${response.status})`;
    if (response.status === 401) {
      unauthorizedHandler();
    }
    throw new Error(message);
  }

  return payload.data;
}

export async function apiFetchForm(path, formData, options = {}) {
  const buildRequest = () => ({
    method: options.method || "POST",
    headers: {
      ...(state.authToken ? { Authorization: `Bearer ${state.authToken}` } : {}),
      ...(options.headers || {}),
    },
    body: formData,
  });
  let response = await fetchWithApiRecovery(path, buildRequest(), options.query);

  let payload = await response.json().catch(() => null);

  if (
    (!response.ok || !payload?.success) &&
    isStaleLocalApiBaseUrl(state.apiBaseUrl) &&
    switchToDefaultApiBaseUrl()
  ) {
    response = await fetch(buildUrl(path, options.query), buildRequest());
    payload = await response.json().catch(() => null);
  }

  if (!response.ok || !payload?.success) {
    const message =
      payload?.error?.message ||
      payload?.message ||
      `请求失败 (${response.status})`;
    if (response.status === 401) {
      unauthorizedHandler();
    }
    throw new Error(message);
  }

  return payload.data;
}

function getDownloadFilename(response, fallback) {
  const disposition = response.headers.get("Content-Disposition") || "";
  const encodedMatch = disposition.match(/filename\*=UTF-8''([^;]+)/i);
  if (encodedMatch?.[1]) {
    try {
      return decodeURIComponent(encodedMatch[1]);
    } catch {
      return encodedMatch[1];
    }
  }

  const asciiMatch = disposition.match(/filename="?([^";]+)"?/i);
  return asciiMatch?.[1] || fallback;
}

export async function apiDownload(path, options = {}) {
  const buildRequest = () => ({
    method: options.method || "GET",
    headers: {
      ...(state.authToken ? { Authorization: `Bearer ${state.authToken}` } : {}),
      ...(options.headers || {}),
    },
  });
  let response = await fetchWithApiRecovery(path, buildRequest(), options.query);

  if (!response.ok) {
    if (
      isStaleLocalApiBaseUrl(state.apiBaseUrl) &&
      switchToDefaultApiBaseUrl()
    ) {
      response = await fetch(buildUrl(path, options.query), buildRequest());
    }
  }

  if (!response.ok) {
    if (response.status === 401) {
      unauthorizedHandler();
    }
    const payload = await response.json().catch(() => null);
    const message =
      payload?.error?.message ||
      payload?.message ||
      `下载失败 (${response.status})`;
    throw new Error(message);
  }

  const blob = await response.blob();
  const filename = getDownloadFilename(response, options.filename || "download");
  const objectUrl = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = objectUrl;
  link.download = filename;
  document.body.append(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(objectUrl);
  return { filename };
}
