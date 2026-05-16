import { adminFetch } from "./api.js";
import { adminEls, escapeHtml, formatDate, openDialog, closeDialog, showToast } from "./app.js";

function renderStats(stats) {
  return `
    <div class="admin-stat-grid">
      <article class="content-card admin-stat-card">
        <strong>${stats.total_users || 0}</strong>
        <span>注册用户</span>
      </article>
      <article class="content-card admin-stat-card">
        <strong>${stats.total_customers || 0}</strong>
        <span>客户总数</span>
      </article>
    </div>
  `;
}

function renderUserTable(users, { maintenance = false } = {}) {
  if (!users.length) {
    return `<div class="empty-state"><h3>没有找到用户</h3><p>可以换个关键词再试。</p></div>`;
  }

  return `
    <div class="admin-table-wrap">
      <table class="admin-table">
        <thead>
          <tr>
            <th>账号</th>
            <th>昵称</th>
            <th>行业</th>
            <th>客户数</th>
            <th>注册时间</th>
            <th>操作</th>
          </tr>
        </thead>
        <tbody>
          ${users
            .map(
              (user) => `
                <tr>
                  <td>${escapeHtml(user.account)}</td>
                  <td>${escapeHtml(user.name || "-")}</td>
                  <td>${escapeHtml(user.industry_key || "generic")}</td>
                  <td>${user.customer_count || 0}</td>
                  <td>${formatDate(user.created_at)}</td>
                  <td class="admin-row-actions">
                    <button type="button" class="button button-secondary" data-view-customers="${escapeHtml(user.id)}">客户</button>
                    ${
                      maintenance
                        ? `<button type="button" class="button button-ghost" data-reset-password="${escapeHtml(user.id)}" data-user-account="${escapeHtml(user.account)}">重置密码</button>`
                        : ""
                    }
                  </td>
                </tr>
              `,
            )
            .join("")}
        </tbody>
      </table>
    </div>
  `;
}

async function fetchUsers(keyword = "") {
  const data = await adminFetch("/admin/users", { query: { keyword } });
  return data.items || [];
}

async function showUserCustomers(userId) {
  const data = await adminFetch(`/admin/users/${userId}/customers`);
  const customers = data.items || [];
  const body = customers.length
    ? `
      <div class="admin-table-wrap">
        <table class="admin-table">
          <thead><tr><th>姓名</th><th>电话</th><th>标签</th><th>更新时间</th></tr></thead>
          <tbody>
            ${customers
              .map(
                (customer) => `
                  <tr>
                    <td>${escapeHtml(customer.name)}</td>
                    <td>${escapeHtml(customer.phone || "-")}</td>
                    <td>${escapeHtml((customer.tags || []).join("、") || "-")}</td>
                    <td>${formatDate(customer.updated_at)}</td>
                  </tr>
                `,
              )
              .join("")}
          </tbody>
        </table>
      </div>
    `
    : `<p class="muted">这个用户还没有客户。</p>`;
  openDialog("用户客户列表", body);
}

function bindUserTable(container, { maintenance = false } = {}) {
  container.querySelectorAll("[data-view-customers]").forEach((button) => {
    button.addEventListener("click", async () => {
      try {
        await showUserCustomers(button.dataset.viewCustomers);
      } catch (error) {
        showToast(error.message);
      }
    });
  });

  if (!maintenance) return;
  container.querySelectorAll("[data-reset-password]").forEach((button) => {
    button.addEventListener("click", () => {
      openPasswordResetDialog(
        button.dataset.resetPassword,
        button.dataset.userAccount || "用户",
      );
    });
  });
}

function openPasswordResetDialog(userId, account) {
  openDialog(
    "重置密码",
    `
      <form id="admin-password-reset-form" class="admin-edit-form">
        <p class="muted">为 ${escapeHtml(account)} 设置新密码，至少 8 位。</p>
        <label>
          <span>新密码</span>
          <input name="password" type="password" minlength="8" required autocomplete="new-password" />
        </label>
        <label>
          <span>再次输入</span>
          <input name="password_confirm" type="password" minlength="8" required autocomplete="new-password" />
        </label>
        <div class="form-actions">
          <button type="submit" class="button button-primary">确认重置</button>
        </div>
      </form>
    `,
  );

  adminEls.dialogBody.querySelector("#admin-password-reset-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const form = event.currentTarget;
    const password = form.elements.password.value;
    const confirm = form.elements.password_confirm.value;
    if (password !== confirm) {
      showToast("两次输入的密码不一致");
      return;
    }
    try {
      await adminFetch(`/admin/users/${userId}/password`, {
        method: "PUT",
        body: { password },
      });
      closeDialog();
      showToast("密码已重置");
    } catch (error) {
      showToast(error.message);
    }
  });
}

export async function loadUserOverview() {
  const [stats, users] = await Promise.all([adminFetch("/admin/stats"), fetchUsers()]);
  adminEls.panels.overview.innerHTML = `
    ${renderStats(stats)}
    <section class="content-card admin-section">
      <div class="card-head">
        <div>
          <p class="card-kicker">Users</p>
          <h3>用户和客户数量</h3>
        </div>
      </div>
      ${renderUserTable(users)}
    </section>
  `;
  bindUserTable(adminEls.panels.overview);
}

export async function loadUserMaintenance() {
  const users = await fetchUsers();
  adminEls.panels.maintenance.innerHTML = `
    <section class="content-card admin-section">
      <div class="card-head">
        <div>
          <p class="card-kicker">Maintenance</p>
          <h3>用户维护</h3>
        </div>
      </div>
      <label class="search-field admin-search">
        <input id="admin-user-search" type="search" placeholder="搜索账号或昵称" />
      </label>
      <div id="admin-user-maintenance-table">${renderUserTable(users, { maintenance: true })}</div>
    </section>
  `;
  const tableWrap = adminEls.panels.maintenance.querySelector("#admin-user-maintenance-table");
  bindUserTable(tableWrap, { maintenance: true });

  let timer;
  adminEls.panels.maintenance.querySelector("#admin-user-search").addEventListener("input", (event) => {
    window.clearTimeout(timer);
    timer = window.setTimeout(async () => {
      try {
        const nextUsers = await fetchUsers(event.target.value.trim());
        tableWrap.innerHTML = renderUserTable(nextUsers, { maintenance: true });
        bindUserTable(tableWrap, { maintenance: true });
      } catch (error) {
        showToast(error.message);
      }
    }, 260);
  });
}
