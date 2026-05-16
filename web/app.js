import { setUnauthorizedHandler } from "./src/api.js";
import {
  clearAuthSession,
  configureAuth,
  renderAuthState,
  restoreSession,
  setAuthMode,
  submitLogin,
  submitRegister,
} from "./src/auth.js";
import {
  configureCustomers,
  createCustomer,
  deleteCurrentCustomer,
  exportCustomersExcel,
  findCustomerNameById,
  importCustomersExcel,
  loadCustomers,
  openEditCustomerDialog,
  renderCustomerList,
  updateCustomer,
} from "./src/customers.js";
import {
  analyzeRecordImage,
  askCustomerQuestion,
  closeImagePreview,
  configureCustomerDetail,
  copyAdvice,
  copySummary,
  createRecord,
  deleteRecord,
  exportAdvice,
  exportSummary,
  generateAdvice,
  generateSummary,
  loadCustomerDetail,
  mergeSelectedImages,
  openCreateRecordDialog,
  openEditRecordDialog,
  openImagePreview,
  removeSelectedImage,
  renderCustomerDetail,
  renderExistingRecordImages,
  resetRecordDialog,
  toggleExpandedRecord,
  toggleExpandedRecordAnalysis,
  updateRecordImageModes,
  openSelectedImagePreview,
} from "./src/customer_detail.js";
import {
  askGlobalQuestion,
  clearGlobalChat,
  clearGlobalChatFiles,
  configureGlobalAi,
  copyGlobalAnswer,
  exportGlobalAnswer,
  loadGlobalChatState,
  mergeGlobalChatFiles,
  removeGlobalChatFile,
  renderGlobalChat,
  renderGlobalSuggestions,
  showNextGlobalAnswerPart,
} from "./src/global_ai.js";
import { DEFAULT_API_BASE_URL, STORAGE_KEY, state } from "./src/state.js";
import { els } from "./src/dom.js";
import {
  configureUtils,
  escapeHtml,
  formatDate,
  renderRichText,
  splitTags,
} from "./src/utils.js";

els.apiBaseUrl.value = state.apiBaseUrl;
configureUtils({
  findCustomerNameById,
});
configureAuth({
  renderCustomerList,
  renderCustomerDetail,
  renderGlobalChat,
  showToast,
  loadCustomers,
});
configureCustomers({
  loadCustomerDetail,
  renderCustomerDetail,
  renderGlobalSuggestions,
  showToast,
  splitTags,
  escapeHtml,
  formatDate,
});
configureCustomerDetail({
  showToast,
  formatDate,
  escapeHtml,
  renderRichText,
  setDetailVisibility,
  setActiveSectionNav,
  updateActiveSectionNavFromScroll,
});
configureGlobalAi({
  showToast,
  formatDate,
  escapeHtml,
  renderRichText,
});
setUnauthorizedHandler(() => {
  clearAuthSession();
  renderAuthState();
  loadGlobalChatState();
});

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
    loadGlobalChatState();
  } catch (error) {
    showToast(error.message);
  }
});
els.registerForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    await submitRegister(new FormData(els.registerForm));
    loadGlobalChatState();
  } catch (error) {
    showToast(error.message);
  }
});
els.logoutButton.addEventListener("click", () => {
  clearAuthSession();
  renderAuthState();
  loadGlobalChatState();
  setAuthMode("login");
  showToast("已退出登录");
});
els.exportCustomers.addEventListener("click", async () => {
  try {
    await exportCustomersExcel();
  } catch (error) {
    showToast(error.message || "导出失败");
  }
});
els.importCustomers.addEventListener("click", () => {
  els.importGuideDialog.showModal();
});
els.closeImportGuide.addEventListener("click", () => {
  els.importGuideDialog.close();
});
els.importGuideDialog.addEventListener("click", (event) => {
  if (event.target === els.importGuideDialog) {
    els.importGuideDialog.close();
  }
});
els.chooseImportFile.addEventListener("click", () => {
  els.importGuideDialog.close();
  els.importCustomersFile.click();
});
els.importCustomersFile.addEventListener("change", async () => {
  const file = els.importCustomersFile.files?.[0];
  if (!file) return;
  try {
    await importCustomersExcel(file);
  } catch (error) {
    showToast(error.message || "导入失败");
    els.importCustomersFile.value = "";
  }
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

els.globalSuggestions.addEventListener("click", (event) => {
  const button = event.target.closest(".suggestion-chip");
  if (!button) return;
  askGlobalQuestion(button.dataset.question || "");
});

els.globalChatLog.addEventListener("click", async (event) => {
  const continueButton = event.target.closest("[data-global-continue-answer]");
  if (continueButton) {
    showNextGlobalAnswerPart();
    return;
  }

  const actionButton = event.target.closest("[data-global-action]");
  if (actionButton) {
    const customerId = actionButton.dataset.globalActionCustomer;
    if (!customerId) return;

    try {
      await loadCustomerDetail(customerId);
      els.detailContent.scrollTo({ top: 0, behavior: "smooth" });

      const action = actionButton.dataset.globalAction;
      if (action === "add_record") {
        openCreateRecordDialog();
      } else if (action === "generate_summary") {
        await generateSummary();
      } else if (action === "generate_advice") {
        await generateAdvice();
      }
    } catch (error) {
      showToast(error.message || "操作失败");
    }
    return;
  }

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
  clearGlobalChat();
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
  const previewButton = event.target.closest("[data-selected-image-preview]");
  if (previewButton) {
    openSelectedImagePreview(previewButton.dataset.selectedImagePreview);
    return;
  }

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
  const previewButton = event.target.closest("[data-preview-image]");
  if (previewButton) {
    openImagePreview(previewButton.dataset.previewImage, previewButton.dataset.previewAlt);
    return;
  }

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

  const analysisToggleButton = event.target.closest("[data-record-analysis-toggle]");
  if (analysisToggleButton) {
    toggleExpandedRecordAnalysis(analysisToggleButton.dataset.recordAnalysisToggle);
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
loadGlobalChatState();
setAuthMode("login");
renderAuthState();
restoreSession().then((isReady) => {
  if (isReady) {
    loadGlobalChatState();
    loadCustomers();
  }
});
