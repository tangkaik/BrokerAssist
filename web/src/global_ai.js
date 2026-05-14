import { apiFetch, apiFetchForm } from "./api.js";
import { els } from "./dom.js";
import {
  GLOBAL_CHAT_CONTEXT_LIMIT,
  GLOBAL_CHAT_HISTORY_PREFIX,
  GLOBAL_SEARCH_HISTORY_PREFIX,
  state,
} from "./state.js";

const SEARCH_HISTORY_LIMIT = 10;
const MAX_LINES_PER_MESSAGE = 100;

let callbacks = {
  showToast: () => {},
  formatDate: (value) => String(value ?? ""),
  escapeHtml: (text) => String(text ?? ""),
  renderRichText: (text) => String(text ?? ""),
};

export function configureGlobalAi(nextCallbacks) {
  callbacks = { ...callbacks, ...nextCallbacks };
}

function fileKey(file) {
  return `${file.name}:${file.size}:${file.lastModified}`;
}

function getUserScope() {
  const user = state.currentUser || {};
  return user.id || user.account || "anonymous";
}

function getChatHistoryKey() {
  return `${GLOBAL_CHAT_HISTORY_PREFIX}${getUserScope()}`;
}

function getSearchHistoryKey() {
  return `${GLOBAL_SEARCH_HISTORY_PREFIX}${getUserScope()}`;
}

