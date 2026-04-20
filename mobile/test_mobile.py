"""
BrokerAssist Mobile App Automated Test

Tests:
1. Login with test account
2. Verify customer list contains created customers
"""

import time
from appium import webdriver
from appium.options.android import UiAutomator2Options
from appium.webdriver.common.appiumby import AppiumBy

# Test credentials
TEST_ACCOUNT = "test_brokerassist@example.com"
TEST_PASSWORD = "password123"
EXPECTED_CUSTOMERS = ["张三", "李四"]

# App capabilities
CAPABILITIES = {
    "platformName": "Android",
    "deviceName": "emulator-5554",
    "appPackage": "com.brokerassist.broker_assist",
    "appActivity": ".MainActivity",
    "automationName": "UiAutomator2",
    "noReset": False,
}


def main():
    print("Starting BrokerAssist Mobile App Test...")

    # Initialize driver
    options = UiAutomator2Options().load_capabilities(CAPABILITIES)
    driver = webdriver.Remote("http://127.0.0.1:4723", options=options)

    try:
        # Wait for app to load
        print("Waiting for app to load...")
        time.sleep(5)

        # Check if on login page - look for edit texts
        print("Looking for login form...")

        # Find account field using UiAutomator
        account_field = driver.find_element(
            AppiumBy.ANDROID_UIAUTOMATOR,
            'new UiSelector().className("android.widget.EditText").instance(0)'
        )
        account_field.clear()
        account_field.send_keys(TEST_ACCOUNT)
        print(f"Entered account: {TEST_ACCOUNT}")

        # Find password field
        password_field = driver.find_element(
            AppiumBy.ANDROID_UIAUTOMATOR,
            'new UiSelector().className("android.widget.EditText").instance(1)'
        )
        password_field.clear()
        password_field.send_keys(TEST_PASSWORD)
        print("Entered password")

        # Find and click login button
        login_button = driver.find_element(
            AppiumBy.ANDROID_UIAUTOMATOR,
            'new UiSelector().text("登录").className("android.widget.Button")'
        )
        login_button.click()
        print("Clicked login button")

        # Wait for login to complete
        time.sleep(5)

        # Check if logged in - look for customer list or navigation
        print("Checking if login successful...")

        # Look for bottom navigation (indicates successful login)
        try:
            nav = driver.find_element(
                AppiumBy.ANDROID_UIAUTOMATOR,
                'new UiSelector().className("android.widget.NavigationBar")'
            )
            print("✓ Navigation bar found - likely logged in")
        except:
            print("Navigation bar not found directly, continuing...")

        # Take screenshot
        driver.save_screenshot("/tmp/mobile_after_login.png")
        print("Screenshot saved to /tmp/mobile_after_login.png")

        # Now check for customers - navigate to customer list
        print("Looking for customer list...")

        # Find customer tab/button
        try:
            customers_tab = driver.find_element(
                AppiumBy.ANDROID_UIAUTOMATOR,
                'new UiSelector().text("客户").className("android.widget.TextView")'
            )
            customers_tab.click()
            print("Clicked 客户 tab")
            time.sleep(3)
        except Exception as e:
            print(f"Could not find 客户 tab: {e}")

        # Take screenshot of customer list
        driver.save_screenshot("/tmp/mobile_customer_list.png")
        print("Customer list screenshot saved")

        # Check for expected customers
        page_source = driver.page_source
        found_customers = []

        for customer in EXPECTED_CUSTOMERS:
            if customer in page_source:
                found_customers.append(customer)
                print(f"✓ Found customer: {customer}")
            else:
                print(f"✗ Customer not found: {customer}")

        # Final results
        print("\n" + "="*50)
        if len(found_customers) == len(EXPECTED_CUSTOMERS):
            print(f"✓ SUCCESS: All {len(EXPECTED_CUSTOMERS)} customers found!")
            print(f"  Found: {', '.join(found_customers)}")
        else:
            print(f"⚠ PARTIAL: Found {len(found_customers)}/{len(EXPECTED_CUSTOMERS)} customers")
            print(f"  Found: {', '.join(found_customers)}")
            print(f"  Missing: {', '.join([c for c in EXPECTED_CUSTOMERS if c not in found_customers])}")
        print("="*50)

    except Exception as e:
        print(f"Error: {e}")
        driver.save_screenshot("/tmp/mobile_error.png")
        print("Error screenshot saved to /tmp/mobile_error.png")

    finally:
        driver.quit()
        print("\nTest completed. Driver closed.")


if __name__ == "__main__":
    main()
