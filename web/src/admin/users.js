import { buildUrl } from "../api.js";
import { state } from "../state.js";
import { showToast } from "./app.js";

let page = 1;
let search = "";
const pageSize = 20;

export async function loadUsers() {
  const container = document.getElementById("tab-users");
  container.innerHTML = `
    <div class="admin-toolbar">
      <label class="search-field"><input id="user-search" type="search" placeholder="搜索账号或昵称" value="${escapeHtml(search)}" /></label>
    </div>
    <div id="user-table-container"></div>
  `;

  document.getElementById("user-search").addEventListener("input", (e) => {
    search = e.target.value;
    page = 1;
    fetchUsers();
  });

  fetchUsers();
}

async function fetchUsers() {
  const container = document.getElementById("user-table-container");
  try {
    const params = new URLSearchParams({ page, page_size: pageSize, search });
    const res = await fetch(buildUrl(`/admin/users?${params}`), {
      headers: { Authorization: `Bearer ${state.authToken}` },
    });
    const payload = await res.json();
    if (!payload.success) throw new Error(payload.error?.message || "加载失败");
    const d = payload.data;
    container.innerHTML = `
      <table class="data-table">
        <thead>
          <tr>
            <th>账号</th><th>昵称</th><th>行业</th><th>客户数</th><th>管理员</th><th>状态</th><th>注册时间</th><th>操作</th>
          </tr>
        </thead>
        <tbody>
          ${d.items.map((u) => `
            <tr>
              <td>${escapeHtml(u.account)}</td>
              <td>${escapeHtml(u.name || "-")}</td>
              <td>${escapeHtml(u.industry_key)}</td>
              <td>${u.customer_count}</td>
              <td>${u.is_admin ? '<span class="badge badge-admin">管理员</span>' : "-"}</td>
              <td>${u.disabled
                ? '<span class="badge badge-disabled">已禁用</span>'
                : '<span class="badge badge-active">正常</span>'}</td>
              <td>${u.created_at ? u.created_at.slice(0, 10) : "-"}</td>
              <td>
                <button class="button button-small" data-action="reset-pw" data-uid="${u.id}">重置密码</button>
                <button class="button button-small" data-action="toggle-status" data-uid="${u.id}" data-disabled="${u.disabled}">
                  ${u.disabled ? "启用" : "禁用"}
                </button>
                <button class="button button-small" data-action="view-customers" data-uid="${u.id}">客户</button>
              </td>
            </tr>
          `).join("")}
        </tbody>
      </table>
      <div class="pagination">
        <button ${page <= 1 ? "disabled" : ""} id="prev-page">上一页</button>
        <span>第 ${d.page} 页 / 共 ${Math.ceil(d.total / pageSize)} 页 (${d.total} 条)</span>
        <button ${page * pageSize >= d.total ? "disabled" : ""} id="next-page">下一页</button>
      </div>
    `;

    document.getElementById("prev-page")?.addEventListener("click", () => { if (page > 1) { page--; fetchUsers(); } });
    document.getElementById("next-page")?.addEventListener("click", () => { page++; fetchUsers(); });

    container.querySelectorAll("[data-action]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const uid = btn.dataset.uid;
        if (btn.dataset.action === "reset-pw") await resetPassword(uid);
        else if (btn.dataset.action === "toggle-status") await toggleStatus(uid, btn.dataset.disabled === "true");
        else if (btn.dataset.action === "view-customers") await viewCustomers(uid);
      });
    });
  } catch (e) {
    container.innerHTML = `<p class="error">${e.message}</p>`;
  }
}

async function resetPassword(uid) {
  const pw = prompt("请输入新密码（至少3位）：");
  if (!pw) return;
  try {
    const res = await fetch(buildUrl(`/admin/users/${uid}/password`), {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${state.authToken}`,
      },
      body: JSON.stringify({ password: pw }),
    });
    const payload = await res.json();
    if (!payload.success) throw new Error(payload.error?.message || "操作失败");
    showToast("密码已重置");
  } catch (e) {
    showToast(e.message);
  }
}

async function toggleStatus(uid, currentlyDisabled) {
  try {
    const res = await fetch(buildUrl(`/admin/users/${uid}/status`), {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${state.authToken}`,
      },
      body: JSON.stringify({ disabled: !currentlyDisabled }),
    });
    const payload = await res.json();
    if (!payload.success) throw new Error(payload.error?.message || "操作失败");
    showToast(currentlyDisabled ? "已启用" : "已禁用");
    fetchUsers();
  } catch (e) {
    showToast(e.message);
  }
}

async function viewCustomers(uid) {
  try {
    const res = await fetch(buildUrl(`/admin/users/${uid}/customers`), {
      headers: { Authorization: `Bearer ${state.authToken}` },
    });
    const payload = await res.json();
    if (!payload.success) throw new Error(payload.error?.message || "加载失败");
    const customers = payload.data;
    const dialog = document.getElementById("admin-dialog");
    document.getElementById("admin-dialog-title").textContent = "用户客户列表";
    document.getElementById("admin-dialog-body").innerHTML = customers.length
      ? `<table class="data-table"><thead><tr><th>姓名</th><th>电话</th><th>创建时间</th></tr></thead><tbody>
          ${customers.map((c) => `<tr><td>${escapeHtml(c.name)}</td><td>${escapeHtml(c.phone || "-")}</td><td>${c.created_at ? c.created_at.slice(0, 10) : "-"}</td></tr>`).join("")}
        </tbody></table>`
      : "<p>暂无客户</p>";
    dialog.showModal();
    document.getElementById("admin-dialog-close").onclick = () => dialog.close();
  } catch (e) {
    showToast(e.message);
  }
}

function escapeHtml(s) {
  const div = document.createElement("div");
  div.textContent = String(s ?? "");
  return div.innerHTML;
}