function safeParseArray(value) {
  try {
    const parsed = JSON.parse(value || "[]");
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function persistGlobalChat() {
  if (!state.currentUser) return;
  localStorage.setItem(getChatHistoryKey(), JSON.stringify(state.globalMessages.slice(-80)));
}

function persistGlobalSearchHistory() {
  if (!state.currentUser) return;
  localStorage.setItem(getSearchHistoryKey(), JSON.stringify(state.globalSearchHistory));
}

function addGlobalSearchHistory(question) {
  const normalized = String(question || "").trim();
  if (!normalized) return;
  state.globalSearchHistory = [
    normalized,
    ...state.globalSearchHistory.filter((item) => item !== normalized),
  ].slice(0, SEARCH_HISTORY_LIMIT);
  persistGlobalSearchHistory();
}

export function loadGlobalChatState() {
  if (!state.currentUser) {
    state.globalMessages = [];
    state.globalSearchHistory = [];
    state.globalPendingAnswerLines = [];
    state.globalPendingAnswerIndex = 0;
    state.globalSuggestionsHidden = false;
    renderGlobalChat();
    renderGlobalSuggestions();
    return;
  }

  state.globalMessages = safeParseArray(localStorage.getItem(getChatHistoryKey()))
    .filter(
      (message) =>
        (message.role === "user" || message.role === "assistant") &&
        String(message.content || "").trim(),
    )
    .map((message) => ({ ...message, hasMoreAnswer: false }));
  state.globalSearchHistory = safeParseArray(localStorage.getItem(getSearchHistoryKey()))
    .map((item) => String(item || "").trim())
    .filter(Boolean)
    .slice(0, SEARCH_HISTORY_LIMIT);
  state.globalPendingAnswerLines = [];
  state.globalPendingAnswerIndex = 0;
  state.globalSuggestionsHidden = state.globalMessages.length > 0;
  renderGlobalChat();
  renderGlobalSuggestions();
}

export function hideGlobalSuggestions() {
  state.globalSuggestionsHidden = true;
  els.globalSuggestions.classList.add("hidden");
}

function pickCustomerNames(limit = 2) {
  return state.customers
    .map((customer) => String(customer.name || "").trim())
    .filter(Boolean)
    .slice(0, limit);
}

function buildSuggestionGroups() {
  const [primaryName, secondaryName] = pickCustomerNames(2);
  const firstCustomer = primaryName || "某位客户";
  const secondCustomer = secondaryName || primaryName || "某位客户";

  const groups = [
    {
      title: "客户数据",
      questions: [
        "列出最近一个月没有联系的客户",
        "哪些客户最适合本周优先约见？",
        "找出有明确预算但还没推进下一步的客户",
      ],
    },
    {
      title: "业务处理",
      questions: [
        `给${firstCustomer}写一段跟进微信`,
        `总结${secondCustomer}上次沟通，并给出这次建议`,
        `明天见${firstCustomer}，帮我准备会谈简报`,
      ],
    },
    {
      title: "产品用法",
      questions: [
        "新增沟通记录后客户画像会自动更新吗？",
        "怎么导出客户数据？",
        "图片识别结果在哪里看？",
      ],
    },
  ];

  if (state.globalSearchHistory.length) {
    groups.unshift({
      title: "最近提问",
      questions: state.globalSearchHistory.slice(0, 3),
    });
  }

  return groups;
}

export function renderGlobalSuggestions() {
  if (!els.globalSuggestions || state.globalSuggestionsHidden) return;

  els.globalSuggestions.classList.remove("hidden");
  els.globalSuggestions.innerHTML = buildSuggestionGroups()
    .map(
      (group) => `
        <section class="suggestion-group" aria-label="${callbacks.escapeHtml(group.title)}">
          <div class="suggestion-group-title">${callbacks.escapeHtml(group.title)}</div>
          <div class="suggestion-group-list">
            ${group.questions
              .map(
                (question) => `
                  <button class="suggestion-chip" type="button" data-question="${callbacks.escapeHtml(question)}">
                    ${callbacks.escapeHtml(question)}
                  </button>
                `,
              )
              .join("")}
          </div>
        </section>
      `,
    )
    .join("");
}

export function renderGlobalChatAttachments() {
  if (!state.globalChatFiles.length) {
    els.globalChatAttachments.innerHTML = "";
    els.globalChatAttachments.classList.add("hidden");
    return;
  }

  els.globalChatAttachments.classList.remove("hidden");
  els.globalChatAttachments.innerHTML = state.globalChatFiles
    .map(
      (file) => `
        <div class="composer-chip" title="${callbacks.escapeHtml(file.name)}">
          <span class="composer-chip-name">${callbacks.escapeHtml(file.name)}</span>
          <button
            type="button"
            class="composer-chip-remove"
            data-global-chat-file-remove="${callbacks.escapeHtml(fileKey(file))}"
            aria-label="移除附件"
          >
            ×
          </button>
        </div>
      `,
    )
    .join("");
}

export function mergeGlobalChatFiles(incomingFiles) {
  const dataTransfer = new DataTransfer();
  const firstFile = incomingFiles[0];
  if (firstFile) {
    dataTransfer.items.add(firstFile);
  }

  state.globalChatFiles = Array.from(dataTransfer.files);
  els.globalChatFiles.files = dataTransfer.files;
  renderGlobalChatAttachments();
}

export function removeGlobalChatFile(keyToRemove) {
  const dataTransfer = new DataTransfer();
  state.globalChatFiles
    .filter((file) => fileKey(file) !== keyToRemove)
    .forEach((file) => dataTransfer.items.add(file));
  state.globalChatFiles = Array.from(dataTransfer.files);
  els.globalChatFiles.files = dataTransfer.files;
  renderGlobalChatAttachments();
}

export function clearGlobalChatFiles() {
  state.globalChatFiles = [];
  els.globalChatFiles.value = "";
  renderGlobalChatAttachments();
}

export function clearGlobalChat() {
  state.globalMessages = [];
  state.globalPendingAnswerLines = [];
  state.globalPendingAnswerIndex = 0;
  state.globalSuggestionsHidden = false;
  if (state.currentUser) {
    localStorage.removeItem(getChatHistoryKey());
  }
  renderGlobalChat();
  renderGlobalSuggestions();
}

function extractFirstCustomerLink(text) {
  const match = String(text || "").match(/\[([^[\]|]+)\|([0-9a-fA-F-]{36})\]/);
  if (!match) return null;
  return { name: match[1], id: match[2] };
}

function buildGlobalFollowupActions(message) {
  if (message.role !== "assistant") return "";

  const content = String(message.content || "");
  const customer = extractFirstCustomerLink(content);
  if (!customer) return "";

  const looksActionable =
    content.includes("还不能") ||
    content.includes("资料还不够") ||
    content.includes("请先") ||
    content.includes("信息不足");
  if (!looksActionable) return "";

  const actions = [
    { key: "open_customer", label: `查看${customer.name}` },
  ];

  if (content.includes("沟通记录") || content.includes("真实沟通") || content.includes("保存一条")) {
    actions.push({ key: "add_record", label: "添加沟通记录" });
  }
  if (content.includes("客户画像") || content.includes("画像")) {
    actions.push({ key: "generate_summary", label: "生成画像" });
  }
  if (content.includes("下一步建议") || content.includes("建议")) {
    actions.push({ key: "generate_advice", label: "生成建议" });
  }

  return `
    <div class="chat-followup-actions" aria-label="可执行下一步">
      ${actions
        .map(
          (action) => `
            <button
              type="button"
              class="button button-ghost button-small"
              data-global-action="${callbacks.escapeHtml(action.key)}"
              data-global-action-customer="${callbacks.escapeHtml(customer.id)}"
            >${callbacks.escapeHtml(action.label)}</button>
          `,
        )
        .join("")}
    </div>
  `;
}

export function renderGlobalChat() {
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
          ? callbacks.renderRichText(message.content)
          : callbacks.escapeHtml(message.content).replace(/\n/g, "<br />");

      return `
        <article class="chat-message ${message.role}">
          <header>
            <span>${message.role === "user" ? "你" : "BrokerAssist"}</span>
            <span>${callbacks.formatDate(message.time)}</span>
          </header>
          <div class="chat-message-body">${content}</div>
          ${buildGlobalFollowupActions(message)}
          ${
            message.role === "assistant" &&
            index === state.globalMessages.length - 1 &&
            message.hasMoreAnswer
              ? `<div class="chat-followup-actions">
                  <button
                    type="button"
                    class="button button-ghost button-small"
                    data-global-continue-answer="true"
                  >继续</button>
                </div>`
              : ""
          }
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

function getFriendlyGlobalErrorMessage(rawMessage, { hasImage = false } = {}) {
  const message = String(rawMessage || "").trim();
  if (hasImage) {
    return "图片识别暂时不可用。可以先把图片里的文字或关键信息发给我，我会继续基于文本帮你分析。";
  }
  if (!message || message === "未知错误") {
    return "AI 助手暂时没有返回结果，请稍后再试。";
  }
  if (
    message.includes("服务暂时不可用") ||
    message.includes("请求失败") ||
    message.includes("网络连接失败") ||
    message.includes("Failed to fetch")
  ) {
    return "AI 助手暂时连接不上服务，请稍后再试。";
  }
  return message;
}

export function showNextGlobalAnswerPart() {
  if (!state.globalPendingAnswerLines.length) return false;

  const start = state.globalPendingAnswerIndex;
  const end = Math.min(start + MAX_LINES_PER_MESSAGE, state.globalPendingAnswerLines.length);
  const partLines = state.globalPendingAnswerLines.slice(start, end);
  state.globalPendingAnswerIndex = end;
  if (end < state.globalPendingAnswerLines.length) {
    partLines.push("");
    partLines.push("（内容较长，点击“继续”查看后续）");
  }

  if (end >= state.globalPendingAnswerLines.length) {
    state.globalPendingAnswerLines = [];
    state.globalPendingAnswerIndex = 0;
  }

  state.globalMessages.push({
    role: "assistant",
    content: partLines.join("\n"),
    hasMoreAnswer: end < state.globalPendingAnswerLines.length,
    time: new Date().toISOString(),
  });
  persistGlobalChat();
  renderGlobalChat();
  return true;
}

function appendGlobalAssistantAnswer(answer) {
  const fullAnswer = String(answer || "暂无回答");
  const lines = fullAnswer.split("\n");
  state.globalPendingAnswerLines = [];
  state.globalPendingAnswerIndex = 0;

  if (lines.length > MAX_LINES_PER_MESSAGE) {
    state.globalPendingAnswerLines = lines;
    state.globalPendingAnswerIndex = 0;
    showNextGlobalAnswerPart();
    return;
  }

  state.globalMessages.push({
    role: "assistant",
    content: fullAnswer,
    time: new Date().toISOString(),
  });
  persistGlobalChat();
  renderGlobalChat();
}

export async function copyGlobalAnswer(index) {
  const message = state.globalMessages[index];
  if (!message || message.role !== "assistant" || !message.content) return;
  await navigator.clipboard.writeText(message.content);
  callbacks.showToast("回答已复制");
}

export async function exportGlobalAnswer(index) {
  const message = state.globalMessages[index];
  if (!message || message.role !== "assistant" || !message.content) return;

  if (navigator.share) {
    try {
      await navigator.share({
        title: "BrokerAssist - AI问答",
        text: message.content,
      });
      callbacks.showToast("回答已分享");
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
  callbacks.showToast("回答已导出");
}

export async function askGlobalQuestion(question, imageFile = null) {
  if (!state.authToken) {
    callbacks.showToast("请先登录");
    return;
  }
  const effectiveQuestion = question.trim() || (imageFile ? "请识别这张图片并提取重点信息" : "");
  if (!effectiveQuestion) return;

  if (!imageFile && effectiveQuestion === "继续" && showNextGlobalAnswerPart()) {
    return;
  }

  const recentMessages = state.globalMessages
    .slice(-GLOBAL_CHAT_CONTEXT_LIMIT)
    .filter((message) => message.role === "user" || message.role === "assistant")
    .map((message) => ({
      role: message.role,
      content: String(message.content || "").slice(0, 2000),
    }))
    .filter((message) => message.content.trim());

  hideGlobalSuggestions();
  addGlobalSearchHistory(effectiveQuestion);
  state.globalMessages.push({
    role: "user",
    content: imageFile ? `${effectiveQuestion}\n\n[附图：${imageFile.name}]` : effectiveQuestion,
    time: new Date().toISOString(),
  });
  persistGlobalChat();
  renderGlobalChat();

  try {
    const result = imageFile
      ? await (async () => {
          const formData = new FormData();
          formData.set("question", effectiveQuestion);
          formData.set("image", imageFile);
          return apiFetchForm("/ai/chat-with-image", formData);
        })()
      : await apiFetch("/ai/chat", {
          method: "POST",
          body: { question: effectiveQuestion, recent_messages: recentMessages },
        });

    appendGlobalAssistantAnswer(result.answer);
  } catch (error) {
    const fallbackMessage = getFriendlyGlobalErrorMessage(error.message, { hasImage: Boolean(imageFile) });
    state.globalMessages.push({
      role: "assistant",
      content: fallbackMessage,
      time: new Date().toISOString(),
    });
    persistGlobalChat();
    renderGlobalChat();
  }
}
