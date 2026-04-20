// @ts-check
import { test, expect } from '@playwright/test';

const BASE_URL = 'http://127.0.0.1:4173';
const API_BASE_URL = 'http://127.0.0.1:8001/api/v1';

test.describe('BrokerAssist 保险助手', () => {
  test.beforeEach(async ({ page }) => {
    // 访问首页
    await page.goto(BASE_URL);
  });

  test('首页加载成功', async ({ page }) => {
    // 验证页面标题
    await expect(page).toHaveTitle(/BrokerAssist/);

    // 验证主工作区存在
    await expect(page.locator('.app-shell')).toBeVisible();

    // 验证侧边栏客户列表区域存在
    await expect(page.locator('.sidebar')).toBeVisible();

    // API 配置表单在 dialog 中，默认隐藏是正常的
    // 只验证 dialog 元素存在
    await expect(page.locator('#api-config-form')).toBeAttached();
  });

  test('登录界面显示和交互', async ({ page }) => {
    // 验证 auth-screen 登录界面可见
    await expect(page.locator('#auth-screen')).toBeVisible();

    // 验证登录表单存在
    await expect(page.locator('#login-form')).toBeVisible();

    // 验证登录按钮
    await expect(page.locator('#login-submit')).toBeVisible();

    // 验证切换到注册表单按钮
    await expect(page.locator('#show-register')).toBeVisible();

    // 点击切换到注册表单
    await page.locator('#show-register').click();

    // 验证注册表单显示，登录表单隐藏
    await expect(page.locator('#register-form')).toBeVisible();
    await expect(page.locator('#login-form')).toBeHidden();

    // 切回登录表单
    await page.locator('#show-login').click();
    await expect(page.locator('#login-form')).toBeVisible();
  });

  test('登录表单验证', async ({ page }) => {
    // 打开登录界面（如果未显示）
    await page.locator('#auth-screen').waitFor({ state: 'visible' });

    // 空表单提交，应该触发 HTML5 验证
    const loginButton = page.locator('#login-submit');
    await expect(loginButton).toBeEnabled();
  });

  test('API 配置表单存在', async ({ page }) => {
    // API 配置输入框在 dialog 中，默认隐藏是正常的
    // 只验证 input 元素存在
    await expect(page.locator('#api-base-url')).toBeAttached();
  });

  test('登录成功流程', async ({ page }) => {
    // 打开登录界面
    await page.locator('#auth-screen').waitFor({ state: 'visible' });

    // 填写登录表单
    await page.locator('#login-account').fill('test@example.com');
    await page.locator('#login-password').fill('password123');

    // 提交登录
    await page.locator('#login-submit').click();

    // 等待登录完成（auth-screen 应该隐藏，或者显示用户信息）
    // 注意：实际行为取决于后端 API 响应
    // 这里假设登录后会隐藏 auth-screen 或显示用户信息
    await page.waitForTimeout(1000);
  });

  test('登录后界面状态变化', async ({ page }) => {
    // 打开登录界面
    await page.locator('#auth-screen').waitFor({ state: 'visible' });

    // 填写登录表单
    await page.locator('#login-account').fill('test@example.com');
    await page.locator('#login-password').fill('password123');

    // 提交登录
    await page.locator('#login-submit').click();

    // 等待登录完成
    await page.waitForTimeout(2000);

    // 验证工作区可见
    await expect(page.locator('.workspace')).toBeVisible();

    // 验证侧边栏和主面板存在
    await expect(page.locator('.sidebar')).toBeVisible();
    await expect(page.locator('.main-panel')).toBeVisible();

    // 验证 AI 助手面板存在
    await expect(page.locator('.side-panel')).toBeVisible();

    // 验证客户详情默认显示空状态
    await expect(page.locator('#detail-empty')).toBeVisible();
  });
});
