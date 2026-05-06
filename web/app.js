const DEFAULT_API_BASE_URL = `${window.location.origin}/api/v1`;
const STORAGE_KEY = "brokerassist:web:api-base-url";
const AUTH_TOKEN_KEY = "brokerassist:web:auth-token";
const AUTH_USER_KEY = "brokerassist:web:auth-user";

const state = {
  apiBaseUrl: localStorage.getItem(STORAGE_KEY) || DEFAULT_API_BASE_URL,
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
  globalSuggestionsHidden: false,
  expandedRecordIds: new Set(),
  recordSaving: false,
  analyzingRecordImageKey: "",
  recordImageModes: {},
};

const GLOBAL_CHAT_CONTEXT_LIMIT = 16;

const els = {
  apiBaseUrl: document.querySelector("#api-base-url"),
  apiConfigForm: document.querySelector("#api-config-form"),
  settingsDialog: document.querySelector("#settings-dialog"),
  openSettings: document.querySelector("#open-settings"),
  closeSettings: document.querySelector("#close-settings"),
  authScreen: document.querySelector("#auth-screen"),
  authTitle: document.querySelector("#auth-title"),
  showLogin: document.querySelector("#show-login"),
  showRegister: document.querySelector("#show-register"),
  loginForm: document.querySelector("#login-form"),
  registerForm: document.querySelector("#register-form"),
  loginSubmit: document.querySelector("#login-submit"),
  registerSubmit: document.querySelector("#register-submit"),
  authStatus: document.querySelector("#auth-status"),
  authUserName: document.querySelector("#auth-user-name"),
  authUserAccount: document.querySelector("#auth-user-account"),
  logoutButton: document.querySelector("#logout-button"),
  customerSearch: document.querySelector("#customer-search"),
  customerSort: document.querySelector("#customer-sort"),
  customerList: document.querySelector("#customer-list"),
  refreshCustomers: document.querySelector("#refresh-customers"),
  generateSummary: document.querySelector("#generate-summary"),
  generateAdvice: document.querySelector("#generate-advice"),
  detailEmpty: document.querySelector("#detail-empty"),
  detailContent: document.querySelector("#detail-content"),
  customerMeta: document.querySelector("#customer-meta"),
  customerName: document.querySelector("#customer-name"),
  customerTags: document.querySelector("#customer-tags"),
  summaryBody: document.querySelector("#summary-body"),
  copySummary: document.querySelector("#copy-summary"),
  exportSummary: document.querySelector("#export-summary"),
  adviceBody: document.querySelector("#advice-body"),
  adviceUpdatedAt: document.querySelector("#advice-updated-at"),
  copyAdvice: document.querySelector("#copy-advice"),
  exportAdvice: document.querySelector("#export-advice"),
  recordList: document.querySelector("#record-list"),
  customerChatForm: document.querySelector("#customer-chat-form"),
  customerChatInput: document.querySelector("#customer-chat-input"),
  customerChatAnswer: document.querySelector("#customer-chat-answer"),
  globalChatForm: document.querySelector("#global-chat-form"),
  globalChatInput: document.querySelector("#global-chat-input"),
  globalChatFiles: document.querySelector("#global-chat-files"),
  globalChatFileTrigger: document.querySelector("#global-chat-file-trigger"),
  globalChatAttachments: document.querySelector("#global-chat-attachments"),
  globalChatLog: document.querySelector("#global-chat-log"),
  globalSuggestions: document.querySelector("#global-suggestions"),
  clearGlobalChat: document.querySelector("#clear-global-chat"),
  createCustomerDialog: document.querySelector("#create-customer-dialog"),
  openCreateCustomer: document.querySelector("#open-create-customer"),
  closeCreateCustomer: document.querySelector("#close-create-customer"),
  createCustomerForm: document.querySelector("#create-customer-form"),
  editCustomerDialog: document.querySelector("#edit-customer-dialog"),
  openEditCustomer: document.querySelector("#open-edit-customer"),
  closeEditCustomer: document.querySelector("#close-edit-customer"),
  editCustomerForm: document.querySelector("#edit-customer-form"),
  editCustomerSubmit: document.querySelector("#edit-customer-submit"),
  addRecordDialog: document.querySelector("#add-record-dialog"),
  openAddRecord: document.querySelector("#open-add-record"),
  closeAddRecord: document.querySelector("#close-add-record"),
  addRecordForm: document.querySelector("#add-record-form"),
  addRecordImages: document.querySelector("#add-record-images"),
  addRecordImageTrigger: document.querySelector("#add-record-image-trigger"),
  addRecordImagePreview: document.querySelector("#add-record-image-preview"),
  recordDropzone: document.querySelector("#record-dropzone"),
  existingRecordImagesWrap: document.querySelector("#existing-record-images-wrap"),
  existingRecordImages: document.querySelector("#existing-record-images"),
  recordDialogTitle: document.querySelector("#record-dialog-title"),
  recordSubmitButton: document.querySelector("#record-submit-button"),
  deleteCustomer: document.querySelector("#delete-customer"),
  imagePreviewDialog: document.querySelector("#image-preview-dialog"),
  imagePreviewTarget: document.querySelector("#image-preview-target"),
  closeImagePreview: document.querySelector("#close-image-preview"),
  toast: document.querySelector("#toast"),
  sectionNavChips: Array.from(document.querySelectorAll("[data-section-nav]")),
};

els.apiBaseUrl.value = state.apiBaseUrl;

function buildUrl(path, query = {}) {
  const normalizedBase = state.apiBaseUrl.replace(/\/$/, "");
  const normalizedPath = path.startsWith("/") ? path : `/${path}`;
  const url = new URL(`${normalizedBase}${normalizedPath}`);

  Object.entries(query).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== "") {
      url.searchParams.set(key, String(value));
    }
  });

  return url.toString();
}

