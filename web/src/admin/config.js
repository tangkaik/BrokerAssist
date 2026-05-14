import { buildUrl } from "../api.js";
import { state } from "../state.js";
import { showToast } from "./app.js";

export async function loadConfig() {
  const container = document.getElementById("tab-config");

  const defaultConfigs = [
    { key: "kimi_model", label: "Kimi 模型", description: "文本问答使用的 Kimi 模型名称", value: "" },
    { key: "qwen_vl_model", label: "Qwen VL 模型", description: "图片问答使用的视觉模型", value: "" },
    { key: "max_upload_image_count", label: "最大上传图片数", description: "单次上传允许的最大图片张数", value: "" },
    { key: "max_upload_image_bytes", label: "单张图片最大大小", description: "单位：字节，默认 10MB", value: "" },
    { key: "allow_test_account", label: "允许测试账号登录", description: "true/false", value: "" },
    { key: "open_registration", label: "开放注册", description: "是否允许新用户注册", value: "" },
  ];

  try {
    const res = await fetch(buildUrl("/admin/configs"), {
      headers: { Authorization: `Bearer ${state.authToken}` },
    });
    const payload = await res.json();
    const savedConfigs = payload.success ? payload.data : [];
    const savedMap = {};
    savedConfigs.forEach((c) => { savedMap[c.key] = c.value; });

    defaultConfigs.forEach((c) => { if (savedMap[c.key] !== undefined) c.value = savedMap[c.key]; });

    container.innerHTML = `
      <h3>系统配置</h3>
      <div class="config-list">
        ${defaultConfigs.map((c) => `
          <div class="config-row">
            <label>${escapeHtml(c.label)}<br><span class="config-desc">${escapeHtml(c.description)}</span></label>
            <input id="cfg-${c.key}" type="text" value="${escapeHtml(c.value)}" />
            <button class="button button-secondary" data-save="${c.key}">保存</button>
          </div>
        `).join("")}
      </div>
    `;

    container.querySelectorAll("[data-save]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const key = btn.dataset.save;
        const input = document.getElementById(`cfg-${key}`);
        try {
          const res = await fetch(buildUrl(`/admin/configs/${key}`), {
            method: "PUT",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${state.authToken}`,
            },
            body: JSON.stringify({ value: input.value }),
          });
          const payload = await res.json();
          if (!payload.success) throw new Error(payload.error?.message || "保存失败");
          showToast("配置已保存");
        } catch (e) { showToast(e.message); }
      });
    });
  } catch (e) {
    container.innerHTML = `<p class="error">${e.message}</p>`;
  }
}

function escapeHtml(s) {
  const div = document.createElement("div");
  div.textContent = String(s ?? "");
  return div.innerHTML;
}
