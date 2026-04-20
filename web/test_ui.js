const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  const BASE = 'http://localhost:4173';
  const errors = [];

  page.on('console', msg => {
    if (msg.type() === 'error') errors.push(msg.text());
  });
  page.on('pageerror', err => errors.push(err.message));

  try {
    console.log('=== Test 1: Load Page ===');
    await page.goto(BASE, { waitUntil: 'networkidle', timeout: 15000 });
    console.log(`Title: ${await page.title()}`);

    // Login inputs are at indices 2 (account) and 3 (password) based on previous test
    const accountInput = page.locator('input').nth(2);
    const passInput = page.locator('input').nth(3);
    const loginBtn = page.locator('button').nth(28); // visible "登录" button

    console.log('\n=== Test 2: Login ===');
    console.log(`Account input visible: ${await accountInput.isVisible()}`);
    console.log(`Password input visible: ${await passInput.isVisible()}`);
    console.log(`Login button visible: ${await loginBtn.isVisible()}`);

    if (await accountInput.isVisible() && await passInput.isVisible()) {
      await accountInput.fill('test@brokerassist.local');
      await passInput.fill('Test123456');
      await loginBtn.click();
      await page.waitForTimeout(3000);
      console.log(`URL after login: ${page.url()}`);
    }

    console.log('\n=== Test 3: After Login - Check Customer List ===');
    const bodyText = await page.locator('body').innerText();
    console.log(`Body text preview: ${bodyText.substring(0, 300)}`);

    console.log('\n=== Test 4: Customer List ===');
    const customerNames = await page.locator('[class*="name"], .customer-name, [class*="item"] [class*="name"]').allTextContents();
    console.log(`Found ${customerNames.length} customer items`);
    if (customerNames.length > 0) {
      console.log(`First few: ${customerNames.slice(0, 5).join(', ')}`);
    }

    console.log('\n=== Test 5: Select First Customer ===');
    // Click on first customer item
    const firstCustomer = page.locator('[class*="item"], [class*="customer"], [class*="list"] > *').first();
    if (await firstCustomer.count() > 0 && await firstCustomer.isVisible()) {
      await firstCustomer.click();
      await page.waitForTimeout(2000);
      console.log(`URL after selection: ${page.url()}`);

      // Check if detail panel appears
      const detailPanel = await page.locator('[class*="detail"], [class*="summary"], [class*="profile"]').count();
      console.log(`Detail panel elements found: ${detailPanel}`);
    }

    console.log('\n=== Test 6: Quick Actions ===');
    // Click "客户画像" button if visible
    const profileBtn = page.locator('button:has-text("客户画像")');
    if (await profileBtn.isVisible()) {
      await profileBtn.click();
      await page.waitForTimeout(5000);
      console.log('Clicked 客户画像');
      const newBodyText = await page.locator('body').innerText();
      console.log(`Response preview: ${newBodyText.substring(0, 200)}`);
    }

    console.log('\n=== Test 7: AI Q&A Buttons ===');
    // Click on one of the example question buttons (visible ones at indices 19-23)
    const exampleBtns = await page.locator('button:has-text("请列出"), button:has-text("哪些客户"), button:has-text("请推荐"), button:has-text("海淀区")').all();
    console.log(`Found ${exampleBtns.length} example question buttons`);
    if (exampleBtns.length > 0 && await exampleBtns[0].isVisible()) {
      await exampleBtns[0].click();
      await page.waitForTimeout(8000);
      const newBodyText = await page.locator('body').innerText();
      console.log(`AI response preview: ${newBodyText.substring(0, 300)}`);
    }

    console.log('\n=== Test 8: Console Errors ===');
    if (errors.length > 0) {
      console.log(`Errors (${errors.length}):`);
      errors.forEach((e, i) => console.log(`  ${i+1}. ${e}`));
    } else {
      console.log('No console errors!');
    }

  } catch (err) {
    console.error('Test error:', err.message);
  } finally {
    await browser.close();
  }

  console.log('\n=== Test Complete ===');
})();
