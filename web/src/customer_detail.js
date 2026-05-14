import { apiFetch, apiFetchForm, buildUrl } from "./api.js";
import { renderCustomerList } from "./customers.js";
import { els } from "./dom.js";
import { state } from "./state.js";

let callbacks = {
  showToast: () => {},
  formatDate: (value) => String(value ?? ""),
  escapeHtml: (text) => String(text ?? ""),
  renderRichText: (text) => String(text ?? ""),
  setDetailVisibility: () => {},
  setActiveSectionNav: () => {},
  updateActiveSectionNavFromScroll: () => {},
};

export function configureCustomerDetail(nextCallbacks) {
  callbacks = { ...callbacks, ...nextCallbacks };
}

function buildMediaUrl(url) {
  if (!url) return "";
  if (/^(https?:|blob:|data:)/.test(url)) return url;

  const root = state.apiBaseUrl.replace(/\/api\/v1\/?$/, "");
  return `${root}${url.startsWith("/") ? url : `/${url}`}`;
}

function fileKey(file) {
  return `${file.name}:${file.size}:${file.lastModified}`;
}

export function toggleExpandedRecord(recordId) {
  if (state.expandedRecordIds.has(recordId)) {
    state.expandedRecordIds.delete(recordId);
  } else {
    state.expandedRecordIds.add(recordId);
  }
  renderCustomerDetail();
}

export function renderSelectedImages() {
  const files = state.selectedRecordFiles;
  if (!files.length) {
    els.addRecordImagePreview.innerHTML = "";
    return;
  }

  els.addRecordImagePreview.innerHTML = files
    .map((file) => {
      const objectUrl = URL.createObjectURL(file);
      return `
        <div class="image-preview-item" title="${callbacks.escapeHtml(file.name)}">
          <button
            type="button"
            class="image-preview-thumb"
            data-selected-image-preview="${callbacks.escapeHtml(fileKey(file))}"
            aria-label="预览${callbacks.escapeHtml(file.name)}"
          >
          <img src="${objectUrl}" alt="${callbacks.escapeHtml(file.name)}" />
          </button>
          <button
            type="button"
            class="image-remove-chip selected-image-chip"
            data-selected-image-remove="${callbacks.escapeHtml(fileKey(file))}"
            aria-label="移除图片"
          >
            ×
          </button>
        </div>
      `;
    })
    .join("");
}

