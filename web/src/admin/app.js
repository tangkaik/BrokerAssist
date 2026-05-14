import { state } from "../state.js";
import { loadDashboard } from "./dashboard.js";
import { loadUsers } from "./users.js";
import { loadConfig } from "./config.js";
import { loadIndustries } from "./industries.js";
import { loadPrompts } from "./prompts.js";

const navItems = document.querySelectorAll(".admin-nav-item");
const tabs = document.querySelectorAll(".admin-tab");
const toast = document.getElementById("admin-toast");
const userEl = document.getElementById("admin-user-name");
const logoutBtn = document.getElementById("admin-logout");

function showToast(msg) {
  toast.textContent = msg;
  toast.classList.remove("hidden");
  clearTimeout(showToast.timer);
  showToast.timer = setTimeout(() => toast.classList.add("hidden"), 2800);
}

function switchTab(name) {
  navItems.forEach((btn) => btn.classList.toggle("active", btn.dataset.tab === name));
  tabs.forEach((tab) => tab.classList.toggle("hidden", tab.id !== `tab-${name}`));
  if (name === "dashboard") loadDashboard();
  else if (name === "users") loadUsers();
  else if (name === "config") loadConfig();
  else if (name === "industries") loadIndustries();
  else if (name === "prompts") loadPrompts();
}

navItems.forEach((btn) => {
  btn.addEventListener("click", () => switchTab(btn.dataset.tab));
});

logoutBtn.addEventListener("click", () => {
  localStorage.removeItem("brokerassist:web:auth-token");
  localStorage.removeItem("brokerassist:web:auth-user");
  window.location.href = "./index.html";
});

function checkAdmin() {
  if (!state.authToken) {
    window.location.href = "./index.html";
    return false;
  }
  const user = state.currentUser;
  if (user) {
    userEl.textContent = user.name || user.account || "";
  }
  return true;
}

if (checkAdmin()) {
  loadDashboard();
}

export { showToast, checkAdmin };
