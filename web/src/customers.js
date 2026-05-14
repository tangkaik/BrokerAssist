import { apiDownload, apiFetch, apiFetchForm } from "./api.js";
import { els } from "./dom.js";
import { state } from "./state.js";

let callbacks = {
  loadCustomerDetail: async () => {},
  renderCustomerDetail: () => {},
  renderGlobalSuggestions: () => {},
  showToast: () => {},
  splitTags: () => [],
  escapeHtml: (text) => String(text ?? ""),
  formatDate: (value) => String(value ?? ""),
};

export function configureCustomers(nextCallbacks) {
  callbacks = { ...callbacks, ...nextCallbacks };
}

export function findCustomerNameById(customerId) {
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

export function renderCustomerList() {
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
        .map((tag) => `<span class="tag">${callbacks.escapeHtml(tag)}</span>`)
        .join("");

      return `
        <article class="customer-item ${active}" data-customer-id="${customer.id}">
          <h3>${callbacks.escapeHtml(customer.name)}</h3>
          <p>${callbacks.escapeHtml(customer.phone || "未填写电话")}</p>
          <div class="tag-row">${tags}</div>
          <small>更新于 ${callbacks.formatDate(customer.updated_at || customer.created_at)}</small>
        </article>
      `;
    })
    .join("");
}

export async function loadCustomers() {
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
    callbacks.renderGlobalSuggestions();
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
      await callbacks.loadCustomerDetail(state.selectedCustomerId);
    } else {
      state.customerDetail = null;
      state.records = [];
      callbacks.renderCustomerDetail();
    }
  } catch (error) {
    renderCustomerList();
    callbacks.showToast(error.message);
  }
}

export async function createCustomer(formData) {
  if (!state.authToken) return;
  const data = await apiFetch("/customers", {
    method: "POST",
    body: {
      name: String(formData.get("name") || "").trim(),
      phone: String(formData.get("phone") || "").trim() || undefined,
      gender: String(formData.get("gender") || "").trim() || undefined,
      age: String(formData.get("age") || "").trim()
        ? Number(String(formData.get("age")).trim())
        : undefined,
      birthday: String(formData.get("birthday") || "").trim() || undefined,
      location: String(formData.get("location") || "").trim() || undefined,
      tags: callbacks.splitTags(formData.get("tags")),
    },
  });

  callbacks.showToast("客户已创建");
  els.createCustomerDialog.close();
  els.createCustomerForm.reset();
  state.selectedCustomerId = data.customer_id;
  await loadCustomers();
}

export async function updateCustomer(formData) {
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
        age: String(formData.get("age") || "").trim()
          ? Number(String(formData.get("age")).trim())
          : undefined,
        birthday: String(formData.get("birthday") || "").trim() || undefined,
        location: String(formData.get("location") || "").trim() || undefined,
        tags: callbacks.splitTags(formData.get("tags")),
      },
    });

    callbacks.showToast("客户信息已更新");
    els.editCustomerDialog.close();
    await loadCustomers();
    await callbacks.loadCustomerDetail(state.selectedCustomerId, { preserveScroll: true });
  } finally {
    els.editCustomerSubmit.disabled = false;
    els.editCustomerSubmit.textContent = "保存客户信息";
  }
}

export function openEditCustomerDialog() {
  if (!state.customerDetail) {
    callbacks.showToast("请先选择一位客户");
    return;
  }

  els.editCustomerForm.elements.name.value = state.customerDetail.name || "";
  els.editCustomerForm.elements.phone.value = state.customerDetail.phone || "";
  els.editCustomerForm.elements.gender.value = state.customerDetail.gender || "";
  els.editCustomerForm.elements.age.value = state.customerDetail.age ?? "";
  els.editCustomerForm.elements.birthday.value = state.customerDetail.birthday || "";
  els.editCustomerForm.elements.location.value = state.customerDetail.location_raw || "";
  els.editCustomerForm.elements.tags.value = (state.customerDetail.tags || []).join("，");
  els.editCustomerDialog.showModal();
}

export async function deleteCurrentCustomer() {
  if (!state.authToken) return;
  if (!state.selectedCustomerId || !state.customerDetail) return;

  const confirmed = window.confirm(`确定要删除客户“${state.customerDetail.name}”吗？`);
  if (!confirmed) return;

  try {
    await apiFetch(`/customers/${state.selectedCustomerId}`, {
      method: "DELETE",
    });

    callbacks.showToast("客户已删除");
    state.selectedCustomerId = null;
    state.customerDetail = null;
    state.records = [];
    state.adviceText = "";
    state.adviceUpdatedAt = "";
    callbacks.renderCustomerDetail();
    await loadCustomers();
  } catch (error) {
    callbacks.showToast(error.message);
  }
}

export async function exportCustomersExcel() {
  if (!state.authToken) return;

  els.exportCustomers.disabled = true;
  els.exportCustomers.textContent = "导出中...";
  try {
    const result = await apiDownload("/customers/export", {
      filename: "客户导出.xlsx",
    });
    callbacks.showToast(`客户 Excel 已导出：${result.filename}`);
  } finally {
    els.exportCustomers.disabled = false;
    els.exportCustomers.textContent = "导出客户 Excel";
  }
}

export async function importCustomersExcel(file) {
  if (!state.authToken || !file) return;

  const formData = new FormData();
  formData.set("file", file);

  els.importCustomers.disabled = true;
  els.importCustomers.textContent = "导入中...";
  try {
    const result = await apiFetchForm("/customers/import", formData);
    const parts = [
      `新增 ${result.created || 0} 位`,
      `跳过 ${result.skipped || 0} 位`,
      `失败 ${result.failed || 0} 行`,
    ];
    callbacks.showToast(`导入完成：${parts.join("，")}`);
    await loadCustomers();
  } finally {
    els.importCustomers.disabled = false;
    els.importCustomers.textContent = "导入客户 Excel";
    els.importCustomersFile.value = "";
  }
}
