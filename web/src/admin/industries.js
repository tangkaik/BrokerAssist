import { buildUrl } from "../api.js";
import { state } from "../state.js";
import { showToast } from "./app.js";

export async function loadIndustries() {
  const container = document.getElementById("tab-industries");
  try {
    const res = await fetch(buildUrl("/admin/industries"), {
      headers: { Authorization: `Bearer ${state.authToken}` },
    });
    const payload = await res.json();
    if (!payload.success) throw new Error(payload.error?.message || "加载失败");
    const industries = payload.data;

    container.innerHTML = `
      <div class="admin-toolbar">
        <button id="add-industry-btn" class="button button-brand">新增行业</button>
      </div>
      <table class="data-table">
        <thead>
          <tr><th>标识 (key)</th><th>中文标签</th><th>角色名</th><th>状态</th><th>操作</th></tr>
        </thead>
        <tbody>
          ${industries.map((ind) => `
            <tr>
              <td>${escapeHtml(ind.key)}</td>
              <td>${escapeHtml(ind.label)}</td>
              <td>${escapeHtml(ind.role_name)}</td>
              <td>${ind.enabled
                ? '<span class="badge badge-active">启用</span>'
                : '<span class="badge badge-disabled">禁用</span>'}</td>
              <td>
                <button class="button button-small" data-edit="${ind.key}">编辑</button>
                <button class="button button-small" data-toggle="${ind.key}" data-enabled="${ind.enabled}">
                  ${ind.enabled ? "禁用" : "启用"}
                </button>
                ${ind.key !== "generic" ? `<button class="button button-small button-danger" data-delete="${ind.key}">删除</button>` : ""}
              </td>
            </tr>
          `).join("")}
        </tbody>
      </table>
    `;

    document.getElementById("add-industry-btn").addEventListener("click", () => showIndustryDialog());
    container.querySelectorAll("[data-edit]").forEach((btn) => {
      btn.addEventListener("click", () => {
        const ind = industries.find((i) => i.key === btn.dataset.edit);
        if (ind) showIndustryDialog(ind);
      });
    });
    container.querySelectorAll("[data-toggle]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const key = btn.dataset.toggle;
        const enabled = btn.dataset.enabled === "true";
        try {
          const res = await fetch(buildUrl(`/admin/industries/${key}`), {
            method: "PUT",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${state.authToken}`,
            },
            body: JSON.stringify({ enabled: !enabled }),
          });
          const payload = await res.json();
          if (!payload.success) throw new Error(payload.error?.message || "操作失败");
          showToast(enabled ? "已禁用" : "已启用");
          loadIndustries();
        } catch (e) { showToast(e.message); }
      });
    });
    container.querySelectorAll("[data-delete]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        if (!confirm(`确定删除行业 "${btn.dataset.delete}"？`)) return;
        try {
          const res = await fetch(buildUrl(`/admin/industries/${btn.dataset.delete}`), {
            method: "DELETE",
            headers: { Authorization: `Bearer ${state.authToken}` },
          });
          const payload = await res.json();
          if (!payload.success) throw new Error(payload.error?.message || "删除失败");
          showToast("已删除");
          loadIndustries();
        } catch (e) { showToast(e.message); }
      });
    });

  } catch (e) {
    container.innerHTML = `<p class="error">${e.message}</p>`;
  }
}

function showIndustryDialog(existing) {
  const dialog = document.getElementById("admin-dialog");
  const isEdit = !!existing;
  document.getElementById("admin-dialog-title").textContent = isEdit ? "编辑行业" : "新增行业";
  document.getElementById("admin-dialog-body").innerHTML = `
    <form id="industry-form">
      <label>标识 (key): <input id="ind-key" type="text" value="${escapeHtml(existing?.key || "")}" ${isEdit ? "disabled" : "required"} /></label>
      <label>中文标签: <input id="ind-label" type="text" value="${escapeHtml(existing?.label || "")}" required /></label>
      <label>角色名: <input id="ind-role" type="text" value="${escapeHtml(existing?.role_name || "")}" required /></label>
      <button type="submit" class="button button-brand">${isEdit ? "保存" : "创建"}</button>
    </form>
  `;
  dialog.showModal();
  document.getElementById("admin-dialog-close").onclick = () => dialog.close();

  document.getElementById("industry-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    const body = {
      key: document.getElementById("ind-key").value.trim(),
      label: document.getElementById("ind-label").value.trim(),
      role_name: document.getElementById("ind-role").value.trim(),
    };
    try {
      const url = isEdit ? buildUrl(`/admin/industries/${existing.key}`) : buildUrl("/admin/industries");
      const method = isEdit ? "PUT" : "POST";
      const res = await fetch(url, {
        method,
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${state.authToken}`,
        },
        body: JSON.stringify(body),
      });
      const payload = await res.json();
      if (!payload.success) throw new Error(payload.error?.message || "操作失败");
      showToast(isEdit ? "已保存" : "已创建");
      dialog.close();
      loadIndustries();
    } catch (err) { showToast(err.message); }
  });
}

function escapeHtml(s) {
  const div = document.createElement("div");
  div.textContent = String(s ?? "");
  return div.innerHTML;
}