async function apiFetch(path, options = {}) {
  const response = await fetch(buildUrl(path, options.query), {
    method: options.method || "GET",
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-cache, no-store, must-revalidate",
      "Pragma": "no-cache",
      ...(state.authToken ? { Authorization: `Bearer ${state.authToken}` } : {}),
      ...(options.headers || {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  const payload = await response.json().catch(() => null);

  if (!response.ok || !payload?.success) {
    const message =
      payload?.error?.message ||
      payload?.message ||
      `请求失败 (${response.status})`;
    if (response.status === 401) {
      clearAuthSession();
      renderAuthState();
    }
    throw new Error(message);
  }

  return payload.data;
}

async function apiFetchForm(path, formData, options = {}) {
  const response = await fetch(buildUrl(path, options.query), {
    method: options.method || "POST",
    headers: {
      ...(state.authToken ? { Authorization: `Bearer ${state.authToken}` } : {}),
      ...(options.headers || {}),
    },
    body: formData,
  });

  const payload = await response.json().catch(() => null);

  if (!response.ok || !payload?.success) {
    const message =
      payload?.error?.message ||
      payload?.message ||
      `请求失败 (${response.status})`;
    if (response.status === 401) {
      clearAuthSession();
      renderAuthState();
    }
    throw new Error(message);
  }

  return payload.data;
}

function saveAuthSession(token, user) {
  state.authToken = token;
  state.currentUser = user;
  localStorage.setItem(AUTH_TOKEN_KEY, token);
  localStorage.setItem(AUTH_USER_KEY, JSON.stringify(user));
}

function clearAuthSession() {
  state.authToken = "";
  state.currentUser = null;
  state.customers = [];
  state.selectedCustomerId = null;
  state.customerDetail = null;
  state.records = [];
  state.adviceText = "";
  state.adviceUpdatedAt = "";
  state.globalMessages = [];
  localStorage.removeItem(AUTH_TOKEN_KEY);
  localStorage.removeItem(AUTH_USER_KEY);
}

function setAuthMode(mode) {
  const isLogin = mode !== "register";
  els.authTitle.textContent = isLogin ? "登录工作台" : "创建新账号";
  els.loginForm.classList.toggle("hidden", !isLogin);
  els.registerForm.classList.toggle("hidden", isLogin);
  els.showLogin.classList.toggle("active", isLogin);
  els.showRegister.classList.toggle("active", !isLogin);
}

function renderAuthState() {
  const loggedIn = Boolean(state.authToken && state.currentUser);
  els.authScreen.classList.toggle("hidden", loggedIn);
  els.authStatus.classList.toggle("hidden", !loggedIn);

  if (loggedIn) {
    els.authUserName.textContent = state.currentUser.name || "未命名用户";
    els.authUserAccount.textContent = state.currentUser.account || "";
  } else {
    els.authUserName.textContent = "未登录";
    els.authUserAccount.textContent = "";
    renderCustomerList();
    renderCustomerDetail();
    renderGlobalChat();
  }
}

async function restoreSession() {
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
    showToast(error.message || "登录状态已失效，请重新登录");
    return false;
  }
}

function formatDate(value) {
  if (!value) return "未知时间";

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;

  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function formatDateOnly(value) {
  if (!value) return "";

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return date.toISOString().slice(0, 10);
}

function escapeHtml(text) {
  return String(text)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function renderInlineMarkdown(text) {
  return escapeHtml(text).replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
}

function normalizeCustomerLinkSyntax(text) {
  return String(text || "")
    .replace(/([^\s\[]+)\[客户\d+\|ID:([0-9a-fA-F-]{36})\]/g, "[$1|$2]")
    .replace(/\[客户\d+\|ID:([0-9a-fA-F-]{36})\]/g, (_, customerId) => {
      return `[${findCustomerNameById(customerId)}|${customerId}]`;
    })
    .replace(
      /(?<!\[)([\u4e00-\u9fa5A-Za-z0-9]+)\|([0-9a-fA-F-]{36})(?!\])/g,
      "[$1|$2]",
    );
}

function renderInlineRich(text) {
  const source = normalizeCustomerLinkSyntax(text);
  const pattern = /\[([^[\]|]+)\|([0-9a-fA-F-]{36})\]/g;
  let lastIndex = 0;
  let html = "";
  let match;

  while ((match = pattern.exec(source)) !== null) {
    html += renderInlineMarkdown(source.slice(lastIndex, match.index));
    html += `<a href="#" class="customer-link" data-customer-link="${escapeHtml(match[2])}">${escapeHtml(match[1])}</a>`;
    lastIndex = match.index + match[0].length;
  }

  html += renderInlineMarkdown(source.slice(lastIndex));
  return html;
}

function isMarkdownTableSeparator(line) {
  const trimmed = line.trim();
  return /^\|?[\s:-]+(\|[\s:-]+)+\|?$/.test(trimmed);
}

function isMarkdownTableLine(line) {
  const trimmed = line.trim();
  return trimmed.includes("|") && /^\|?.+\|.+\|?$/.test(trimmed);
}

function splitMarkdownTableCells(line) {
  let trimmed = line.trim();
  if (trimmed.startsWith("|")) trimmed = trimmed.slice(1);
  if (trimmed.endsWith("|")) trimmed = trimmed.slice(0, -1);
  return trimmed.split("|").map((cell) => cell.trim());
}

function renderRichText(text) {
  const source = String(text || "").replace(/\r\n/g, "\n");
  const lines = source.split("\n");
  let index = 0;
  const blocks = [];

  while (index < lines.length) {
    const line = lines[index];

    if (!line.trim()) {
      index += 1;
      continue;
    }

    if (
      index + 1 < lines.length &&
      isMarkdownTableLine(line) &&
      isMarkdownTableSeparator(lines[index + 1])
    ) {
      const headerCells = splitMarkdownTableCells(line);
      const bodyRows = [];
      index += 2;

      while (index < lines.length && isMarkdownTableLine(lines[index]) && !isMarkdownTableSeparator(lines[index])) {
        bodyRows.push(splitMarkdownTableCells(lines[index]));
        index += 1;
      }

      blocks.push(`
        <div class="rich-table-wrap">
          <table class="rich-table">
            <thead>
              <tr>${headerCells.map((cell) => `<th>${renderInlineRich(cell)}</th>`).join("")}</tr>
            </thead>
            <tbody>
              ${bodyRows
                .map(
                  (row) =>
                    `<tr>${row.map((cell) => `<td>${renderInlineRich(cell)}</td>`).join("")}</tr>`,
                )
                .join("")}
            </tbody>
          </table>
        </div>
      `);
      continue;
    }

    const paragraphLines = [];
    while (
      index < lines.length &&
      lines[index].trim() &&
      !(
        index + 1 < lines.length &&
        isMarkdownTableLine(lines[index]) &&
        isMarkdownTableSeparator(lines[index + 1])
      )
    ) {
      paragraphLines.push(lines[index]);
      index += 1;
    }

    const paragraphHtml = paragraphLines
      .map((paragraphLine) => renderInlineRich(paragraphLine))
      .join("<br />");
    blocks.push(`<p>${paragraphHtml}</p>`);
  }

  return blocks.join("");
}

function showToast(message) {
  els.toast.textContent = message;
  els.toast.classList.remove("hidden");
  window.clearTimeout(showToast.timer);
  showToast.timer = window.setTimeout(() => {
    els.toast.classList.add("hidden");
  }, 2800);
}

function setActiveSectionNav(sectionId) {
  els.sectionNavChips.forEach((chip) => {
    chip.classList.toggle("active", chip.dataset.sectionNav === sectionId);
  });
}

function updateActiveSectionNavFromScroll() {
  if (!state.customerDetail) return;
  const sectionIds = ["summary-section", "advice-section", "customer-chat-section", "record-section"];
  const containerTop = els.detailContent.getBoundingClientRect().top;
  let activeId = sectionIds[0];

  sectionIds.forEach((sectionId) => {
    const section = document.getElementById(sectionId);
    if (!section) return;
    const top = section.getBoundingClientRect().top - containerTop;
    if (top <= 80) {
      activeId = sectionId;
    }
  });

  setActiveSectionNav(activeId);
}

function setDetailVisibility(hasDetail) {
  els.detailEmpty.classList.toggle("hidden", hasDetail);
  els.detailContent.classList.toggle("hidden", !hasDetail);
}

function hideGlobalSuggestions() {
  state.globalSuggestionsHidden = true;
  els.globalSuggestions.classList.add("hidden");
}

function splitTags(value) {
  return String(value || "")
    .split(/[，,]/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function buildMediaUrl(url) {
  if (!url) return "";
  if (/^https?:\/\//.test(url)) return url;

  const root = state.apiBaseUrl.replace(/\/api\/v1\/?$/, "");
  return `${root}${url.startsWith("/") ? url : `/${url}`}`;
}

function fileKey(file) {
  return `${file.name}:${file.size}:${file.lastModified}`;
}

function renderGlobalChatAttachments() {
  if (!state.globalChatFiles.length) {
    els.globalChatAttachments.innerHTML = "";
    els.globalChatAttachments.classList.add("hidden");
    return;
  }

  els.globalChatAttachments.classList.remove("hidden");
  els.globalChatAttachments.innerHTML = state.globalChatFiles
    .map(
      (file) => `
        <div class="composer-chip" title="${escapeHtml(file.name)}">
          <span class="composer-chip-name">${escapeHtml(file.name)}</span>
          <button
            type="button"
            class="composer-chip-remove"
            data-global-chat-file-remove="${escapeHtml(fileKey(file))}"
            aria-label="移除附件"
          >
            ×
          </button>
        </div>
      `,
    )
    .join("");
}

function mergeGlobalChatFiles(incomingFiles) {
  const dataTransfer = new DataTransfer();
  const firstFile = incomingFiles[0];
  if (firstFile) {
    dataTransfer.items.add(firstFile);
  }

  state.globalChatFiles = Array.from(dataTransfer.files);
  els.globalChatFiles.files = dataTransfer.files;
  renderGlobalChatAttachments();
}

function removeGlobalChatFile(keyToRemove) {
  const dataTransfer = new DataTransfer();
  state.globalChatFiles
    .filter((file) => fileKey(file) !== keyToRemove)
    .forEach((file) => dataTransfer.items.add(file));
  state.globalChatFiles = Array.from(dataTransfer.files);
  els.globalChatFiles.files = dataTransfer.files;
  renderGlobalChatAttachments();
}

function clearGlobalChatFiles() {
  state.globalChatFiles = [];
  els.globalChatFiles.value = "";
  renderGlobalChatAttachments();
}

function toggleExpandedRecord(recordId) {
  if (state.expandedRecordIds.has(recordId)) {
    state.expandedRecordIds.delete(recordId);
  } else {
    state.expandedRecordIds.add(recordId);
  }
  renderCustomerDetail();
}

function renderSelectedImages() {
  const files = state.selectedRecordFiles;
  if (!files.length) {
    els.addRecordImagePreview.innerHTML = "";
    return;
  }

  els.addRecordImagePreview.innerHTML = files
    .map((file) => {
      const objectUrl = URL.createObjectURL(file);
      return `
        <div class="image-preview-item" title="${escapeHtml(file.name)}">
          <img src="${objectUrl}" alt="${escapeHtml(file.name)}" />
          <button
            type="button"
            class="image-remove-chip selected-image-chip"
            data-selected-image-remove="${escapeHtml(fileKey(file))}"
            aria-label="移除图片"
          >
            ×
          </button>
        </div>
      `;
    })
    .join("");
}

function mergeSelectedImages(incomingFiles) {
  const dataTransfer = new DataTransfer();
  const dedup = new Set();

  [...state.selectedRecordFiles, ...incomingFiles].forEach((file) => {
    const key = fileKey(file);
    if (dedup.has(key)) return;
    dedup.add(key);
    dataTransfer.items.add(file);
  });

  state.selectedRecordFiles = Array.from(dataTransfer.files);
  els.addRecordImages.files = dataTransfer.files;
  renderSelectedImages();
}

function removeSelectedImage(keyToRemove) {
  const dataTransfer = new DataTransfer();
  state.selectedRecordFiles
    .filter((file) => fileKey(file) !== keyToRemove)
    .forEach((file) => dataTransfer.items.add(file));
  state.selectedRecordFiles = Array.from(dataTransfer.files);
  els.addRecordImages.files = dataTransfer.files;
  renderSelectedImages();
}

function renderExistingRecordImages() {
  if (!state.editingRecordImages.length) {
    els.existingRecordImagesWrap.classList.add("hidden");
    els.existingRecordImages.innerHTML = "";
    return;
  }

  els.existingRecordImagesWrap.classList.remove("hidden");
  els.existingRecordImages.innerHTML = state.editingRecordImages
    .map(
      (image) => `
        <div class="image-preview-item existing-image-item" title="${escapeHtml(image.name || "图片")}">
          <img src="${buildMediaUrl(image.url)}" alt="${escapeHtml(image.name || "图片")}" />
          <button
            type="button"
            class="image-remove-chip"
            data-existing-image-remove="${escapeHtml(image.url)}"
            aria-label="删除图片"
          >
            ×
          </button>
        </div>
      `,
    )
    .join("");
}

function setRecordSaving(isSaving) {
  state.recordSaving = isSaving;
  els.recordSubmitButton.disabled = isSaving;
  els.closeAddRecord.disabled = isSaving;
  els.addRecordImageTrigger.disabled = isSaving;
  els.recordSubmitButton.textContent = isSaving
    ? state.editingRecordId
      ? "正在保存..."
      : "正在创建..."
    : state.editingRecordId
      ? "保存修改"
      : "保存记录";
}

function updateRecordImageModes(modeKey, inputNodes) {
  state.recordImageModes[modeKey] = Array.from(inputNodes)
    .filter((input) => input.checked)
    .map((input) => input.value);
}

function resetRecordDialog() {
  state.editingRecordId = null;
  state.editingRecordImages = [];
  state.selectedRecordFiles = [];
  els.addRecordForm.reset();
  els.addRecordImagePreview.innerHTML = "";
  els.existingRecordImages.innerHTML = "";
  els.existingRecordImagesWrap.classList.add("hidden");
  els.recordDropzone.classList.remove("dragging");
  els.recordDialogTitle.textContent = "添加拜访记录";
  setRecordSaving(false);
}

function openCreateRecordDialog() {
  if (!state.selectedCustomerId) {
    showToast("请先选择一位客户");
    return;
  }
  resetRecordDialog();
  els.addRecordDialog.showModal();
}

function openEditRecordDialog(recordId) {
  const record = state.records.find((item) => item.id === recordId);
  if (!record) return;

  resetRecordDialog();
  state.editingRecordId = recordId;
  state.editingRecordImages = [...(record.images || [])];
  els.addRecordForm.elements.content.value = record.content || "";
  els.addRecordForm.elements.location_raw.value = record.location_raw || "";
  els.recordDialogTitle.textContent = "编辑拜访记录";
  setRecordSaving(false);
  renderExistingRecordImages();
  els.addRecordDialog.showModal();
}

function openEditCustomerDialog() {
  if (!state.customerDetail) {
    showToast("请先选择一位客户");
    return;
  }

  els.editCustomerForm.elements.name.value = state.customerDetail.name || "";
  els.editCustomerForm.elements.phone.value = state.customerDetail.phone || "";
  els.editCustomerForm.elements.gender.value = state.customerDetail.gender || "";
  els.editCustomerForm.elements.location.value = state.customerDetail.location_raw || "";
  els.editCustomerForm.elements.tags.value = (state.customerDetail.tags || []).join("，");
  els.editCustomerDialog.showModal();
}

function openImagePreview(url, altText) {
  els.imagePreviewTarget.src = buildMediaUrl(url);
  els.imagePreviewTarget.alt = altText || "图片预览";
  els.imagePreviewDialog.showModal();
}

function closeImagePreview() {
  els.imagePreviewDialog.close();
  els.imagePreviewTarget.removeAttribute("src");
}

function findCustomerNameById(customerId) {
  return state.customers.find((customer) => customer.id === customerId)?.name || customerId;
}

function getNameSortValue(name) {
  return String(name || "").trim();
}

function sortCustomersInPlace(customers, sortBy, sortOrder) {
  if (!Array.isArray(customers) || sortBy !== "name") return;

  const collator = new Intl.Collator("zh-u-co-pinyin", {
    sensitivity: "base",
    numeric: false,
  });

  customers.sort((left, right) => {
    const leftName = getNameSortValue(left.name);
    const rightName = getNameSortValue(right.name);
    const result = collator.compare(leftName, rightName);
    return sortOrder === "desc" ? -result : result;
  });
}

function renderCustomerList() {
  if (!state.authToken) {
    els.customerList.innerHTML = `
      <div class="empty-state">
        <h3>先登录再开始</h3>
        <p>登录后，这里会只展示你自己的客户和记录。</p>
      </div>
    `;
    return;
  }
  if (!state.customers.length) {
    els.customerList.innerHTML = `
      <div class="empty-state">
        <h3>还没有客户</h3>
        <p>先创建一位客户，桌面版工作台就能开始积累记录和摘要。</p>
      </div>
    `;
    return;
  }

  els.customerList.innerHTML = state.customers
    .map((customer) => {
      const active = customer.id === state.selectedCustomerId ? "active" : "";
      const tags = (customer.tags || [])
        .slice(0, 3)
        .map((tag) => `<span class="tag">${escapeHtml(tag)}</span>`)
        .join("");

      return `
        <article class="customer-item ${active}" data-customer-id="${customer.id}">
          <h3>${escapeHtml(customer.name)}</h3>
          <p>${escapeHtml(customer.phone || "未填写电话")}</p>
          <div class="tag-row">${tags}</div>
          <small>更新于 ${formatDate(customer.updated_at || customer.created_at)}</small>
        </article>
      `;
    })
    .join("");
}

function statusMarkup(status) {
  const labelMap = {
    ready: "已就绪",
    stale: "待更新",
    updating: "生成中",
    failed: "失败",
  };
  const normalized = status || "stale";
  return `<span class="status-pill ${normalized}">${labelMap[normalized] || normalized}</span>`;
}

function renderCustomerDetail() {
  const detail = state.customerDetail;

  if (!detail) {
    setDetailVisibility(false);
    return;
  }

  const hasAdvice = Boolean(state.adviceText);
  const hasSummary = Boolean(detail.summary_text);

  els.customerName.textContent = detail.name;
  const locationInfo = detail.location_raw
    ? `${detail.location_city || ""}${detail.location_district || ""}${detail.location_subarea || ""} (${detail.location_raw})`
    : "地址未填写";
  els.customerMeta.textContent = `${detail.phone || "电话未填写"} · ${detail.gender || "性别未填写"}\n${locationInfo}\n创建于 ${formatDate(detail.created_at)}`;
  els.customerTags.innerHTML = (detail.tags || []).length
    ? detail.tags.map((tag) => `<span class="tag">${escapeHtml(tag)}</span>`).join("")
    : `<span class="tag">暂无标签</span>`;
  els.summaryBody.textContent =
    detail.summary_text || "这位客户还没有摘要。你可以先生成一次，看看桌面版是否能把零散记录整理成可跟进的信息。";
  els.adviceBody.textContent =
    state.adviceText || "点击“生成拜访建议”后，这里会显示结构化建议。";
  els.adviceUpdatedAt.textContent = state.adviceUpdatedAt
    ? `上次生成时间：${formatDate(state.adviceUpdatedAt)}`
    : "";
  els.copySummary.disabled = !hasSummary;
  els.exportSummary.disabled = !hasSummary;
  els.copyAdvice.disabled = !hasAdvice;
  els.exportAdvice.disabled = !hasAdvice;

  if (!state.records.length) {
    els.recordList.innerHTML = `
      <div class="empty-state">
        <h3>还没有沟通记录</h3>
        <p>当前 Web 版先聚焦桌面查看与 AI 辅助，记录录入仍可沿用现有 App。</p>
      </div>
    `;
  } else {
    els.recordList.innerHTML = state.records
      .map((record) => {
        const expanded = state.expandedRecordIds.has(record.id);
        const needsToggle = String(record.content || "").length > 180 || String(record.content || "").includes("\n");
        const imageCount = record.images?.length || 0;

        return `
          <article class="record-item">
            <div class="record-head">
              <div>
                <h4>${record.type === "audio" ? "语音转写记录" : "文本记录"}</h4>
                <small class="record-image-meta">${imageCount ? `（共 ${imageCount} 张图片）` : "（无图片）"}</small>
              </div>
              <div class="record-actions">
                <button
                  class="icon-button icon-button-soft icon-button-small"
                  type="button"
                  title="编辑记录"
                  aria-label="编辑记录"
                  data-record-edit="${record.id}"
                >
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path d="M4 20h4l10-10l-4-4L4 16z" />
                    <path d="M13 7l4 4" />
                  </svg>
                </button>
                <button
                  class="icon-button icon-button-accent icon-button-small"
                  type="button"
                  title="删除记录"
                  aria-label="删除记录"
                  data-record-delete="${record.id}"
                >
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path d="M4 7h16" />
                    <path d="M9 7V5h6v2" />
                    <path d="M7 7l1 12h8l1-12" />
                    <path d="M10 11v5" />
                    <path d="M14 11v5" />
                  </svg>
                </button>
              </div>
            </div>
            <div class="record-body ${expanded ? "expanded" : "collapsed"}">
              <p>${escapeHtml(record.content)}</p>
            </div>
            ${
              record.location_raw
                ? `<p class="meta-line">地点线索：${escapeHtml(record.location_raw)}${
                    record.location_city || record.location_district || record.location_subarea
                      ? `（${escapeHtml(
                          [record.location_city, record.location_district, record.location_subarea]
                            .filter(Boolean)
                            .join(" / "),
                        )}）`
                      : ""
                  }</p>`
                : ""
            }
            ${
              needsToggle
                ? `<button class="record-more" type="button" data-record-toggle="${record.id}">${expanded ? "收起" : "展开全文"}</button>`
                : ""
            }
            ${
              imageCount
                ? `<div class="record-image-list">${record.images
                    .map(
                      (image) => {
                        const analyzeKey = `${record.id}:${image.url}`;
                        const isAnalyzing = state.analyzingRecordImageKey === analyzeKey;
                        const selectedModes = state.recordImageModes[analyzeKey] || [];
                        return `
                        <div class="record-image-card">
                          <button
                            type="button"
                            class="record-image-button"
                            data-preview-image="${escapeHtml(image.url)}"
                            data-preview-alt="${escapeHtml(image.name || "记录图片")}"
                            title="${escapeHtml(image.name || "图片")}"
                          >
                            <img src="${buildMediaUrl(image.url)}" alt="${escapeHtml(image.name || "记录图片")}" />
                          </button>
                          <div class="record-image-content">
                            <div class="record-image-actions">
                              <div class="record-image-modes">
                                <label class="record-image-mode">
                                  <input type="checkbox" value="output_table" data-record-image-mode-key="${escapeHtml(analyzeKey)}" ${selectedModes.includes("output_table") ? "checked" : ""} />
                                  <span>输出表格</span>
                                </label>
                                <label class="record-image-mode">
                                  <input type="checkbox" value="extract_key_points" data-record-image-mode-key="${escapeHtml(analyzeKey)}" ${selectedModes.includes("extract_key_points") ? "checked" : ""} />
                                  <span>提取重点</span>
                                </label>
                                <label class="record-image-mode">
                                  <input type="checkbox" value="summarize_description" data-record-image-mode-key="${escapeHtml(analyzeKey)}" ${selectedModes.includes("summarize_description") ? "checked" : ""} />
                                  <span>总结成说明</span>
                                </label>
                                <label class="record-image-mode">
                                  <input type="checkbox" value="extract_customer_info" data-record-image-mode-key="${escapeHtml(analyzeKey)}" ${selectedModes.includes("extract_customer_info") ? "checked" : ""} />
                                  <span>提取客户信息</span>
                                </label>
                              </div>
                              <button
                                type="button"
                                class="button button-ghost button-small record-image-analyze"
                                data-record-image-analyze="${record.id}"
                                data-record-image-url="${escapeHtml(image.url)}"
                                ${isAnalyzing ? "disabled" : ""}
                              >
                                ${isAnalyzing ? "识别中..." : "识别图片"}
                              </button>
                            </div>
                            ${
                              image.vision?.answer
                                ? `<div class="record-image-analysis">
                                    <div class="record-image-analysis-label">识别结果</div>
                                    <div class="record-image-analysis-body">${renderRichText(image.vision.answer)}</div>
                                  </div>`
                                : ""
                            }
                          </div>
                        </div>
                      `;
                      },
                    )
                    .join("")}</div>`
                : ""
            }
            <time>${formatDate(record.created_at)}</time>
          </article>
        `;
      })
      .join("");
  }

  setDetailVisibility(true);
}

function renderGlobalChat() {
  if (!state.authToken) {
    els.globalChatLog.replaceChildren();
    return;
  }
  if (!state.globalMessages.length) {
    els.globalChatLog.replaceChildren();
    return;
  }

  els.globalChatLog.innerHTML = state.globalMessages
    .map((message, index) => {
      const content =
        message.role === "assistant"
          ? renderRichText(message.content)
          : escapeHtml(message.content).replace(/\n/g, "<br />");

      return `
        <article class="chat-message ${message.role}">
          <header>
            <span>${message.role === "user" ? "你" : "BrokerAssist"}</span>
            <span>${formatDate(message.time)}</span>
          </header>
          <div class="chat-message-body">${content}</div>
          ${
            message.role === "assistant"
              ? `<div class="chat-message-actions">
                  <button
                    type="button"
                    class="icon-button icon-button-soft icon-button-small"
                    title="复制回答"
                    aria-label="复制回答"
                    data-global-copy="${index}"
                  >
                    <svg viewBox="0 0 24 24" aria-hidden="true">
                      <rect x="9" y="9" width="10" height="10" rx="2" ry="2" />
                      <path d="M7 15H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h7a2 2 0 0 1 2 2v1" />
                    </svg>
                  </button>
                  <button
                    type="button"
                    class="icon-button icon-button-soft icon-button-small"
                    title="分享或导出回答"
                    aria-label="分享或导出回答"
                    data-global-export="${index}"
                  >
                    <svg viewBox="0 0 24 24" aria-hidden="true">
                      <path d="M12 16V5" />
                      <path d="M8 9l4-4l4 4" />
                      <path d="M5 19h14" />
                    </svg>
                  </button>
                </div>`
              : ""
          }
        </article>
      `;
    })
    .join("");
  els.globalChatLog.scrollTop = els.globalChatLog.scrollHeight;
}

async function loadCustomers() {
  if (!state.authToken) {
    renderCustomerList();
    return;
  }
  const sortValue = els.customerSort?.value || "updated_at:desc";
  const [sortBy, sortOrder] = sortValue.split(":");

  try {
    const data = await apiFetch("/customers", {
      query: {
        keyword: els.customerSearch.value.trim() || undefined,
        sort_by: sortBy,
        sort_order: sortOrder,
      },
    });

    state.customers = data.items || [];
    sortCustomersInPlace(state.customers, sortBy, sortOrder);
    if (
      state.selectedCustomerId &&
      !state.customers.some((customer) => customer.id === state.selectedCustomerId)
    ) {
      state.selectedCustomerId = null;
    }

    if (!state.selectedCustomerId && state.customers[0]) {
      state.selectedCustomerId = state.customers[0].id;
    }

    renderCustomerList();

    if (state.selectedCustomerId) {
      await loadCustomerDetail(state.selectedCustomerId);
    } else {
      state.customerDetail = null;
      state.records = [];
      renderCustomerDetail();
    }
  } catch (error) {
    renderCustomerList();
    showToast(error.message);
  }
}

async function loadCustomerDetail(customerId, options = {}) {
  if (!state.authToken) return;
  const preserveScroll = Boolean(options.preserveScroll);
  const previousScrollTop = preserveScroll ? els.detailContent.scrollTop : 0;
  state.selectedCustomerId = customerId;
  renderCustomerList();
  if (!preserveScroll) {
    els.detailContent.scrollTo({ top: 0, behavior: "auto" });
  }
  setActiveSectionNav("summary-section");

  try {
    const [detail, records, advice] = await Promise.all([
      apiFetch(`/customers/${customerId}`),
      apiFetch(`/customers/${customerId}/records`, { query: { limit: 50 } }),
      apiFetch(`/customers/${customerId}/advice`).catch(() => null),
    ]);

    state.customerDetail = detail;
    state.records = records.items || [];
    state.adviceText = advice?.advice_text || "";
    state.adviceUpdatedAt = advice?.updated_at || "";
    state.expandedRecordIds = new Set();
    els.customerChatAnswer.innerHTML = "";
    els.customerChatAnswer.classList.add("hidden");
    renderCustomerDetail();
    if (preserveScroll) {
      els.detailContent.scrollTo({ top: previousScrollTop, behavior: "auto" });
    }
    updateActiveSectionNavFromScroll();
  } catch (error) {
    showToast(error.message);
  }
}

async function createCustomer(formData) {
  if (!state.authToken) return;
  const data = await apiFetch("/customers", {
    method: "POST",
    body: {
      name: String(formData.get("name") || "").trim(),
      phone: String(formData.get("phone") || "").trim() || undefined,
      gender: String(formData.get("gender") || "").trim() || undefined,
      location: String(formData.get("location") || "").trim() || undefined,
      tags: splitTags(formData.get("tags")),
    },
  });

  showToast("客户已创建");
  els.createCustomerDialog.close();
  els.createCustomerForm.reset();
  state.selectedCustomerId = data.customer_id;
  await loadCustomers();
}

async function updateCustomer(formData) {
  if (!state.authToken) return;
  if (!state.selectedCustomerId) return;

  els.editCustomerSubmit.disabled = true;
  els.editCustomerSubmit.textContent = "正在保存...";

  try {
    await apiFetch(`/customers/${state.selectedCustomerId}`, {
      method: "PUT",
      body: {
        name: String(formData.get("name") || "").trim(),
        phone: String(formData.get("phone") || "").trim() || undefined,
        gender: String(formData.get("gender") || "").trim() || undefined,
        location: String(formData.get("location") || "").trim() || undefined,
        tags: splitTags(formData.get("tags")),
      },
    });

    showToast("客户信息已更新");
    els.editCustomerDialog.close();
    await loadCustomers();
    await loadCustomerDetail(state.selectedCustomerId, { preserveScroll: true });
  } finally {
    els.editCustomerSubmit.disabled = false;
    els.editCustomerSubmit.textContent = "保存客户信息";
  }
}

async function createRecord(formData) {
  if (!state.authToken) return;
  if (!state.selectedCustomerId) return;

  const content = String(formData.get("content") || "").trim();
  if (!content) {
    showToast("请输入记录内容");
    return;
  }

  setRecordSaving(true);

  try {
    const images = state.selectedRecordFiles;

    if (!state.editingRecordId && !images.length) {
      await apiFetch("/records", {
        method: "POST",
      body: {
        customer_id: state.selectedCustomerId,
        content,
        location_raw: String(formData.get("location_raw") || "").trim() || undefined,
      },
    });
  } else if (!state.editingRecordId) {
    const multipart = new FormData();
    multipart.set("customer_id", state.selectedCustomerId);
    multipart.set("content", content);
    const locationRaw = String(formData.get("location_raw") || "").trim();
    if (locationRaw) {
      multipart.set("location_raw", locationRaw);
    }
    images.forEach((image) => {
      multipart.append("images", image);
    });

      const response = await fetch(buildUrl("/records/with-images"), {
        method: "POST",
        headers: {
          ...(state.authToken ? { Authorization: `Bearer ${state.authToken}` } : {}),
        },
        body: multipart,
      });
      const payload = await response.json().catch(() => null);
      if (!response.ok || !payload?.success) {
        throw new Error(payload?.error?.message || `请求失败 (${response.status})`);
      }
  } else {
    const multipart = new FormData();
    multipart.set("content", content);
    const locationRaw = String(formData.get("location_raw") || "").trim();
    multipart.set("location_raw", locationRaw);
    state.editingRecordImages.forEach((image) => {
      multipart.append("keep_image_urls", image.url);
    });
      images.forEach((image) => {
        multipart.append("images", image);
      });

      const response = await fetch(buildUrl(`/records/${state.editingRecordId}/with-images`), {
        method: "PUT",
        headers: {
          ...(state.authToken ? { Authorization: `Bearer ${state.authToken}` } : {}),
        },
        body: multipart,
      });
      const payload = await response.json().catch(() => null);
      if (!response.ok || !payload?.success) {
        throw new Error(payload?.error?.message || `请求失败 (${response.status})`);
      }
    }

    showToast(state.editingRecordId ? "拜访记录已更新" : "拜访记录已添加");
    els.addRecordDialog.close();
    resetRecordDialog();
    await loadCustomerDetail(state.selectedCustomerId, { preserveScroll: true });
  } finally {
    setRecordSaving(false);
  }
}

async function deleteRecord(recordId) {
  const record = state.records.find((item) => item.id === recordId);
  const imageCount = record?.images?.length || 0;
  const summary = record?.content
    ? record.content.length > 80
      ? `${record.content.slice(0, 80)}...`
      : record.content
    : "这条记录";
  const confirmed = window.confirm(
    `确认删除这条记录吗？\n\n内容摘要：${summary}\n图片数量：${imageCount} 张\n\n删除后将无法恢复。`,
  );
  if (!confirmed) return;

  await apiFetch(`/records/${recordId}`, { method: "DELETE" });
  showToast("记录已删除");
  await loadCustomerDetail(state.selectedCustomerId, { preserveScroll: true });
}

async function analyzeRecordImage(recordId, imageUrl, analyzeModes = []) {
  state.analyzingRecordImageKey = `${recordId}:${imageUrl}`;
  renderCustomerDetail();

  try {
    const formData = new FormData();
    formData.set("image_url", imageUrl);
    analyzeModes.forEach((mode) => formData.append("analyze_modes", mode));
    await apiFetchForm(`/records/${recordId}/images/analyze`, formData);
    showToast("图片识别完成");
    await loadCustomerDetail(state.selectedCustomerId, { preserveScroll: true });
  } catch (error) {
    showToast(error.message);
  } finally {
    state.analyzingRecordImageKey = "";
    renderCustomerDetail();
  }
}

async function generateSummary() {
  if (!state.selectedCustomerId) return;

  els.summaryBody.textContent = "正在生成摘要...";

  try {
    const result = await apiFetch(`/customers/${state.selectedCustomerId}/summary/generate`, {
      method: "POST",
    });

    state.customerDetail = {
      ...state.customerDetail,
      summary_text: result.summary_text,
      summary_status: result.summary_status,
      updated_at: result.updated_at,
    };

    renderCustomerDetail();
    showToast("摘要已更新");
  } catch (error) {
    renderCustomerDetail();
    showToast(error.message);
  }
}

async function generateAdvice() {
  if (!state.selectedCustomerId) return;

  els.adviceBody.textContent = "正在生成拜访建议...";

  try {
    const result = await apiFetch(`/customers/${state.selectedCustomerId}/advice/generate`, {
      method: "POST",
    });

    state.adviceText = result.advice_text || result.advice || "暂无建议";
    state.adviceUpdatedAt = result.updated_at || "";
    renderCustomerDetail();
    showToast("拜访建议已生成");
  } catch (error) {
    renderCustomerDetail();
    showToast(error.message);
  }
}

async function copyAdvice() {
  if (!state.adviceText) return;

  await navigator.clipboard.writeText(state.adviceText);
  showToast("拜访建议已复制");
}

async function copySummary() {
  const summaryText = state.customerDetail?.summary_text || "";
  if (!summaryText) return;

  await navigator.clipboard.writeText(summaryText);
  showToast("客户画像摘要已复制");
}

async function exportAdvice() {
  if (!state.adviceText || !state.customerDetail) return;

  const exportText = [
    `客户：${state.customerDetail.name}`,
    state.adviceUpdatedAt ? `生成时间：${formatDate(state.adviceUpdatedAt)}` : "",
    "",
    state.adviceText,
  ]
    .filter(Boolean)
    .join("\n");

  if (navigator.share) {
    try {
      await navigator.share({
        title: `${state.customerDetail.name} - 拜访建议`,
        text: exportText,
      });
      showToast("拜访建议已分享");
      return;
    } catch (error) {
      if (error?.name === "AbortError") return;
    }
  }

  const blob = new Blob([exportText], { type: "text/plain;charset=utf-8" });
  const objectUrl = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = objectUrl;
  link.download = `${state.customerDetail.name}-拜访建议.txt`;
  document.body.append(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(objectUrl);
  showToast("拜访建议已导出");
}

async function exportSummary() {
  const summaryText = state.customerDetail?.summary_text || "";
  if (!summaryText || !state.customerDetail) return;

  const exportText = [`客户：${state.customerDetail.name}`, "", summaryText].join("\n");

  if (navigator.share) {
    try {
      await navigator.share({
        title: `${state.customerDetail.name} - 客户画像摘要`,
        text: exportText,
      });
      showToast("客户画像摘要已分享");
      return;
    } catch (error) {
      if (error?.name === "AbortError") return;
    }
  }

  const blob = new Blob([exportText], { type: "text/plain;charset=utf-8" });
  const objectUrl = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = objectUrl;
  link.download = `${state.customerDetail.name}-客户画像摘要.txt`;
  document.body.append(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(objectUrl);
  showToast("客户画像摘要已导出");
}

async function askCustomerQuestion(question) {
  if (!state.authToken) return;
  if (!state.selectedCustomerId || !question.trim()) return;

  els.customerChatAnswer.classList.remove("hidden");
  els.customerChatAnswer.textContent = "正在思考...";

  try {
    const result = await apiFetch(`/customers/${state.selectedCustomerId}/chat`, {
      method: "POST",
      body: { question: question.trim() },
    });

    els.customerChatAnswer.innerHTML = renderRichText(result.answer || "暂无回答");
  } catch (error) {
    els.customerChatAnswer.textContent = error.message;
  }
}

async function copyGlobalAnswer(index) {
  const message = state.globalMessages[index];
  if (!message || message.role !== "assistant" || !message.content) return;
  await navigator.clipboard.writeText(message.content);
  showToast("回答已复制");
}

async function exportGlobalAnswer(index) {
  const message = state.globalMessages[index];
  if (!message || message.role !== "assistant" || !message.content) return;

  if (navigator.share) {
    try {
      await navigator.share({
        title: "BrokerAssist - AI问答",
        text: message.content,
      });
      showToast("回答已分享");
      return;
    } catch (error) {
      if (error?.name === "AbortError") return;
    }
  }

  const blob = new Blob([message.content], { type: "text/plain;charset=utf-8" });
  const objectUrl = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = objectUrl;
  link.download = `ai-answer-${index + 1}.txt`;
  document.body.append(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(objectUrl);
  showToast("回答已导出");
}

async function askGlobalQuestion(question, imageFile = null) {
  if (!state.authToken) {
    showToast("请先登录");
    return;
  }
  if (!question.trim()) return;

  const recentMessages = state.globalMessages
    .slice(-GLOBAL_CHAT_CONTEXT_LIMIT)
    .filter((message) => message.role === "user" || message.role === "assistant")
    .map((message) => ({
      role: message.role,
      content: String(message.content || "").slice(0, 2000),
    }))
    .filter((message) => message.content.trim());

  hideGlobalSuggestions();
  state.globalMessages.push({
    role: "user",
    content: imageFile ? `${question.trim()}\n\n[附图：${imageFile.name}]` : question.trim(),
    time: new Date().toISOString(),
  });
  renderGlobalChat();

  try {
    const result = imageFile
      ? await (async () => {
          const formData = new FormData();
          formData.set("question", question.trim());
          formData.set("image", imageFile);
          return apiFetchForm("/ai/chat-with-image", formData);
        })()
      : await apiFetch("/ai/chat", {
          method: "POST",
          body: { question: question.trim(), recent_messages: recentMessages },
        });

    state.globalMessages.push({
      role: "assistant",
      content: result.answer || "暂无回答",
      time: new Date().toISOString(),
    });
    renderGlobalChat();
  } catch (error) {
    const fallbackMessage = imageFile
      ? "图片识别暂时不可用。可以先把图片里的文字或关键信息发给我，我会继续基于文本帮你分析。"
      : error.message;
    state.globalMessages.push({
      role: "assistant",
      content: fallbackMessage,
      time: new Date().toISOString(),
    });
    renderGlobalChat();
  }
}

async function deleteCurrentCustomer() {
  if (!state.authToken) return;
  if (!state.selectedCustomerId || !state.customerDetail) return;

  const confirmed = window.confirm(`确定要删除客户“${state.customerDetail.name}”吗？`);
  if (!confirmed) return;

  try {
    await apiFetch(`/customers/${state.selectedCustomerId}`, {
      method: "DELETE",
    });

    showToast("客户已删除");
    state.selectedCustomerId = null;
    state.customerDetail = null;
    state.records = [];
    state.adviceText = "";
    state.adviceUpdatedAt = "";
    renderCustomerDetail();
    await loadCustomers();
  } catch (error) {
    showToast(error.message);
  }
}

async function submitLogin(formData) {
  els.loginSubmit.disabled = true;
  els.loginSubmit.textContent = "正在登录...";

  try {
    const result = await apiFetch("/auth/login", {
      method: "POST",
      body: {
        account: String(formData.get("account") || "").trim(),
        password: String(formData.get("password") || ""),
      },
      headers: {},
    });
    saveAuthSession(result.token, result.user);
    renderAuthState();
    await loadCustomers();
    showToast("登录成功");
  } finally {
    els.loginSubmit.disabled = false;
    els.loginSubmit.textContent = "登录";
  }
}

async function submitRegister(formData) {
  els.registerSubmit.disabled = true;
  els.registerSubmit.textContent = "正在创建...";

  try {
    const result = await apiFetch("/auth/register", {
      method: "POST",
      body: {
        name: String(formData.get("name") || "").trim() || undefined,
        account: String(formData.get("account") || "").trim(),
        password: String(formData.get("password") || ""),
      },
      headers: {},
    });
    saveAuthSession(result.token, result.user);
    renderAuthState();
    await loadCustomers();
    showToast("账号已创建");
  } finally {
    els.registerSubmit.disabled = false;
    els.registerSubmit.textContent = "创建账号并登录";
  }
}

els.apiConfigForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  state.apiBaseUrl = els.apiBaseUrl.value.trim() || DEFAULT_API_BASE_URL;
  localStorage.setItem(STORAGE_KEY, state.apiBaseUrl);
  showToast("API 地址已保存");
  els.settingsDialog.close();
  if (state.authToken) {
    await restoreSession();
    await loadCustomers();
  }
});

els.openSettings.addEventListener("click", () => {
  els.apiBaseUrl.value = state.apiBaseUrl;
  els.settingsDialog.showModal();
});
els.closeSettings.addEventListener("click", () => {
  els.settingsDialog.close();
});

els.showLogin.addEventListener("click", () => setAuthMode("login"));
els.showRegister.addEventListener("click", () => setAuthMode("register"));
els.loginForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    await submitLogin(new FormData(els.loginForm));
  } catch (error) {
    showToast(error.message);
  }
});
els.registerForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    await submitRegister(new FormData(els.registerForm));
  } catch (error) {
    showToast(error.message);
  }
});
els.logoutButton.addEventListener("click", () => {
  clearAuthSession();
  renderAuthState();
  setAuthMode("login");
  showToast("已退出登录");
});

let searchTimer;
els.customerSearch.addEventListener("input", () => {
  window.clearTimeout(searchTimer);
  searchTimer = window.setTimeout(loadCustomers, 300);
});
els.customerSearch.addEventListener("keydown", (event) => {
  if (event.key !== "Enter") return;
  event.preventDefault();
  window.clearTimeout(searchTimer);
  loadCustomers();
});
els.customerSort.addEventListener("change", loadCustomers);
els.refreshCustomers.addEventListener("click", loadCustomers);
els.generateSummary.addEventListener("click", generateSummary);
els.generateAdvice.addEventListener("click", generateAdvice);
els.copySummary.addEventListener("click", async () => {
  try {
    await copySummary();
  } catch (error) {
    showToast(error.message || "复制失败");
  }
});
els.exportSummary.addEventListener("click", exportSummary);
els.copyAdvice.addEventListener("click", async () => {
  try {
    await copyAdvice();
  } catch (error) {
    showToast(error.message || "复制失败");
  }
});
els.exportAdvice.addEventListener("click", exportAdvice);

els.customerList.addEventListener("click", (event) => {
  const item = event.target.closest("[data-customer-id]");
  if (!item) return;
  loadCustomerDetail(item.dataset.customerId);
});

els.sectionNavChips.forEach((chip) => {
  chip.addEventListener("click", () => {
    const sectionId = chip.dataset.sectionNav;
    const section = document.getElementById(sectionId);
    if (!section) return;
    setActiveSectionNav(sectionId);
    const top = section.offsetTop - 10;
    els.detailContent.scrollTo({ top, behavior: "smooth" });
  });
});

els.detailContent.addEventListener("scroll", () => {
  window.requestAnimationFrame(updateActiveSectionNavFromScroll);
});

els.customerChatForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const question = els.customerChatInput.value;
  els.customerChatInput.value = "";
  await askCustomerQuestion(question);
});
els.customerChatInput.addEventListener("keydown", (event) => {
  if (event.key !== "Enter" || event.shiftKey) return;
  event.preventDefault();
  els.customerChatForm.requestSubmit();
});

els.globalChatForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const question = els.globalChatInput.value;
  const imageFile = state.globalChatFiles[0] || null;
  els.globalChatInput.value = "";
  clearGlobalChatFiles();
  await askGlobalQuestion(question, imageFile);
});
els.globalChatInput.addEventListener("keydown", (event) => {
  if (event.key !== "Enter" || event.shiftKey) return;
  event.preventDefault();
  els.globalChatForm.requestSubmit();
});

