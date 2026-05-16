import { adminFetch } from "./api.js";
import { adminEls, escapeHtml, formatDate, openDialog, closeDialog, showToast } from "./app.js";

let industriesCache = [];

function emptyPromptConfig() {
  return {
    summary_focus: [],
    missing_info: [],
    advice_focus: "",
    forbidden_guidance: [],
    query_examples: [],
    assistant_suggestions: [],
    app_display: {
      workspace_label: "",
      icon_key: "work",
      quick_tip: "",
    },
    reminder_rules: {
      birthday_enabled: true,
      festival_enabled: true,
      festival_group_title: "节日关怀",
      festival_body_template: "{festival}还有 {days} 天，建议提前准备客户关怀。",
      key_date_enabled: false,
      key_date_keywords: [],
      key_date_title_template: "{customer}关键日期提醒",
      key_date_body_template: "{customer} 的关键日期还有 {days} 天，请及时跟进。",
      key_date_group_title: "关键日期",
      key_date_source_key: "key_date_detected",
    },
  };
}

function promptSectionFromConfig(config) {
  return {
    summary_focus: config.summary_focus || [],
    missing_info: config.missing_info || [],
    advice_focus: config.advice_focus || "",
    forbidden_guidance: config.forbidden_guidance || [],
    query_examples: config.query_examples || [],
  };
}

function jsonText(value) {
  return JSON.stringify(value, null, 2);
}

function parseJsonField(form, name, label) {
  try {
    return JSON.parse(form.elements[name].value || "null");
  } catch (error) {
    throw new Error(`${label} 不是合法 JSON：${error.message}`);
  }
}

function renderJsonEditor(name, label, value, rows = 10) {
  return `
    <label>
      <span>${label}</span>
      <textarea name="${name}" class="admin-json-editor" rows="${rows}" spellcheck="false">${escapeHtml(jsonText(value))}</textarea>
    </label>
  `;
}

function renderIndustryTable(industries) {
  return `
    <div class="admin-table-wrap">
      <table class="admin-table">
        <thead>
          <tr>
            <th>标识</th>
            <th>行业名称</th>
            <th>AI 角色名</th>
            <th>状态</th>
            <th>更新时间</th>
            <th>操作</th>
          </tr>
        </thead>
        <tbody>
          ${industries
            .map(
              (industry) => `
                <tr>
                  <td><code>${escapeHtml(industry.key)}</code></td>
                  <td>${escapeHtml(industry.label)}</td>
                  <td>${escapeHtml(industry.role_name)}</td>
                  <td>${industry.enabled ? "启用" : "停用"}</td>
                  <td>${formatDate(industry.updated_at)}</td>
                  <td class="admin-row-actions">
                    <button type="button" class="button button-secondary" data-edit-industry="${escapeHtml(industry.key)}">编辑</button>
                    <button type="button" class="button button-ghost" data-clone-industry="${escapeHtml(industry.key)}">复制</button>
                    <button
                      type="button"
                      class="button button-ghost"
                      data-toggle-industry="${escapeHtml(industry.key)}"
                      ${industry.key === "generic" ? "disabled" : ""}
                    >${industry.enabled ? "停用" : "启用"}</button>
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

function getIndustryFormValues(form) {
  const aiPrompt = parseJsonField(form, "ai_prompt_json", "AI 提示词配置");
  const appDisplay = parseJsonField(form, "app_display_json", "App 展示配置");
  const assistantSuggestions = parseJsonField(form, "assistant_suggestions_json", "AI 助手示例问题");
  const reminderRules = parseJsonField(form, "reminder_rules_json", "提醒规则");
  if (!aiPrompt || typeof aiPrompt !== "object" || Array.isArray(aiPrompt)) {
    throw new Error("AI 提示词配置必须是 JSON 对象");
  }
  if (!appDisplay || typeof appDisplay !== "object" || Array.isArray(appDisplay)) {
    throw new Error("App 展示配置必须是 JSON 对象");
  }
  if (!Array.isArray(assistantSuggestions)) {
    throw new Error("AI 助手示例问题必须是 JSON 数组");
  }
  if (!reminderRules || typeof reminderRules !== "object" || Array.isArray(reminderRules)) {
    throw new Error("提醒规则必须是 JSON 对象");
  }
  const promptConfig = {
    ...emptyPromptConfig(),
    ...aiPrompt,
    app_display: appDisplay,
    assistant_suggestions: assistantSuggestions,
    reminder_rules: reminderRules,
  };

  return {
    key: form.elements.key.value.trim().toLowerCase(),
    label: form.elements.label.value.trim(),
    role_name: form.elements.role_name.value.trim(),
    enabled: form.elements.enabled.checked,
    prompt_config: promptConfig,
  };
}

function renderIndustryForm(industry, { isCreate = false } = {}) {
  const config = { ...emptyPromptConfig(), ...(industry?.prompt_config || {}) };
  config.app_display = { ...emptyPromptConfig().app_display, ...(config.app_display || {}) };
  config.reminder_rules = { ...emptyPromptConfig().reminder_rules, ...(config.reminder_rules || {}) };
  return `
    <form id="admin-industry-form" class="admin-edit-form">
      <label>
        <span>行业标识</span>
        <input name="key" value="${escapeHtml(industry?.key || "")}" ${isCreate ? "" : "readonly"} required />
      </label>
      <label>
        <span>行业名称</span>
        <input name="label" value="${escapeHtml(industry?.label || "")}" required />
      </label>
      <label>
        <span>AI 角色名</span>
        <input name="role_name" value="${escapeHtml(industry?.role_name || "")}" required />
      </label>
      <label class="admin-checkbox-row">
        <input name="enabled" type="checkbox" ${industry?.enabled !== false ? "checked" : ""} ${industry?.key === "generic" ? "disabled" : ""} />
        <span>启用这个行业</span>
      </label>
      <hr />
      ${renderJsonEditor("ai_prompt_json", "AI 提示词配置 JSON", promptSectionFromConfig(config), 14)}
      ${renderJsonEditor("app_display_json", "App 展示配置 JSON", config.app_display, 6)}
      ${renderJsonEditor("assistant_suggestions_json", "AI 助手示例问题 JSON", config.assistant_suggestions || [], 16)}
      ${renderJsonEditor("reminder_rules_json", "提醒规则 JSON", config.reminder_rules, 12)}
      <div class="form-actions">
        <button type="submit" class="button button-primary">保存</button>
      </div>
    </form>
  `;
}

function openIndustryEditor(industry, { isCreate = false } = {}) {
  openDialog(isCreate ? "新增行业" : "编辑行业", renderIndustryForm(industry, { isCreate }));
  const form = adminEls.dialogBody.querySelector("#admin-industry-form");
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    try {
      const body = getIndustryFormValues(form);
      if (!body.key || !body.label || !body.role_name) {
        showToast("请填写行业标识、名称和 AI 角色名");
        return;
      }
      if (body.key === "generic") {
        body.enabled = true;
      }
      if (isCreate) {
        await adminFetch("/admin/industries", { method: "POST", body });
      } else {
        await adminFetch(`/admin/industries/${industry.key}`, { method: "PUT", body });
      }
      closeDialog();
      showToast("行业配置已保存");
      await loadIndustryAdmin();
    } catch (error) {
      showToast(error.message);
    }
  });
}

