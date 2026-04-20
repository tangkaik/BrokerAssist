// @ts-check
import { test, expect } from '@playwright/test';

const BASE_URL = 'http://127.0.0.1:4173';
const API_BASE_URL = 'http://127.0.0.1:8001/api/v1';

const TEST_ACCOUNT = 'e2e_test@example.com';
const TEST_PASSWORD = 'password123';
const TEST_NAME = 'E2E测试用户';

async function registerViaApi(account, password, name) {
  const response = await fetch(`${API_BASE_URL}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ account, password, name }),
  });
  const data = await response.json();
  return data;
}

test.describe('BrokerAssist 客户管理流程', () => {

  test.beforeAll(async () => {
    // 尝试注册测试账号（忽略错误，账号可能已存在）
    try {
      await registerViaApi(TEST_ACCOUNT, TEST_PASSWORD, TEST_NAME);
    } catch (e) {
      // ignore
    }
  });

  test('创建第一个客户', async ({ page }) => {
    await page.goto(BASE_URL);
    await page.evaluate(
      (url) => localStorage.setItem('brokerassist:web:api-base-url', url),
      API_BASE_URL
    );
    await page.reload();
    await page.waitForTimeout(500);

    // 登录
    await page.locator('#auth-screen').waitFor({ state: 'visible' });
    await page.locator('#login-account').fill(TEST_ACCOUNT);
    await page.locator('#login-password').fill(TEST_PASSWORD);
    await page.locator('#login-submit').click();
    await expect(page.locator('#auth-screen')).toHaveClass(/hidden/, { timeout: 15000 });

    // 创建客户
    await page.locator('#open-create-customer').click();
    await page.locator('#create-customer-dialog').waitFor({ state: 'visible' });
    await page.locator('#create-name').fill('张三');
    await page.locator('#create-phone').fill('13800138001');
    await page.locator('#create-gender').selectOption('男');
    await page.locator('#create-tags').fill('高净值,重疾险');
    await page.locator('#create-customer-form').locator('button[type="submit"]').click();
    await page.locator('#create-customer-dialog').waitFor({ state: 'hidden', timeout: 10000 });
    await expect(page.locator('.customer-list')).toContainText('张三');
  });

  test('创建第二个客户', async ({ page }) => {
    await page.goto(BASE_URL);
    await page.evaluate(
      (url) => localStorage.setItem('brokerassist:web:api-base-url', url),
      API_BASE_URL
    );
    await page.reload();
    await page.waitForTimeout(500);

    // 登录
    await page.locator('#auth-screen').waitFor({ state: 'visible' });
    await page.locator('#login-account').fill(TEST_ACCOUNT);
    await page.locator('#login-password').fill(TEST_PASSWORD);
    await page.locator('#login-submit').click();
    await expect(page.locator('#auth-screen')).toHaveClass(/hidden/, { timeout: 15000 });

    // 创建第二个客户
    await page.locator('#open-create-customer').click();
    await page.locator('#create-customer-dialog').waitFor({ state: 'visible' });
    await page.locator('#create-name').fill('李四');
    await page.locator('#create-phone').fill('13900139002');
    await page.locator('#create-gender').selectOption('女');
    await page.locator('#create-tags').fill('车险,意外险');
    await page.locator('#create-customer-form').locator('button[type="submit"]').click();
    await page.locator('#create-customer-dialog').waitFor({ state: 'hidden', timeout: 10000 });
    await expect(page.locator('.customer-list')).toContainText('李四');
  });

  test('验证两个客户都存在', async ({ page }) => {
    await page.goto(BASE_URL);
    await page.evaluate(
      (url) => localStorage.setItem('brokerassist:web:api-base-url', url),
      API_BASE_URL
    );
    await page.reload();
    await page.waitForTimeout(500);

    // 登录
    await page.locator('#auth-screen').waitFor({ state: 'visible' });
    await page.locator('#login-account').fill(TEST_ACCOUNT);
    await page.locator('#login-password').fill(TEST_PASSWORD);
    await page.locator('#login-submit').click();
    await expect(page.locator('#auth-screen')).toHaveClass(/hidden/, { timeout: 15000 });

    // 验证两个客户都存在
    await expect(page.locator('.customer-list')).toContainText('张三');
    await expect(page.locator('.customer-list')).toContainText('李四');
    const customerItems = await page.locator('.customer-item').count();
    expect(customerItems).toBeGreaterThanOrEqual(2);
  });
});
