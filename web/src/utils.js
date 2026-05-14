let callbacks = {
  findCustomerNameById: (customerId) => customerId,
};

export function configureUtils(nextCallbacks) {
  callbacks = { ...callbacks, ...nextCallbacks };
}

export function formatDate(value) {
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

export function formatDateOnly(value) {
  if (!value) return "";

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return date.toISOString().slice(0, 10);
}

export function escapeHtml(text) {
  return String(text)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export function splitTags(value) {
  return String(value || "")
    .split(/[，,]/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function renderInlineMarkdown(text) {
  return escapeHtml(text).replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
}

function normalizeCustomerLinkSyntax(text) {
  return String(text || "")
    .replace(/([^\s\[]+)\[客户\d+\|ID:([0-9a-fA-F-]{36})\]/g, "[$1|$2]")
    .replace(/\[客户\d+\|ID:([0-9a-fA-F-]{36})\]/g, (_, customerId) => {
      return `[${callbacks.findCustomerNameById(customerId)}|${customerId}]`;
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

export function renderRichText(text) {
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