export function mergeSelectedImages(incomingFiles) {
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

export function removeSelectedImage(keyToRemove) {
  const dataTransfer = new DataTransfer();
  state.selectedRecordFiles
    .filter((file) => fileKey(file) !== keyToRemove)
    .forEach((file) => dataTransfer.items.add(file));
  state.selectedRecordFiles = Array.from(dataTransfer.files);
  els.addRecordImages.files = dataTransfer.files;
  renderSelectedImages();
}

export function renderExistingRecordImages() {
  if (!state.editingRecordImages.length) {
    els.existingRecordImagesWrap.classList.add("hidden");
    els.existingRecordImages.innerHTML = "";
    return;
  }

  els.existingRecordImagesWrap.classList.remove("hidden");
  els.existingRecordImages.innerHTML = state.editingRecordImages
    .map(
      (image) => `
        <div class="image-preview-item existing-image-item" title="${callbacks.escapeHtml(image.name || "图片")}">
          <button
            type="button"
            class="image-preview-thumb"
            data-preview-image="${callbacks.escapeHtml(image.url)}"
            data-preview-alt="${callbacks.escapeHtml(image.name || "图片")}"
            aria-label="预览${callbacks.escapeHtml(image.name || "图片")}"
          >
          <img src="${buildMediaUrl(image.url)}" alt="${callbacks.escapeHtml(image.name || "图片")}" />
          </button>
          <button
            type="button"
            class="image-remove-chip"
            data-existing-image-remove="${callbacks.escapeHtml(image.url)}"
            aria-label="删除图片"
          >
            ×
          </button>
        </div>
      `,
    )
    .join("");
}

export function setRecordSaving(isSaving) {
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

export function updateRecordImageModes(modeKey, inputNodes) {
  state.recordImageModes[modeKey] = Array.from(inputNodes)
    .filter((input) => input.checked)
    .map((input) => input.value);
}

export function toggleExpandedRecordAnalysis(analysisKey) {
  if (state.expandedRecordAnalysisKeys.has(analysisKey)) {
    state.expandedRecordAnalysisKeys.delete(analysisKey);
  } else {
    state.expandedRecordAnalysisKeys.add(analysisKey);
  }
  renderCustomerDetail();
}

export function resetRecordDialog() {
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

export function openCreateRecordDialog() {
  if (!state.selectedCustomerId) {
    callbacks.showToast("请先选择一位客户");
    return;
  }
  resetRecordDialog();
  els.addRecordDialog.showModal();
}

export function openEditRecordDialog(recordId) {
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

export function openImagePreview(url, altText) {
  els.imagePreviewTarget.src = buildMediaUrl(url);
  els.imagePreviewTarget.alt = altText || "图片预览";
  els.imagePreviewDialog.showModal();
}

export function openSelectedImagePreview(imageKey) {
  const file = state.selectedRecordFiles.find((item) => fileKey(item) === imageKey);
  if (!file) return;
  openImagePreview(URL.createObjectURL(file), file.name);
}

export function closeImagePreview() {
  els.imagePreviewDialog.close();
  els.imagePreviewTarget.removeAttribute("src");
}

export function renderCustomerDetail() {
  const detail = state.customerDetail;

  if (!detail) {
    callbacks.setDetailVisibility(false);
    return;
  }

  const hasAdvice = Boolean(state.adviceText);
  const hasSummary = Boolean(detail.summary_text);

  els.customerName.textContent = detail.name;
  const locationInfo = detail.location_raw
    ? `${detail.location_city || ""}${detail.location_district || ""}${detail.location_subarea || ""} (${detail.location_raw})`
    : "地址未填写";
  const profileParts = [
    detail.phone || "电话未填写",
    detail.gender || "性别未填写",
    detail.age !== null && detail.age !== undefined ? `${detail.age}岁` : "",
    detail.birthday ? `生日 ${detail.birthday}` : "",
  ].filter(Boolean);
  els.customerMeta.textContent = `${profileParts.join(" · ")}\n${locationInfo}\n创建于 ${callbacks.formatDate(detail.created_at)}`;
  els.customerTags.innerHTML = (detail.tags || []).length
    ? detail.tags.map((tag) => `<span class="tag">${callbacks.escapeHtml(tag)}</span>`).join("")
    : `<span class="tag">暂无标签</span>`;
  els.summaryBody.textContent =
    detail.summary_text || "这位客户还没有摘要。你可以先生成一次，看看桌面版是否能把零散记录整理成可跟进的信息。";
  els.adviceBody.textContent =
    state.adviceText || "点击“生成拜访建议”后，这里会显示结构化建议。";
  els.adviceUpdatedAt.textContent = state.adviceUpdatedAt
    ? `上次生成时间：${callbacks.formatDate(state.adviceUpdatedAt)}`
    : "";
  els.copySummary.disabled = !hasSummary;
  els.exportSummary.disabled = !hasSummary;
  els.copyAdvice.disabled = !hasAdvice;
  els.exportAdvice.disabled = !hasAdvice;

  if (!state.records.length) {
    els.recordList.innerHTML = `
      <div class="empty-state">
        <h3>还没有沟通记录</h3>
        <p>可以点击“添加拜访记录”录入文字、地点线索和图片，保存后会回到这里。</p>
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
                <button class="icon-button icon-button-soft icon-button-small" type="button" title="编辑记录" aria-label="编辑记录" data-record-edit="${record.id}">
                  <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 20h4l10-10l-4-4L4 16z" /><path d="M13 7l4 4" /></svg>
                </button>
                <button class="icon-button icon-button-accent icon-button-small" type="button" title="删除记录" aria-label="删除记录" data-record-delete="${record.id}">
                  <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16" /><path d="M9 7V5h6v2" /><path d="M7 7l1 12h8l1-12" /><path d="M10 11v5" /><path d="M14 11v5" /></svg>
                </button>
              </div>
            </div>
            <div class="record-body ${expanded ? "expanded" : "collapsed"}">
              <p>${callbacks.escapeHtml(record.content)}</p>
            </div>
            ${
              record.location_raw
                ? `<p class="meta-line">地点线索：${callbacks.escapeHtml(record.location_raw)}${
                    record.location_city || record.location_district || record.location_subarea
                      ? `（${callbacks.escapeHtml(
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
                    .map((image) => {
                      const analyzeKey = `${record.id}:${image.url}`;
                      const isAnalyzing = state.analyzingRecordImageKey === analyzeKey;
                      const selectedModes = state.recordImageModes[analyzeKey] || [];
                      const analysisAnswer = image.vision?.answer || "";
                      const analysisExpanded = state.expandedRecordAnalysisKeys.has(analyzeKey);
                      const analysisNeedsToggle = String(analysisAnswer).length > 280 || String(analysisAnswer).includes("\n");
                      return `
                        <div class="record-image-card">
                          <button type="button" class="record-image-button" data-preview-image="${callbacks.escapeHtml(image.url)}" data-preview-alt="${callbacks.escapeHtml(image.name || "记录图片")}" title="${callbacks.escapeHtml(image.name || "图片")}">
                            <img src="${buildMediaUrl(image.url)}" alt="${callbacks.escapeHtml(image.name || "记录图片")}" />
                          </button>
                          <div class="record-image-content">
                            <div class="record-image-actions">
                              <div class="record-image-modes">
                                <label class="record-image-mode"><input type="checkbox" value="output_table" data-record-image-mode-key="${callbacks.escapeHtml(analyzeKey)}" ${selectedModes.includes("output_table") ? "checked" : ""} /><span>输出表格</span></label>
                                <label class="record-image-mode"><input type="checkbox" value="extract_key_points" data-record-image-mode-key="${callbacks.escapeHtml(analyzeKey)}" ${selectedModes.includes("extract_key_points") ? "checked" : ""} /><span>提取重点</span></label>
                                <label class="record-image-mode"><input type="checkbox" value="summarize_description" data-record-image-mode-key="${callbacks.escapeHtml(analyzeKey)}" ${selectedModes.includes("summarize_description") ? "checked" : ""} /><span>总结成说明</span></label>
                                <label class="record-image-mode"><input type="checkbox" value="extract_customer_info" data-record-image-mode-key="${callbacks.escapeHtml(analyzeKey)}" ${selectedModes.includes("extract_customer_info") ? "checked" : ""} /><span>提取客户信息</span></label>
                              </div>
                              <button type="button" class="button button-ghost button-small record-image-analyze" data-record-image-analyze="${record.id}" data-record-image-url="${callbacks.escapeHtml(image.url)}" ${isAnalyzing ? "disabled" : ""}>
                                ${isAnalyzing ? "识别中..." : "识别图片"}
                              </button>
                            </div>
                            ${
                              analysisAnswer
                                ? `<div class="record-image-analysis ${analysisExpanded ? "expanded" : "collapsed"}">
                                    <div class="record-image-analysis-label">识别结果</div>
                                    <div class="record-image-analysis-body">${callbacks.renderRichText(analysisAnswer)}</div>
                                    ${
                                      analysisNeedsToggle
                                        ? `<button
                                            type="button"
                                            class="record-more"
                                            data-record-analysis-toggle="${callbacks.escapeHtml(analyzeKey)}"
                                          >
                                            ${analysisExpanded ? "收起识别结果" : "展开识别结果"}
                                          </button>`
                                        : ""
                                    }
                                  </div>`
                                : ""
                            }
                          </div>
                        </div>
                      `;
                    })
                    .join("")}</div>`
                : ""
            }
            <time>${callbacks.formatDate(record.created_at)}</time>
          </article>
        `;
      })
      .join("");
  }

  callbacks.setDetailVisibility(true);
}

export async function loadCustomerDetail(customerId, options = {}) {
  if (!state.authToken) return;
  const preserveScroll = Boolean(options.preserveScroll);
  const previousScrollTop = preserveScroll ? els.detailContent.scrollTop : 0;
  state.selectedCustomerId = customerId;
  renderCustomerList();
  if (!preserveScroll) {
    els.detailContent.scrollTo({ top: 0, behavior: "auto" });
  }
  callbacks.setActiveSectionNav("summary-section");

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
    callbacks.updateActiveSectionNavFromScroll();
  } catch (error) {
    callbacks.showToast(error.message);
  }
}

export async function createRecord(formData) {
  if (!state.authToken) return;
  if (!state.selectedCustomerId) return;

  const customerId = state.selectedCustomerId;
  const wasEditing = Boolean(state.editingRecordId);
  const content = String(formData.get("content") || "").trim();
  if (!content) {
    callbacks.showToast("请输入记录内容");
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

    els.addRecordDialog.close();
    resetRecordDialog();
    callbacks.showToast(wasEditing ? "拜访记录已更新，正在更新客户画像和拜访建议..." : "拜访记录已添加，正在更新客户画像和拜访建议...");
    await loadCustomerDetail(customerId, { preserveScroll: true });
    await refreshCustomerAiArtifacts({ silent: true });
    callbacks.showToast("客户画像和拜访建议已更新");
  } finally {
    setRecordSaving(false);
  }
}

export async function deleteRecord(recordId) {
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
  callbacks.showToast("记录已删除");
  await loadCustomerDetail(state.selectedCustomerId, { preserveScroll: true });
}

export async function analyzeRecordImage(recordId, imageUrl, analyzeModes = []) {
  state.analyzingRecordImageKey = `${recordId}:${imageUrl}`;
  renderCustomerDetail();

  try {
    const formData = new FormData();
    formData.set("image_url", imageUrl);
    analyzeModes.forEach((mode) => formData.append("analyze_modes", mode));
    await apiFetchForm(`/records/${recordId}/images/analyze`, formData);
    callbacks.showToast("图片识别完成");
    await loadCustomerDetail(state.selectedCustomerId, { preserveScroll: true });
  } catch (error) {
    callbacks.showToast(error.message);
  } finally {
    state.analyzingRecordImageKey = "";
    renderCustomerDetail();
  }
}

export async function generateSummary(options = {}) {
  if (!state.selectedCustomerId) return;

  const silent = Boolean(options.silent);
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
    if (!silent) {
      callbacks.showToast("摘要已更新");
    }
    return result;
  } catch (error) {
    renderCustomerDetail();
    if (!silent) {
      callbacks.showToast(error.message);
      return null;
    }
    throw error;
  }
}

function needsSummaryRefresh() {
  return !state.customerDetail?.summary_text || state.customerDetail.summary_status !== "ready";
}

export async function generateAdvice(options = {}) {
  if (!state.selectedCustomerId) return;

  const silent = Boolean(options.silent);
  const refreshSummaryFirst = Boolean(options.refreshSummaryFirst);
  els.adviceBody.textContent = "正在生成拜访建议...";

  try {
    if (refreshSummaryFirst || needsSummaryRefresh()) {
      await generateSummary({ silent: true });
      els.adviceBody.textContent = "正在生成拜访建议...";
    }

    const result = await apiFetch(`/customers/${state.selectedCustomerId}/advice/generate`, {
      method: "POST",
    });

    state.adviceText = result.advice_text || result.advice || "暂无建议";
    state.adviceUpdatedAt = result.updated_at || "";
    renderCustomerDetail();
    if (!silent) {
      callbacks.showToast("拜访建议已生成");
    }
    return result;
  } catch (error) {
    renderCustomerDetail();
    if (!silent) {
      callbacks.showToast(error.message);
      return null;
    }
    throw error;
  }
}

export async function refreshCustomerAiArtifacts(options = {}) {
  if (!state.selectedCustomerId) return;
  const silent = Boolean(options.silent);

  try {
    await generateSummary({ silent: true });
    await generateAdvice({ silent: true });
    if (!silent) {
      callbacks.showToast("客户画像和拜访建议已更新");
    }
  } catch (error) {
    if (!silent) {
      callbacks.showToast(error.message);
    } else {
      callbacks.showToast(`AI 自动更新失败：${error.message}`);
    }
  }
}

export async function copyAdvice() {
  if (!state.adviceText) return;

  await navigator.clipboard.writeText(state.adviceText);
  callbacks.showToast("拜访建议已复制");
}

export async function copySummary() {
  const summaryText = state.customerDetail?.summary_text || "";
  if (!summaryText) return;

  await navigator.clipboard.writeText(summaryText);
  callbacks.showToast("客户画像摘要已复制");
}

export async function exportAdvice() {
  if (!state.adviceText || !state.customerDetail) return;

  const exportText = [
    `客户：${state.customerDetail.name}`,
    state.adviceUpdatedAt ? `生成时间：${callbacks.formatDate(state.adviceUpdatedAt)}` : "",
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
      callbacks.showToast("拜访建议已分享");
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
  callbacks.showToast("拜访建议已导出");
}

export async function exportSummary() {
  const summaryText = state.customerDetail?.summary_text || "";
  if (!summaryText || !state.customerDetail) return;

  const exportText = [`客户：${state.customerDetail.name}`, "", summaryText].join("\n");

  if (navigator.share) {
    try {
      await navigator.share({
        title: `${state.customerDetail.name} - 客户画像摘要`,
        text: exportText,
      });
      callbacks.showToast("客户画像摘要已分享");
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
  callbacks.showToast("客户画像摘要已导出");
}

export async function askCustomerQuestion(question) {
  if (!state.authToken) return;
  if (!state.selectedCustomerId || !question.trim()) return;

  els.customerChatAnswer.classList.remove("hidden");
  els.customerChatAnswer.textContent = "正在思考...";

  try {
    const result = await apiFetch(`/customers/${state.selectedCustomerId}/chat`, {
      method: "POST",
      body: { question: question.trim() },
    });

    els.customerChatAnswer.innerHTML = callbacks.renderRichText(result.answer || "暂无回答");
  } catch (error) {
    els.customerChatAnswer.textContent = error.message;
  }
}
