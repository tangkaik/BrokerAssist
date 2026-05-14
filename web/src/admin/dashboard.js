import { buildUrl } from "../api.js";
import { state } from "../state.js";

export async function loadDashboard() {
  const container = document.getElementById("tab-dashboard");
  try {
    const res = await fetch(buildUrl("/admin/stats"), {
      headers: { Authorization: `Bearer ${state.authToken}` },
    });
    const payload = await res.json();
    if (!payload.success) throw new Error(payload.error?.message || "加载失败");
    const d = payload.data;
    container.innerHTML = `
      <div class="stats-grid">
        <div class="stat-card">
          <div class="stat-value">${d.total_users}</div>
          <div class="stat-label">总用户数</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">${d.total_customers}</div>
          <div class="stat-label">总客户数</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">${d.monthly_ai_calls}</div>
          <div class="stat-label">本月 AI 调用</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">${d.active_users_7d}</div>
          <div class="stat-label">近7天活跃用户</div>
        </div>
      </div>
      <div class="chart-container">
        <h3>近30天 AI 调用趋势</h3>
        ${renderLineChart(d.daily_calls)}
      </div>
      <div class="chart-container">
        <h3>行业分布（用户数）</h3>
        ${renderBarChart(d.industry_distribution)}
      </div>
    `;
  } catch (e) {
    container.innerHTML = `<p class="error">${e.message}</p>`;
  }
}

function renderLineChart(data) {
  if (!data || !data.length) return '<p class="muted">暂无数据</p>';
  const max = Math.max(...data.map((d) => d.calls), 1);
  const w = 600, h = 160, pad = 20;
  const stepX = (w - pad * 2) / (data.length - 1 || 1);
  const points = data.map((d, i) => {
    const x = pad + i * stepX;
    const y = h - pad - (d.calls / max) * (h - pad * 2);
    return `${x},${y}`;
  }).join(" ");
  return `<svg class="line-chart-svg" viewBox="0 0 ${w} ${h}">
    <line x1="${pad}" y1="${h - pad}" x2="${w - pad}" y2="${h - pad}" />
    <line x1="${pad}" y1="${pad}" x2="${pad}" y2="${h - pad}" />
    <polyline points="${points}" />
  </svg>`;
}

function renderBarChart(data) {
  if (!data || !data.length) return '<p class="muted">暂无数据</p>';
  const max = Math.max(...data.map((d) => d.user_count), 1);
  return data.map((d) => `
    <div class="bar-chart-row">
      <span class="bar-chart-label">${escapeHtml(d.industry_key)}</span>
      <div class="bar-chart-bar" style="width: ${Math.max((d.user_count / max) * 200, 4)}px"></div>
      <span class="bar-chart-value">${d.user_count} 人</span>
    </div>
  `).join("");
}

function escapeHtml(s) {
  const div = document.createElement("div");
  div.textContent = String(s ?? "");
  return div.innerHTML;
}
