export const STORAGE_KEY = "brokerassist:web:api-base-url";
export const AUTH_TOKEN_KEY = "brokerassist:web:auth-token";
export const AUTH_USER_KEY = "brokerassist:web:auth-user";
export const GLOBAL_CHAT_CONTEXT_LIMIT = 16;
export const GLOBAL_CHAT_HISTORY_PREFIX = "brokerassist:web:global-chat:";
export const GLOBAL_SEARCH_HISTORY_PREFIX = "brokerassist:web:global-search:";

function getDefaultApiBaseUrl() {
  return `${window.location.origin}/api/v1`;
}

export const DEFAULT_API_BASE_URL = getDefaultApiBaseUrl();

function getInitialApiBaseUrl() {
  const stored = localStorage.getItem(STORAGE_KEY);
  if (!stored) {
    localStorage.setItem(STORAGE_KEY, DEFAULT_API_BASE_URL);
    return DEFAULT_API_BASE_URL;
  }
  const staleStaticServerDefault = `${window.location.origin}/api/v1`;
  const shouldReplaceStaleLocalDefault = (() => {
    if (stored.replace(/\/$/, "") === staleStaticServerDefault) return true;
    try {
      const url = new URL(stored);
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
  })();
  if (
    window.location.port === "4173" &&
    shouldReplaceStaleLocalDefault
  ) {
    localStorage.setItem(STORAGE_KEY, DEFAULT_API_BASE_URL);
    return DEFAULT_API_BASE_URL;
  }
  return stored;
}

export const state = {
  apiBaseUrl: getInitialApiBaseUrl(),
  authToken: localStorage.getItem(AUTH_TOKEN_KEY) || "",
  currentUser: JSON.parse(localStorage.getItem(AUTH_USER_KEY) || "null"),
  customers: [],
  selectedCustomerId: null,
  customerDetail: null,
  records: [],
  editingRecordId: null,
  editingRecordImages: [],
  selectedRecordFiles: [],
  adviceText: "",
  adviceUpdatedAt: "",
  globalMessages: [],
  globalChatFiles: [],
  globalSearchHistory: [],
  globalPendingAnswerLines: [],
  globalPendingAnswerIndex: 0,
  globalSuggestionsHidden: false,
  expandedRecordIds: new Set(),
  recordSaving: false,
  analyzingRecordImageKey: "",
  recordImageModes: {},
  expandedRecordAnalysisKeys: new Set(),
};