els.globalChatFileTrigger.addEventListener("click", () => {
  els.globalChatFiles.click();
});

els.globalChatFiles.addEventListener("change", (event) => {
  const files = Array.from(event.target.files || []).filter((file) => file.size > 0);
  if (files.length > 1) {
    showToast("当前版本一次只支持上传一张图片");
  }
  mergeGlobalChatFiles(files);
});

els.globalChatAttachments.addEventListener("click", (event) => {
  const button = event.target.closest("[data-global-chat-file-remove]");
  if (!button) return;
  removeGlobalChatFile(button.dataset.globalChatFileRemove);
});

document.querySelectorAll(".suggestion-chip").forEach((button) => {
  button.addEventListener("click", () => {
    askGlobalQuestion(button.dataset.question || "");
  });
});

els.globalChatLog.addEventListener("click", async (event) => {
  const copyButton = event.target.closest("[data-global-copy]");
  if (copyButton) {
    try {
      await copyGlobalAnswer(Number(copyButton.dataset.globalCopy));
    } catch (error) {
      showToast(error.message || "复制失败");
    }
    return;
  }

  const exportButton = event.target.closest("[data-global-export]");
  if (exportButton) {
    try {
      await exportGlobalAnswer(Number(exportButton.dataset.globalExport));
    } catch (error) {
      showToast(error.message || "导出失败");
    }
    return;
  }

  const link = event.target.closest("[data-customer-link]");
  if (!link) return;
  event.preventDefault();
  await loadCustomerDetail(link.dataset.customerLink);
  els.detailContent.scrollTo({ top: 0, behavior: "smooth" });
});

