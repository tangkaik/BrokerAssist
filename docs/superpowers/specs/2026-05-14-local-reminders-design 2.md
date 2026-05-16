# Local Reminder Notifications Design

## Goal

Build the first version of CRM reminder notifications as local phone notifications. The feature should help sales users notice time-sensitive customer work without overwhelming them with one notification per customer.

## Product Scope

The first version uses local notifications scheduled by the mobile app. It does not require a server-side push provider, device tokens, APNs, or FCM.

The app will support predefined reminder rules by industry. Users will not configure custom reminder rules in this version.

The reminder experience has three surfaces:

1. Home page "今日提醒" card.
2. "今日提醒" detail page.
3. Customer list reminder badges as a secondary browsing aid.

## Reminder Rules

All local notifications are scheduled for 09:00 in the user's device timezone.

Insurance users:

- Birthday care: remind 3 days before a customer's birthday.
- Festival gift preparation: remind 7 days, 3 days, and 1 day before predefined festivals.
- Policy payment follow-up: remind 3 days before a clearly detected payment due date.

Generic CRM users:

- Birthday care: remind 3 days before a customer's birthday.
- Festival care: remind 7 days, 3 days, and 1 day before predefined festivals.
- Long-no-contact follow-up can be added after this version if the data quality is ready.

Real estate users:

- Birthday care: remind 3 days before a customer's birthday.
- Festival care: remind 7 days, 3 days, and 1 day before predefined festivals.
- Viewing or revisit reminders can be added later when explicit appointment fields exist.

## Policy Payment Detection

The first version does not add a full policy module.

Policy payment dates are detected only from existing customer information:

- Customer summary.
- Customer advice text if available.
- Communication records.
- Image recognition results if they are already included in record data.

The detector must be conservative. It should only create a payment reminder when the text contains an explicit due date or payment date. If the user did not enter a payment date, no policy payment reminder is created.

Examples that can create reminders:

- "保单缴费日是 2026-06-01"
- "6月1日前续费"
- "下次保费 2026/06/01 到期"

Examples that must not create reminders:

- "客户担心缴费压力"
- "之前买过一份寿险"
- "年缴保费 2 万"

## Notification Merging

The app must not schedule one notification per customer. Reminders are grouped by date and reminder type.

At most one local notification per reminder type should fire at 09:00 for a given day:

- "今天有 3 位客户生日即将到来"
- "今天有 10 位客户保单缴费需跟进"
- "端午节还有 7 天，建议准备重点客户礼品"

Tapping a notification opens the app to the "今日提醒" detail page. If the notification belongs to a specific type, the detail page should focus that reminder group when practical.

## Home Page Design

Add a compact "今日提醒" card to the home page.

The card shows up to three reminder preview rows. Rows should support Markdown-style emphasis in the source text so later reminder text can use bold labels without introducing a new rendering path.

Example rows:

- "**生日关怀** · 3 位客户生日还有 3 天"
- "**保单缴费** · 10 位客户需在 3 天内跟进"
- "**节日礼品** · 端午节还有 7 天"

The card includes a clear "查看全部" affordance. Tapping the card opens the "今日提醒" detail page.

If there are no reminders today, the card should show a quiet empty state rather than disappearing. This keeps the home layout stable and reminds the user that reminders are available.

## Reminder Detail Page

Create a "今日提醒" detail page. This page is the main workflow for processing reminders.

The page groups reminders by type:

- 生日关怀
- 保单缴费
- 节日礼品
- Other predefined industry reminder groups added later

Each customer reminder row shows:

- Customer avatar or initials.
- Customer name.
- Reminder reason.
- Due label such as "还有 3 天" or "今天处理".
- "查看客户" action.
- Explicit completion action.

Clicking "查看客户" opens that customer's detail page. Returning from the customer detail page should return to the reminder detail page, preserving the user's place in the list.

Opening a reminder does not mark it complete. A reminder is dismissed for the day only after the user taps the explicit completion action.

Completed reminders are hidden from the main active list or shown in a subdued completed state. The first version can use a simple local completion store keyed by user, date, reminder type, and target id.

Festival reminders are not tied to one customer. Their row can show the festival name, lead time, and a general "完成" action.

## Customer List Badges

The customer list should show small reminder badges next to customers who have active reminders today.

Examples:

- "生日"
- "缴费"
- "节日"

Badges are auxiliary indicators for browsing. They do not replace the reminder detail page and should not mark reminders complete when tapped. If tapped, they can open the reminder detail page or customer detail page, but completion remains explicit.

## Local Notification Scheduling

On app launch and after relevant data changes, the app refreshes the local reminder schedule.

Relevant data changes include:

- Customer created or edited.
- Customer birthday changed.
- Record created, edited, deleted, or image analysis updated.
- Industry setting changed.
- User login/logout.

The scheduler computes reminder occurrences for a rolling future window. The first version should use a small practical window, such as the next 30 days, to avoid platform scheduling limits.

The scheduler cancels previously scheduled reminder notifications for the current user before scheduling the newly computed set. Completion state should prevent completed reminders for the same day from reappearing in the home card, detail page, or badges.

## Data Model

The first version can keep reminder occurrences computed locally from existing API data. It should introduce local app models for:

- Reminder type.
- Reminder occurrence date.
- Target customer id when applicable.
- Title and body.
- Group title.
- Completion state.
- Source metadata for debugging, such as "birthday", "festival", or "payment_date_detected".

The app should keep these models separate from UI widgets so later server-side push can reuse the rule concepts.

## Error Handling

If notification permission is denied, the home card and reminder detail page should still work inside the app. The app can show a quiet permission prompt or account-page entry later, but it should not block the reminder list.

If local notification scheduling fails, the app should not crash. It should log or surface a lightweight message and keep in-app reminders available.

If payment date detection is uncertain, skip the reminder. Missing a payment reminder is better than sending a false reminder in the first version.

## Testing

Unit tests should cover:

- Birthday reminder date calculation across month and year boundaries.
- Festival lead-day reminder generation.
- Conservative policy payment date detection.
- Merging reminders by date and type.
- Completion state hiding reminders for the current day.
- Industry-specific rule selection.

Widget tests should cover:

- Home reminder card renders up to three preview rows.
- Reminder detail page shows grouped active reminders.
- Completed reminders leave the active list.
- Customer list badges render for customers with active reminders.

Manual verification should cover:

- Notification permission request.
- A scheduled local notification appears when the app is not open.
- Tapping a notification opens the reminder detail page.
- Customer detail navigation returns to the reminder detail page.

## Future Server Push Path

The first version intentionally uses local notifications. Later, server push can be added by moving rule computation or delivery to the backend.

To keep that path open, local reminder types and source metadata should use stable keys. A future backend can generate the same occurrence shape and deliver it through APNs/FCM while the app keeps the same home card, detail page, and customer list badge UI.
