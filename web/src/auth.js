import { apiFetch } from "./api.js";
import { AUTH_TOKEN_KEY, AUTH_USER_KEY, state } from "./state.js";
import { els } from "./dom.js";

let callbacks = {
  renderCustomerList: () => {},
  renderCustomerDetail: () => {},
  renderGlobalChat: () => {},
  showToast: () => {},
  loadCustomers: async () => {},
};

export function configureAuth(nextCallbacks) {
  callbacks = { ...callbacks, ...nextCallbacks };
}

export function saveAuthSession(token, user) {
  state.authToken = token;
  state.currentUser = user;
  localStorage.setItem(AUTH_TOKEN_KEY, token);
  localStorage.setItem(AUTH_USER_KEY, JSON.stringify(user));
}

export function clearAuthSession() {
  state.authToken = "";
  state.currentUser = null;
  state.customers = [];
  state.selectedCustomerId = null;
  state.customerDetail = null;
  state.records = [];
  state.adviceText = "";
  state.adviceUpdatedAt = "";
  state.globalMessages = [];
  state.globalSearchHistory = [];
  state.globalPendingAnswerLines = [];
  state.globalPendingAnswerIndex = 0;
  state.globalSuggestionsHidden = false;
  localStorage.removeItem(AUTH_TOKEN_KEY);
  localStorage.removeItem(AUTH_USER_KEY);
}

export function setAuthMode(mode) {
  const isLogin = mode !== "register";
  els.authTitle.textContent = isLogin ? "登录工作台" : "创建新账号";
  els.loginForm.classList.toggle("hidden", !isLogin);
  els.registerForm.classList.toggle("hidden", isLogin);
  els.showLogin.classList.toggle("active", isLogin);
  els.showRegister.classList.toggle("active", !isLogin);
}

export function renderAuthState() {
  const loggedIn = Boolean(state.authToken && state.currentUser);
  els.authScreen.classList.toggle("hidden", loggedIn);
  els.authStatus.classList.toggle("hidden", !loggedIn);

  if (loggedIn) {
    els.authUserName.textContent = state.currentUser.name || "未命名用户";
    els.authUserAccount.textContent = state.currentUser.account || "";
  } else {
    els.authUserName.textContent = "未登录";
    els.authUserAccount.textContent = "";
    callbacks.renderCustomerList();
    callbacks.renderCustomerDetail();
    callbacks.renderGlobalChat();
  }
}

export async function restoreSession() {
  if (!state.authToken) {
    renderAuthState();
    return false;
  }

  try {
    const user = await apiFetch("/auth/me");
    saveAuthSession(state.authToken, user);
    renderAuthState();
    return true;
  } catch (error) {
    clearAuthSession();
    renderAuthState();
    callbacks.showToast(error.message || "登录状态已失效，请重新登录");
    return false;
  }
}

export async function submitLogin(formData) {
  els.loginSubmit.disabled = true;
  els.loginSubmit.textContent = "登录中...";
  try {
    const result = await apiFetch("/auth/login", {
      method: "POST",
      body: {
        account: String(formData.get("account") || "").trim(),
        password: String(formData.get("password") || ""),
      },
    });
    saveAuthSession(result.token, result.user);
    renderAuthState();
    await callbacks.loadCustomers();
    callbacks.showToast("登录成功");
  } finally {
    els.loginSubmit.disabled = false;
    els.loginSubmit.textContent = "登录";
  }
}

export async function submitRegister(formData) {
  els.registerSubmit.disabled = true;
  els.registerSubmit.textContent = "创建中...";
  try {
    const result = await apiFetch("/auth/register", {
      method: "POST",
      body: {
        account: String(formData.get("account") || "").trim(),
        password: String(formData.get("password") || ""),
        name: String(formData.get("name") || "").trim() || undefined,
      },
    });
    saveAuthSession(result.token, result.user);
    renderAuthState();
    await callbacks.loadCustomers();
    callbacks.showToast("账号已创建");
  } finally {
    els.registerSubmit.disabled = false;
    els.registerSubmit.textContent = "创建账号并登录";
  }
}