function openCloneDialog(source) {
  openDialog(
    "复制为新行业",
    `
      <form id="admin-clone-form" class="admin-edit-form">
        <p class="muted">将复制「${escapeHtml(source.label)}」的全部行业配置 JSON。</p>
        <label>
          <span>新行业标识</span>
          <input name="key" placeholder="例如 car_sales" required />
        </label>
        <label>
          <span>新行业名称</span>
          <input name="label" placeholder="例如 汽车销售" required />
        </label>
        <div class="form-actions">
          <button type="submit" class="button button-primary">复制</button>
        </div>
      </form>
    `,
  );
  adminEls.dialogBody.querySelector("#admin-clone-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const form = event.currentTarget;
    try {
      await adminFetch(`/admin/industries/${source.key}/clone`, {
        method: "POST",
        body: {
          key: form.elements.key.value.trim(),
          label: form.elements.label.value.trim(),
        },
      });
      closeDialog();
      showToast("新行业已复制");
      await loadIndustryAdmin();
    } catch (error) {
      showToast(error.message);
    }
  });
}

function bindIndustryActions() {
  adminEls.panels.industries.querySelector("#admin-create-industry").addEventListener("click", () => {
    openIndustryEditor(
      {
        key: "",
        label: "",
        role_name: "",
        enabled: true,
        prompt_config: emptyPromptConfig(),
      },
      { isCreate: true },
    );
  });

  adminEls.panels.industries.querySelectorAll("[data-edit-industry]").forEach((button) => {
    button.addEventListener("click", () => {
      const industry = industriesCache.find((item) => item.key === button.dataset.editIndustry);
      if (industry) openIndustryEditor(industry);
    });
  });

  adminEls.panels.industries.querySelectorAll("[data-clone-industry]").forEach((button) => {
    button.addEventListener("click", () => {
      const industry = industriesCache.find((item) => item.key === button.dataset.cloneIndustry);
      if (industry) openCloneDialog(industry);
    });
  });

  adminEls.panels.industries.querySelectorAll("[data-toggle-industry]").forEach((button) => {
    button.addEventListener("click", async () => {
      const industry = industriesCache.find((item) => item.key === button.dataset.toggleIndustry);
      if (!industry) return;
      try {
        await adminFetch(`/admin/industries/${industry.key}/enabled`, {
          method: "PUT",
          body: { enabled: !industry.enabled },
        });
        showToast(industry.enabled ? "行业已停用" : "行业已启用");
        await loadIndustryAdmin();
      } catch (error) {
        showToast(error.message);
      }
    });
  });
}

export async function loadIndustryAdmin() {
  const data = await adminFetch("/admin/industries");
  industriesCache = data.items || [];
  adminEls.panels.industries.innerHTML = `
    <section class="content-card admin-section">
      <div class="card-head">
        <div>
          <p class="card-kicker">Industries</p>
          <h3>行业配置</h3>
        </div>
        <button id="admin-create-industry" type="button" class="button button-primary">新增行业</button>
      </div>
      ${renderIndustryTable(industriesCache)}
    </section>
  `;
  bindIndustryActions();
}
