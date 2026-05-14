import { buildUrl } from "../api.js";
import { state } from "../state.js";
import { showToast } from "./app.js";

const PROMPT_FIELDS = [
  { key: "summary_focus", label: "摘要关注点", hint: "每行一项，AI 总结客户时将关注这些方面" },
  { key: "missing_info", label: "信息缺失项", hint: "用顿号（、）分隔，用于判断客户信息完整度" },
  { key: "advice_focus", label: "建议方向", hint: "一段话，描述 AI 给出建议时应围绕的方向" },
  { key: "forbidden_guidance", label: "禁用话术", hint: "每行一项，AI 在生成内容时禁止使用的表述" },
  { key: "query_examples", label: "查询示例", hint: "用顿号（、）分隔，客户搜索时的推荐关键词" },
];

export async function loadPrompts() {
  const container = document.getElementById("tab-prompts");

  try {
    const indRes = await fetch(buildUrl("/admin/industries"), {
      headers: { Authorization: `Bearer ${state.authToken}` },
    });
    const indPayload = await indRes.json();
    if (!indPayload.success) throw new Error(indPayload.error?.message || "加载行业失败");
    const industries = indPayload.data;

    container.innerHTML = `
      <div class="admin-toolbar">
        <label>选择行业：
          <select id="prompt-industry-select">
            <option value="">-- 请选择 --</option>
            ${industries.map((ind) => `<option value="${ind.key}">${escapeHtml(ind.label)} (${ind.key})</option>`).join("")}
          </select>
        </label>
      </div>
      <div id="prompt-editor-area"><p class="muted">请先选择一个行业</p></div>
    `;

    document.getElementById("prompt-industry-select").addEventListener("change", async (e) => {
      const key = e.target.value;
      if (!key) {
        document.getElementById("prompt-editor-area").innerHTML = '<p class="muted">请先选择一个行业</p>';
        return;
      }
      await loadPromptEditor(key);
    });
  } catch (e) {
    container.innerHTML = `<p class="error">${e.message}</p>`;
  }
}

async function loadPromptEditor(industryKey) {
  const area = document.getElementById("prompt-editor-area");
  try {
    const res = await fetch(buildUrl(`/admin/industries/${industryKey}/prompts`), {
      headers: { Authorization: `Bearer ${state.authToken}` },
    });
    const payload = await res.json();
    if (!payload.success) throw new Error(payload.error?.message || "加载提示词失败");
    const savedPrompts = payload.data;
    const savedMap = {};
    savedPrompts.forEach((p) => { savedMap[p.prompt_field] = p.value; });

    area.innerHTML = `
      <form id="prompt-form">
        ${PROMPT_FIELDS.map((f) => `
          <div class="prompt-field-row">
            <label>${f.label}</label>
            <textarea id="prompt-${f.key}" rows="4">${escapeHtml(savedMap[f.key] || "")}</textarea>
            <div class="field-hint">${f.hint}</div>
          </div>
        `).join("")}
        <button type="submit" class="button button-brand">保存全部提示词</button>
      </form>
    `;

    document.getElementById("prompt-form").addEventListener("submit", async (e) => {
      e.preventDefault();
      const body = {};
      PROMPT_FIELDS.forEach((f) => {
        body[f.key] = document.getElementById(`prompt-${f.key}`).value;
      });
      try {
        const res = await fetch(buildUrl(`/admin/industries/${industryKey}/prompts`), {
          method: "PUT",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${state.authToken}`,
          },
          body: JSON.stringify(body),
        });
        const payload = await res.json();
        if (!payload.success) throw new Error(payload.error?.message || "保存失败");
        showToast("提示词已保存");
      } catch (err) { showToast(err.message); }
    });
  } catch (e) {
    area.innerHTML = `<p class="error">${e.message}</p>`;
  }
}

function escapeHtml(s) {
  const div = document.createElement("div");
  div.textContent = String(s ?? "");
  return div.innerHTML;
}