els.clearGlobalChat.addEventListener("click", () => {
  state.globalMessages = [];
  renderGlobalChat();
});

els.openCreateCustomer.addEventListener("click", () => {
  els.createCustomerDialog.showModal();
});
els.closeCreateCustomer.addEventListener("click", () => {
  els.createCustomerDialog.close();
});
els.createCustomerForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    const formData = new FormData(els.createCustomerForm);
    await createCustomer(formData);
  } catch (error) {
    showToast(error.message);
  }
});

els.openEditCustomer.addEventListener("click", openEditCustomerDialog);
els.closeEditCustomer.addEventListener("click", () => {
  els.editCustomerDialog.close();
});
els.editCustomerForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    const formData = new FormData(els.editCustomerForm);
    await updateCustomer(formData);
  } catch (error) {
    showToast(error.message);
  }
});

els.openAddRecord.addEventListener("click", () => {
  openCreateRecordDialog();
});
els.closeAddRecord.addEventListener("click", () => {
  if (state.recordSaving) return;
  resetRecordDialog();
  els.addRecordDialog.close();
});
els.addRecordImageTrigger.addEventListener("click", () => {
  els.addRecordImages.click();
});
els.addRecordImages.addEventListener("change", () => {
  mergeSelectedImages(Array.from(els.addRecordImages.files || []));
});
els.addRecordImagePreview.addEventListener("click", (event) => {
  const button = event.target.closest("[data-selected-image-remove]");
  if (!button) return;
  removeSelectedImage(button.dataset.selectedImageRemove);
});
els.recordDropzone.addEventListener("dragover", (event) => {
  event.preventDefault();
  els.recordDropzone.classList.add("dragging");
});
els.recordDropzone.addEventListener("dragleave", (event) => {
  if (!els.recordDropzone.contains(event.relatedTarget)) {
    els.recordDropzone.classList.remove("dragging");
  }
});
els.recordDropzone.addEventListener("drop", (event) => {
  event.preventDefault();
  els.recordDropzone.classList.remove("dragging");
  const files = Array.from(event.dataTransfer?.files || []).filter((file) =>
    file.type.startsWith("image/"),
  );
  if (!files.length) {
    showToast("请拖入图片文件");
    return;
  }
  mergeSelectedImages(files);
});
els.addRecordForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    const formData = new FormData(els.addRecordForm);
    await createRecord(formData);
  } catch (error) {
    showToast(error.message);
  }
});
els.existingRecordImages.addEventListener("click", (event) => {
  const button = event.target.closest("[data-existing-image-remove]");
  if (!button) return;
  const imageUrl = button.dataset.existingImageRemove;
  state.editingRecordImages = state.editingRecordImages.filter((image) => image.url !== imageUrl);
  renderExistingRecordImages();
});

