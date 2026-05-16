import { ADMIN_ACCOUNT, adminFetch, getToken } from "./api.js";
import { loadIndustryAdmin } from "./industries.js";
import { loadUserMaintenance, loadUserOverview } from "./users.js";

export const adminEls = {
  app: document.querySelector("#admin-app"),
  blocked: document.querySelector("#admin-blocked"),
  blockedMessage: document.querySelector("#admin-blocked-message"),
  status: document.querySelector("#admin-status"),
  tabButtons: Array.from(document.querySelectorAll("[data-admin-tab]")),
  panels: {
    overview: document.querySelector("#admin-tab-overview"),
    maintenance: document.querySelector("#admin-tab-maintenance"),
    industries: document.querySelector("#admin-tab-industries"),
  },
  dialog: document.querySelector("#admin-dialog"),
  dialogTitle: document.querySelector("#admin-dialog-title"),
  dialogBody: document.querySelector("#admin-dialog-body"),
  dialogClose: document.querySelector("#admin-dialog-close"),
  toast: document.querySelector("#admin-toast"),
};

let toastTimer;

export function escapeHtml(text) {
  return String(text ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

export function formatDate(value) {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "-";
  return date.toLocaleString("zh-CN", { hour12: false });
}

export function showToast(message) {
  adminEls.toast.textContent = message;
  adminEls.toast.classList.remove("hidden");
  window.clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => adminEls.toast.classList.add("hidden"), 2600);
}

export function openDialog(title, bodyHtml) {
  adminEls.dialogTitle.textContent = title;
  adminEls.dialogBody.innerHTML = bodyHtml;
  adminEls.dialog.showModal();
}

export function closeDialog() {
  adminEls.dialog.close();
  adminEls.dialogBody.innerHTML = "";
}

function setActiveTab(tabName) {
  adminEls.tabButtons.forEach((button) => {
    button.classList.toggle("active", button.dataset.adminTab === tabName);
  });
  Object.entries(adminEls.panels).forEach(([name, panel]) => {
    panel.classList.toggle("hidden", name !== tabName);
  });
}

async function loadTab(tabName) {
  setActiveTab(tabName);
  if (tabName === "overview") {
    await loadUserOverview();
  } else if (tabName === "maintenance") {
    await loadUserMaintenance();
  } else if (tabName === "industries") {
    await loadIndustryAdmin();
  }
}

async function bootstrap() {
  if (!getToken()) {
    adminEls.blockedMessage.textContent = "请先登录普通 Web 工作台，再访问管理后台。";
    adminEls.status.textContent = "未登录";
    return;
  }

  try {
    const user = await adminFetch("/auth/me");
    if ((user.account || "").toLowerCase() !== ADMIN_ACCOUNT) {
      adminEls.blockedMessage.textContent = "当前账号没有管理后台权限。";
      adminEls.status.textContent = `当前账号：${user.account || "-"}`;
      return;
    }

    adminEls.blocked.classList.add("hidden");
    adminEls.app.classList.remove("hidden");
    adminEls.status.textContent = `管理员：${user.account}`;
    await loadTab("overview");
  } catch (error) {
    adminEls.blockedMessage.textContent = error.message || "无法进入管理后台。";
    adminEls.status.textContent = "权限检查失败";
  }
}

adminEls.tabButtons.forEach((button) => {
  button.addEventListener("click", async () => {
    try {
      await loadTab(button.dataset.adminTab);
    } catch (error) {
      showToast(error.message);
    }
  });
});

adminEls.dialogClose.addEventListener("click", closeDialog);
adminEls.dialog.addEventListener("click", (event) => {
  if (event.target === adminEls.dialog) closeDialog();
});

bootstrap();