els.recordList.addEventListener("click", async (event) => {
  const toggleButton = event.target.closest("[data-record-toggle]");
  if (toggleButton) {
    toggleExpandedRecord(toggleButton.dataset.recordToggle);
    return;
  }

  const previewButton = event.target.closest("[data-preview-image]");
  if (previewButton) {
    openImagePreview(previewButton.dataset.previewImage, previewButton.dataset.previewAlt);
    return;
  }

  const analyzeButton = event.target.closest("[data-record-image-analyze]");
  if (analyzeButton) {
    const card = analyzeButton.closest(".record-image-card");
    const modeInputs = Array.from(card?.querySelectorAll(".record-image-mode input:checked") || []);
    await analyzeRecordImage(
      analyzeButton.dataset.recordImageAnalyze,
      analyzeButton.dataset.recordImageUrl,
      modeInputs.map((input) => input.value),
    );
    return;
  }

  const editButton = event.target.closest("[data-record-edit]");
  if (editButton) {
    openEditRecordDialog(editButton.dataset.recordEdit);
    return;
  }

  const deleteButton = event.target.closest("[data-record-delete]");
  if (deleteButton) {
    await deleteRecord(deleteButton.dataset.recordDelete);
  }
});

els.recordList.addEventListener("change", (event) => {
  const modeInput = event.target.closest("[data-record-image-mode-key]");
  if (!modeInput) return;
  const card = modeInput.closest(".record-image-card");
  const inputNodes = card?.querySelectorAll(".record-image-mode input") || [];
  updateRecordImageModes(modeInput.dataset.recordImageModeKey, inputNodes);
});

els.closeImagePreview.addEventListener("click", closeImagePreview);
els.imagePreviewDialog.addEventListener("click", (event) => {
  if (event.target === els.imagePreviewDialog) {
    closeImagePreview();
  }
});
els.deleteCustomer.addEventListener("click", deleteCurrentCustomer);

renderCustomerList();
renderCustomerDetail();
renderGlobalChat();
setAuthMode("login");
renderAuthState();
restoreSession().then((isReady) => {
  if (isReady) {
    loadCustomers();
  }
});
