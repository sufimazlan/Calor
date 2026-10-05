# Calor — Product Requirements Document

| | |
|---|---|
| **Product** | Calor — personal calorie tracker (iOS native) |
| **Owner** | Sufi |
| **Users** | Sufi and his wife (2 iPhones) |
| **Status** | Draft v0.7 |
| **Last updated** | 5 October 2026 |

---

## 1. Overview

Calor is a simple iPhone app for logging what we eat and tracking daily calories. The main feature is taking a photo of a meal: the app sends the photo to Claude, which identifies the foods and estimates calories, macros and a health score. The user reviews and edits the estimate before saving it. Weigh-ins, a goal progress card and a smart goal check show whether the plan is working.

The app is built for personal use only. It is not published to the App Store.

## 2. Goals

- Log a meal in under 30 seconds by taking a photo.
- See today's total calories against a daily goal at a glance.
- Recognise Malaysian dishes reasonably well (nasi lemak, roti canai, mee goreng, nasi campur, kuih, etc.).
- Keep running costs very low: typical spend around US$1/month for both users, with a **hard cap of US$10/month** that can never be exceeded (see section 9).
- Serve as a learning project for building a native iOS app from scratch.

## 3. Non-goals (v1)

- App Store release, sign-up or user accounts.
- Syncing data between the two phones (each phone keeps its own log). Sharing needs a paid developer account (US$99/year) for iCloud.
- Barcode scanning, restaurant databases or a built-in food database.
- Exercise tracking inside Calor. (Workouts recorded elsewhere can come in from Apple Health, section 6.6d.)
- Bahasa Melayu (English only for now).
- Android or web versions.

These can be revisited after v1 (see section 12).

## 4. Constraints

| Constraint | Detail |
|---|---|
| **Platform** | iPhone only (iOS 27), built with Swift + SwiftUI in Xcode on a Mac |
| **Distribution** | Free Apple ID (Personal Team) signing. The app expires after 7 days and is reinstalled weekly from Xcode (wireless install once paired). |
| **AI provider** | Claude API, using an API key from the Claude Console (pay-as-you-go). A Claude Pro subscription does not cover API usage from an app. |
| **Developer experience** | Beginner in iOS development. Keep the architecture simple and avoid third-party libraries unless needed. |
| **Storage** | All data stored locally on each phone. No backend server. |
| **Budget** | Claude API spend is capped at **US$10/month** for both phones combined, enforced in the Claude Console and by an in-app budget guard (section 9). |

## 5. Users and use cases

**Primary users:** two adults, each using the app on their own iPhone with their own log and goal.

**Key use cases**

1. *Photo log:* "I'm about to eat lunch. I take a photo, the app tells me it's roughly 650 kcal, I adjust the rice portion and save."
2. *Manual log:* "I had a teh tarik earlier and didn't take a photo. I type it in with an estimated calorie number."
3. *Daily check:* "Before dinner, I check how many calories I have left for the day."
4. *History:* "I look back at what I ate this week and my daily totals."

## 6. Features and requirements

Priority: **P0** = must have for v1, **P1** = should have for v1, **P2** = later.

### 6.0 First-launch setup — P0

Styled after Cal AI's onboarding (reference screenshots IMG_0299–0333): white screens, one question each, big bold titles with a grey subtitle, outlined option cards with an icon and a radio button, a round back button with a thin progress line, and a black pill **Continue** that stays grey until an option is picked. Everything is calculated on the phone.

**Flow (first launch):**

1. **Welcome:** Calor logo, phone mockup of the meal scanner, "Calorie tracking made easy", **Get Started**.
2. **Name** (optional).
3. **Sex:** male / female.
4. **Workouts per week:** 0–2 / 3–5 / 6+ (activity multiplier 1.2 / 1.55 / 1.725).
5. **Birthday:** month / day / year wheel.
6. *Info:* "Designed to help you stay on track" (weight trend with Calor vs. without a plan).
7. **Height:** wheel, cm or ft/in.
8. **Weight:** swipeable ruler (0.1 steps), kg or lb.
9. **Goal:** lose / maintain / gain.
10. **Desired weight:** ruler. *(Skipped for maintain, as are 11–12.)*
11. *Info:* "Losing 10 kg starts with a plan!"
12. **Speed:** slider 0.1–1.5 kg a week (gain 0.1–1.0) with Slow / Recommended / Fast, "You should reach your goal in 5 months" and the daily calorie goal. At the safe minimum it shows the real weekly pace.
13. *Info:* "A simpler way to stay on track" (without vs. with Calor).
14. **Diet:** balanced, whole-food, Mediterranean, flexitarian, pescatarian, vegetarian, vegan, low-carb, keto, paleo. Used to tailor protein suggestions in tips.
15. **What's stopping you** (one choice) and 16. **What would you like to accomplish** (one choice). Used for the personal tip on Today (section 6.1).
17. *Info:* "You have great potential to crush your goal".
18. **Rollover:** carry up to 200 unused kcal from yesterday into today? Yes / No.
19. **Meal reminders:** asks for notification permission; daily reminders at 8:00, 12:30 and 19:00 (times editable in Settings).
20. *All done:* "Time to generate your custom plan!"
21. *Building:* animated 0–100% with checkmarks (about 2.5 s).
22. **Your plan:** "Goal: lose 10 kg by 20 December", an estimated progress curve, editable tiles for calories, protein, carbs and fats, and the weight-change projection. **Let's get started!**

Skipped from Cal AI: splash screen, "Other" sex (the calorie formula needs male or female), personal trainer question, Apple Health (connected from Settings instead, section 6.6d), sign-in (no accounts).

Finishing setup (or **Save** after answering again) starts the **plan**: the start date and start weight that progress is measured from (section 6.5d). The plan restarts only when the goal, target weight or pace changes. The weight entered is saved as a weigh-in.

**Calculations:**

- BMR with Mifflin–St Jeor: 10 × kg + 6.25 × cm − 5 × age, +5 for men or −161 for women.
- Maintenance = BMR × workout multiplier.
- Goal = maintenance ∓ pace × 7,700 kcal ÷ 7, never below 1,500 kcal for men or 1,200 kcal for women. Rounded to 10 kcal.
- Goal date = kg to go ÷ real weekly change (from the daily goal vs. maintenance).
- Protein = 1.6 g per kg when losing or gaining, 1.2 g per kg when maintaining. Fat = 30% of calories. Carbs = the rest. Carbs and fat can be set by hand.

The profile (and optional name and photo) is stored only on the phone and never sent to Claude. Older saved profiles still load. **Answer step by step** (from Profile or Settings) replays the questions with current answers filled in, skipping the welcome and info screens.

### 6.1 Today screen (home) — P0

The app is **photo-first**: snapping or uploading a photo is the main way to log a meal. From top to bottom:

- Banners when needed: the install expires within a day, backup isn't working, **Protect your meals** (backup not set up), or the Claude budget is 80% used or used up (section 9.3).
- **Calorie ring:** calories eaten, goal and calories left. The date header shows the **logging streak** ("5-day streak", tap for badges).
  - **Rollover** (if on): up to 200 kcal left over yesterday is added to today's goal, shown as "+150 rolled over".
  - **Workouts** (if Apple Health is connected and turned on): today's workout calories, all or half, are added to the goal, shown as "+240 workouts".
- **Smart goal check** (section 6.5d), only when the weigh-ins show the goal is off.
- **Goal card:** "70.4 kg → 60 kg", a progress bar with % done, "4.2 kg to go · about 20 Dec", "Ahead of plan by 0.5 kg" / "Behind plan by 0.8 kg" / "On track", and a nudge when the last weigh-in is a week old. Tap for the weight chart; **Log weight** opens the weigh-in sheet. When maintaining, it shows the change since the start instead.
- **Macros:** protein, carbs and fat eaten today against targets (protein from the profile, 30% of calories from fat, carbs for the rest).
- **Water** (section 6.5e).
- **What's next:** a short tip worked out on the phone from today's numbers and the time of day, plus a **personal tip** from the setup answers (it changes daily):
  - Lack of consistency: the streak, "log every meal today".
  - Unhealthy eating habits: Malaysian swaps, e.g. "Swap teh tarik for teh-o kosong to save about 100 kcal".
  - Lack of support: share progress with someone close.
  - Busy schedule: snap first, repeat meals from **Same as yesterday**.
  - Lack of meal inspiration: up to three Malaysian meal ideas that fit the calories left and the diet (e.g. no meat or fish for vegetarians, no rice for keto).
  - Aspirations: today's health score, steady energy, motivation, how you feel.
  No API call, so tips are free and work offline.
- Today's entries grouped by meal, with name, portion, health score, a star for favourites and a thumbnail. Tap to edit. Swipe right for **Log again** and **Favourite**; swipe left to delete; long-press for all of them.
- Two main buttons: **Snap meal** (camera) and **Upload** (photo library). In the simulator, which has no camera, only Upload is shown.
- A small **Describe it, repeat a meal, or type it in** link opens the Add Meal screen (section 6.2).

### 6.2 Add Meal screen and manual entry — P0

For when a photo isn't handy, in order:

1. **Describe it in words:** e.g. "2 roti canai with dhal and a teh tarik" → **Estimate calories**. Claude estimates it from the text (no image, so it's about half the cost of a photo) and opens the same review screen as a photo.
2. **Same as yesterday:** yesterday's breakfast, lunch, dinner and snacks, each copied to today with one tap (same meal, no API call).
3. **Favourites:** foods starred anywhere in the app. One tap logs it again now.
4. **Recent:** the last 30 days, one row per food (up to 20). One tap logs it again.
5. **Enter details by hand:** food name (required), calories (required), meal type (auto-selected by time of day), date/time (default now), optional protein / carbs / fat, optional notes. Calories must be a positive number.

Tapped rows show a tick and can be tapped again to add another portion.

### 6.3 Photo entry with Claude — P0

**Flow**

1. User taps **Snap meal**, takes a photo with the camera or picks one from the photo library.
2. **Note before analysing** (on by default, can be turned off in Settings for instant analysis): the photo, an optional note field and quick chips (Half rice, Extra rice, No sugar, Less sweet, Less oil, Shared plate, Small portion, Large portion, Homemade), then **Analyse**. The note goes in the same request (no extra call). Cancelling here sends nothing. One-tap crop to the plate stays P2.
3. The app checks the budget guard (section 9.3). If the monthly or daily limit is reached, it does not call the API and offers **Add manually** instead.
4. The app resizes the image (longest side **768 px**, JPEG quality ~0.6) and shows a loading state.
5. The app sends the image to the Claude API with the analysis prompt (section 8). One photo = one API call.
6. Claude returns structured JSON (enforced by the API's structured outputs, so it always parses): a list of detected food items, each with name, estimated portion, calories, macros and a **health score** from 1 to 10, plus a confidence level.
7. The app records the actual cost of the call from the response's `usage` field (section 9.3).
8. The app shows a **Review screen**:
   - Each item is editable (name, portion, calories, macros) and can be removed.
   - User can add a missing item manually.
   - Total and the meal's **health score** (items weighted by calories, e.g. "6/10 · Good") update live as the user edits. Edits are local and never call the API again.
   - The footer shows which model answered and what it cost, e.g. "Estimated by Claude Haiku 4.5 · cost about US$0.003".
9. User taps **Save**. Each item is saved as its own entry with its health score, the note, and a small thumbnail of the photo.

**Requirements**

- Show a clear message if the photo doesn't look like food, or if confidence is low ("Please check these estimates").
- Handle errors: no internet, invalid API key, out of credit or Console spend limit reached, rate limit, API busy or timeout, a declined request, a cut-off answer. Show a plain message, **Try again** when it can help, and **Add manually**. Never lose the photo on error.
- **Health score:** 10 is nutritious and minimally processed (vegetables, fruit, lean protein, whole grains); 1 is mostly sugar, deep-fried or refined. Shown as a coloured badge (green 7–10, orange 4–6, red 1–3) on entries, the day screen and in Trends. Manual entries have none.

**Compute-saving rules** (P0 unless marked)

These keep each analysis to roughly 1,000 input and 250 output tokens.

| Rule | Why |
|---|---|
| Resize to 768 px on the longest side before sending. | Image tokens ≈ width × height ÷ 750. A 4:3 photo at 768 px costs ~590 tokens, about 45% fewer than at 1024 px (~1,050), and is enough to recognise a plate of food. Keep this a single constant so it can be tuned. |
| Never send the original camera image. | A 12 MP photo would be downscaled by the API anyway (to ~1,600 tokens on Haiku), but it is slow to upload. JPEG quality only affects upload size, not token count. |
| No automatic retries after a successful response. | Every completed call is billed. Calor retries automatically at most once, and only when Claude answers "busy" (529) or a server error, which isn't billed. Everything else waits for the user to tap **Try again**. |
| Use structured outputs (`output_config.format` with a JSON schema). | The response always matches the schema, so there are no "couldn't parse, try again" calls. |
| Keep the output short: compact JSON, short names, one-sentence `notes`. `max_tokens` 1,024 is only a ceiling: just the tokens actually written are billed, and the headroom stops big plates being cut off (a cut-off answer would be paid for and then fail). | Output tokens cost 5× input tokens, so they are the biggest part of the bill. |
| Keep the prompt short and with no examples. | The prompt is sent with every photo. Prompt caching doesn't help here: Haiku 4.5 only caches prompts of 4,096+ tokens and ours is ~300. |
| No extended thinking. Haiku runs without it by default; the Sonnet option turns it off and uses effort `low` (section 8). | Thinking tokens are billed as output. |
| Review-screen edits, re-opening an entry and deleting never call the API. | Only **Snap meal** and **Retry** spend money. |
| **Log again**, **Favourites**, **Recent** and **Same as yesterday** (sections 6.2 and 6.5b). | Repeat meals are logged with no API call at all. |
| **Describe it in words** instead of a photo when the meal is simple. | No image tokens: about half the cost. |
| On-device "is this food?" check with Apple's Vision framework (`VNClassifyImageRequest`) before sending. If it's clearly not food, ask "This doesn't look like food. Send anyway?" — P2 | Free and offline, and it avoids paying for accidental photos. |

### 6.4 Daily goal — P0

- Calculated in setup, editable in Settings and Profile. The smart goal check (6.5d) can suggest a better one.
- Each phone stores its own goal.

### 6.5 Trends tab — P1

Calculated entirely on the phone (free, offline). No Claude call. A **7 days / 30 days** switch at the top changes every section.

- **Daily calories chart** with the goal as a dashed line. Tap a bar for that day's total and item count.
- **Summary:** daily average, days within goal, logging streak, highest day, lowest day, items logged.
- **Estimated weight change** (needs a profile): average intake vs. maintenance, estimated kg change over the logged days, and kg per week and per month at this pace (7,700 kcal ≈ 1 kg).
- **By meal:** average calories and share for breakfast, lunch, dinner and snacks.
- **Macros:** average protein, carbs and fat per day against targets, plus share of calories.
- **Weekdays vs. weekends:** average calories for each.
- **Top foods:** the 5 foods adding the most calories, with how often they were eaten.
- **Weight:** the latest weigh-in and the change over the range, linking to the weight chart (6.5d).
- **Insights:** short sentences picked from the numbers, e.g. "You eat about 300 kcal more on weekends", "Dinner is your biggest meal, 45% of your calories", "At this pace you'd lose about 1.8 kg a month", "Your meals average 6/10 for health".
- A **Badges** button (top right) opens streaks and badges (6.5f).

### 6.5b History tab — P1

- Every day with meals, newest first, grouped by month: "Monday, 5 Oct · 4 items · 1,820 kcal · Within goal" (or "120 over").
- Tap a day: calories, protein, carbs, fat and health score for the day, then the meals.
  - **Copy to today** on each meal (one tap, keeps it as the same meal, no API call).
  - On any entry, swipe right for **Log again** (copies it to today as the meal it's time for) and **Favourite**; swipe left to delete; tap to edit.
- The 7- and 30-day charts are in Trends (6.5).

### 6.5c Demo mode (until the API key is set up)

Until a Claude API key is added, photo and text analysis return realistic sample results (clearly labelled "Demo result", with health scores) so the whole flow can be tried in the simulator without any API cost. Saving a key in Settings switches to real analysis; removing it switches back.

### 6.5d Weight, goal progress and smart goal check — P1

**Weigh-ins**

- **Log weight** (from the goal card or the weight screen): the same swipeable ruler as setup, in kg or lb, with date and time (default now, can be earlier). Tip: weigh at the same time each week, before breakfast.
- The newest weigh-in becomes the profile's current weight, so maintenance calories stay right. The target weight is never changed automatically.
- Optional **weekly weigh-in reminder** (Monday 7:30) in Settings.
- Profiles from v0.6 get their current weight as the first weigh-in and the plan starts on the first launch of v0.7.

**Weight screen:** a chart of weigh-ins (line with dots), the plan as a dashed line from the start weight at the planned pace, and the target as a green line; start, now, target and weekly plan; every weigh-in with its source (logged, profile, Apple Health). Swipe to delete.

**Goal progress** (Today card, 6.1):

- Planned pace = the weekly change the current daily goal gives (maintenance vs. goal ÷ 7,700 kcal per kg), 0 if the goal doesn't move toward the target.
- Planned weight on a date = start weight ∓ planned pace × weeks since the plan started, stopping at the target.
- From the second week: actual vs. planned. ≥ 0.3 kg better is "ahead", ≥ 0.3 kg worse is "behind", otherwise "on track". The first week is skipped because water weight makes it jumpy.
- Projected date = kg to go ÷ planned pace.

**Smart goal check** (Today card, worked out on the phone):

- Looks at the last 21 days. Needs at least 3 weigh-ins at least 14 days apart, and at least 10 days with 800+ kcal logged (lighter days look like missed logging; today is left out).
- Real weekly change = least-squares slope of the weigh-ins. Real maintenance = average intake − slope × 7,700.
- Suggested goal = real maintenance ∓ pace × 7,700 ÷ 7 (maintenance itself when maintaining), never below the safe minimum, rounded to 10 kcal, changed by at most 300 kcal at a time. Shown only if it differs by 100 kcal or more.
- The card explains it in one sentence ("You ate about 1,750 kcal a day and your weight went down 0.2 kg a week, so you burn about 2,000 kcal a day…") and says it assumes everything was logged. **Use 1,450 kcal** applies it and hides the check for 14 days; **Not now** hides it for 7.

### 6.5e Water — P1

- Today card: glasses drunk against the goal (default 8 glasses of 250 ml = 2 L; 4–16 in Settings), drops that fill up, **Add a glass** and −.
- One record per day. Included in backups, the CSV export, the widget and the Hydrated badge.

### 6.5f Streaks and badges — P1

- **Streak:** days in a row with at least one meal. Today doesn't break it until the day is over.
- **Badges**, worked out from the log each time (nothing extra to store): First bite, Snap happy (10 photo meals), On a roll (3-day streak), Week warrior (7), Habit formed (30), Century (100 meals), On target (7 days within goal), Hydrated (water goal on 7 days), Scale starter (first weigh-in), Protein pro (protein target on 5 days, when a target is set), and for lose/gain goals First kilo, Halfway there and Goal reached. Unearned badges show progress, e.g. "4 of 7 days".

### 6.6 Settings — P0

- **Profile:** name, photo, answers, **Redo setup questions**.
- **Targets:** daily calories, protein, carbs and fat (automatic or by hand), water.
- **Rollover**, **meal reminders** (times) and **weekly weigh-in** reminder.
- **Photo analysis (Claude):**
  - **API key:** paste field, checked with a free request (`GET /v1/models`) before it's saved in the iOS Keychain (this device only; never in code, backups or plain storage). Shown masked, e.g. `sk-ant-…a1b2`. **Remove API key** goes back to demo mode.
  - **Model:** Haiku 4.5 (default, cheapest) or Sonnet 5.5 (better on mixed plates, about 2× the cost).
  - **Monthly limit** for this phone: US$0.50–5.00 (default and maximum US$5.00, so both phones together stay within US$10).
  - **Usage:** "US$0.42 of US$5.00", a bar, and "96 analyses this month · 3 of 25 today", from the real token counts Claude returns.
  - **Add a note before analysing** on/off (6.3).
- **Apple Health** (6.6d).
- **Automatic backup** (6.6b) and **Export as CSV** (6.6f).
- **App install** expiry and reinstall reminders (6.6c).

### 6.6b Automatic backup — P0

- One-time setup in Settings, or from the Today card **Protect your meals**: **Choose backup folder** in the Files app, recommended **On My iPhone/Calor Backups**. Calor remembers it with a bookmark.
- Backups are written when the app opens (if none today) and **every time it goes to the background** (at most once a minute), so even a short visit's meals are saved. One JSON file per day, `Calor backup YYYY-MM-DD.json` in local time. The newest **7** daily files are kept. Only exactly-named daily files are ever deleted.
- Contents: every meal (optionally with photo thumbnails, with favourites and health scores), weigh-ins, water, profile (with the plan start), name and photo, targets, water goal, rollover and reminder settings. Backup format version 2; version 1 files still restore (they keep the weigh-ins and water already on the phone).
- **Never writes an empty backup.** Right after a reinstall the phone has no meals, so existing backups are left alone. On a new install's first backup, the previous install's newest file is kept permanently as `… (earlier install <time>).json`.
- **Picking a folder that already has a bigger backup** (after a reinstall, or when switching to a different folder) offers to restore it, **merged with meals logged on the phone since**. A newly picked folder is treated like a fresh start, so its newest existing backup is kept permanently.
- **Restore from a backup…** (Settings, or the setup welcome screen) replaces meals and settings after a confirmation that explains exactly what happens. If the phone has meals, they are first saved as `Calor before restore <time>.json` with photos. If that copy can't be saved, the restore stops and nothing changes. Restored meal reminders ask for notification permission.
- If automatic backups start failing (e.g. the folder was deleted), Today shows **Backup isn't working** with **Fix backup**.
- Each phone backs up to its own storage. Files in On My iPhone survive deleting the app, but not losing the phone.

### 6.6c Reinstall reminders (free Apple ID) — P0

- Calor reads its own expiry date from the provisioning profile Xcode embeds in the app (`embedded.mobileprovision` → `ExpirationDate`; 7 days with a free Apple ID).
- Local notifications **1 day** and **1 hour** before expiry: "Reinstall Calor from Xcode". Rescheduled each time the app opens. Can be turned off in Settings.
- Settings → App install shows the expiry date. In the last 24 hours, Today shows an orange banner.
- If a reinstall doesn't move the expiry date (Xcode reused a still-valid profile), the date in Settings shows it, and the profile has to be refreshed in Xcode.

### 6.6d Apple Health — P1

- Off until **Connect Apple Health** in Settings, which shows iOS's permission sheet. Each phone connects to its own Health data.
- **Add workout calories:** Off (default), Half or All of today's workout calories (Apple Watch, Fitness, Strava…) are added to today's goal. The goal's workout multiplier already allows for usual exercise, so All can count workouts twice; Half is a safe middle.
- **Save weigh-ins to Health:** weights logged in Calor are saved as body mass.
- **Import weight from Health:** weights from other apps and devices (e.g. a smart scale) are added as weigh-ins when Calor opens (the last 30 days the first time). Calor's own weights aren't read back.
- Needs the HealthKit capability, which is in the project (`Config/Calor.entitlements`) and works with a free Apple ID.

### 6.6e Home screen widget — P1

- Small: ring with "650 kcal left" (or "over"), eaten of goal and the streak. Medium: the ring plus calories, protein, water and streak. Lock screen: a ring gauge or a "650 kcal left" line.
- The app shares today's numbers with the widget through an App Group (`group.com.sufimazlan.Calor`) and refreshes it whenever something changes. At midnight the widget starts the new day at zero.
- Lives in the `CalorWidgetExtension` target (`CalorWidget/`).

### 6.6f Export as CSV — P1

- Settings → **Export as CSV** writes two files and opens the share sheet (Files, AirDrop, Mail):
  - `Calor meals <date>.csv`: date, time, meal, food, portion, calories, protein, carbs, fat, health score, source, favourite, notes.
  - `Calor daily totals <date>.csv`: one row per day with calories, macros, number of items, water and weight.
- Dots for decimals whatever the phone's region; UTF-8 with a byte order mark so Excel shows accents and emoji.

### 6.7 Later ideas — P2

- Shared log or sync between the two phones (needs iCloud, so a paid developer account).
- Bahasa Melayu.
- One-tap crop to the plate before analysing.
- On-device "is this food?" check (section 6.3 table).
- Weekly summary written by Claude (decided against for now: on-device trends cover it for free).

## 7. Data model (SwiftData)

**FoodEntry**

| Field | Type | Notes |
|---|---|---|
| id | UUID | |
| timestamp | Date | When eaten |
| mealType | enum | breakfast, lunch, dinner, snack |
| name | String | e.g. "Nasi lemak with fried chicken" |
| portion | String? | e.g. "1 plate", "2 pieces" |
| calories | Int | kcal |
| proteinG | Double? | |
| carbsG | Double? | |
| fatG | Double? | |
| source | enum | manual, photo, text (described in words) |
| confidence | enum? | low, medium, high (analysed entries only) |
| thumbnail | Data? | Small JPEG, stored with external storage enabled |
| notes | String? | The note given before analysing, or typed by hand |
| isFavorite | Bool | Default false. Starred for Favourites |
| healthScore | Int? | 1–10 from the analysis |

**WeightEntry:** id, date, kg (Double), source (manual, profile, health).

**WaterLog:** day (start of day), glasses (Int). One per day.

New fields and models are added by SwiftData's automatic migration; existing meals are kept.

**Settings** (stored with `@AppStorage` / UserDefaults, except the API key)

- profile: the 6.0 answers as JSON, with the plan start date and start weight (missing until first-launch setup is finished)
- dailyGoalKcal: Int (from the profile; default 2000)
- carbsTargetG, fatTargetG: Int (0 = automatic)
- rolloverEnabled: Bool
- remindersEnabled: Bool, plus breakfast / lunch / dinner reminder times
- proteinTargetG: Int (from the profile; 0 = off)
- aiModel: String (default `claude-haiku-4-5`)
- aiMonthlyLimitUSD: Double (default 5.00, 0.50–5.00)
- analysisAsksForNote: Bool (default true)
- aiSpendMonth: String, e.g. "2026-10", and aiSpendMicros: Int (millionths of a dollar spent this month). When the month differs, the counters start again.
- aiCallsMonth: Int
- aiCallsDay: String, e.g. "2026-10-05", and aiCallsToday: Int
- aiFallbacksUnsupported: Bool (the API turned down the Sonnet fallback option once)
- waterGoalGlasses: Int (default 8)
- weighInReminderEnabled: Bool; coachHiddenUntil: seconds since 1970
- healthEnabled: Bool; healthWorkoutShare: 0, 50 or 100; healthWritesWeight, healthReadsWeight: Bool (default true); healthLastWeightImport: seconds since 1970
- The widget's numbers: one dictionary in the App Group's UserDefaults.

**API key:** stored in the Keychain.

## 8. Claude integration

**Endpoint:** `POST https://api.anthropic.com/v1/messages`

**Headers:** `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`

**Models**

| Option | Model string | Use |
|---|---|---|
| Default | `claude-haiku-4-5` | Fast and cheapest (US$1 / US$5 per million input / output tokens) |
| Accurate | `claude-sonnet-5-5` | Better on mixed plates (US$2 / US$10 per million tokens) |

**Request:** a short system prompt and one user message: the image (base64 JPEG, 768 px longest side) with "Estimate this meal." plus the note if any, or for text, "Estimate this meal from my description: …" (note up to 200 characters, description up to 500).

- `max_tokens`: 1,024. A normal reply is ~250–400 tokens; only what's written is billed.
- `output_config.format`: `{"type": "json_schema", "schema": …}` with the schema below. The API then always returns valid JSON matching it (supported on both Haiku 4.5 and Sonnet 5.5).
- Haiku 4.5: no `thinking` or `effort` parameter (thinking stays off).
- Sonnet 5.5: `output_config.effort: "low"` and `thinking: {"type": "between_tools"}`, which keeps thinking off when no tools are used. Without these Sonnet 5.5 thinks by default and bills that as output.
- Sonnet 5.5 also sends `fallbacks: "default"` with the header `anthropic-beta: server-side-fallback-2026-07-01`: if Sonnet declines a request, the API can re-run it on another Claude model in the same call. Both models' tokens are counted in the budget. If the API turns the option down (beta not enabled), Calor sends the request once more without it and remembers not to send it again.
- The response is read by block type (the first `text` block), after checking `stop_reason`: `refusal` and `max_tokens` show an error instead of reading the answer.
- No prompt caching. The prompt is far below Haiku 4.5's 4,096-token caching minimum, so `cache_control` would do nothing.
- Batch API (50% off) is not used: results can take minutes to hours, which doesn't work for "snap and log".

**System prompt**

> You estimate calories and macros for a personal calorie tracker used in Malaysia.
> - List each distinct food or drink. Use common Malaysian names where they fit (nasi lemak, roti canai, teh tarik, kuih).
> - Estimate the portion actually shown or described (e.g. "1 plate", "1 cup", "2 pieces") and the calories, protein, carbs and fat for that portion. Hawker portions are often larger and oilier than Western references: count cooking oil, santan, condensed milk and sugar.
> - Follow any note from the user, such as "half rice" or "no sugar".
> - health_score for each item: 1 to 10. 10 is nutritious and minimally processed (vegetables, fruit, lean protein, whole grains); 1 is mostly sugar, deep-fried or refined with little nutrition.
> - confidence: "high" when the items and portions are clear, "low" when hidden ingredients or portion size are hard to judge.
> - If there is no food or drink, set is_food to false and return no items.
> - notes: one short sentence about what was hardest to judge, or an empty string.

**Schema** (every object closed with `additionalProperties: false`, every field required): `is_food` (boolean), `items` (array of `name`, `portion`, `calories` integer, `protein_g`, `carbs_g`, `fat_g` numbers, `health_score` integer), `confidence` ("low", "medium" or "high"), `notes` (string).

**Expected response (JSON)**

```json
{
  "is_food": true,
  "items": [
    {
      "name": "Nasi lemak (rice with sambal, egg, peanuts, anchovies)",
      "portion": "1 plate",
      "calories": 550,
      "protein_g": 15,
      "carbs_g": 70,
      "fat_g": 22,
      "health_score": 4
    },
    {
      "name": "Fried chicken (drumstick)",
      "portion": "1 piece",
      "calories": 250,
      "protein_g": 20,
      "carbs_g": 8,
      "fat_g": 15,
      "health_score": 3
    }
  ],
  "confidence": "medium",
  "notes": ""
}
```

**Parsing:** decode the first text block with `Codable`, leniently (blank portions and notes become empty, scores are kept within 1–10). With structured outputs it is always valid JSON. Still handle decoding failure by showing **Try again** and **Add manually**, never by retrying automatically.

**Errors:** 401 → check the key; 402, "credit balance" or a spend/usage limit → out of credit or limit reached; 403 → key not allowed; 404 → model not available; 413 → photo too large; 429 → wait a minute; 5xx/529 → busy (one automatic retry); no connection → try again online. Failed requests aren't billed.

**Usage:** every response includes `usage.input_tokens` and `usage.output_tokens`. The app uses these to record the real cost of the call (section 9.3).

**Security note:** the API key lives on the phone. This is acceptable for a personal app used by two people, but the key should never be committed to a git repository or hardcoded. Use a separate key for each phone so one can be revoked without affecting the other. The US$10/month spend limit in the Claude Console (section 9.2) is required, not optional.

## 9. Cost and budget

### 9.1 Cost per photo

Image tokens ≈ width × height ÷ 750. A 4:3 photo resized to 768 × 576 is ~590 tokens. Add ~500 tokens for the prompt and schema, for **~1,100 input tokens**. A compact reply is **~300 output tokens** (a little more than v0.6 for the health scores). A meal described in words has no image tokens.

| Model | Input | Output | Per photo | Per month (2 users × 4 photos/day = 240) |
|---|---|---|---|---|
| Haiku 4.5 (US$1 / US$5 per M) | ~US$0.0011 | ~US$0.0015 | **~US$0.0026** | **~US$0.62** |
| Sonnet 5.5 (US$2 / US$10 per M) | ~US$0.0022 | ~US$0.0030 | ~US$0.0052 | ~US$1.25 |

For comparison, the v0.1 settings (1,024 px, ~400 output tokens) cost ~US$0.0034 per Haiku photo. The rules in 6.3 cut that by about a third.

At US$10/month the cap allows about 3,800 Haiku photos. Normal use will never get close. The cap is there to stop a bug (e.g. a retry loop) or a leaked key from running up a bill.

### 9.2 Hard cap: Claude Console (required, set up in milestone 1)

This is the limit that can never be exceeded, because it is enforced by Anthropic and not by the app.

1. In the Claude Console, create a workspace called **Calor**.
2. Set the workspace's monthly spend limit to **US$10**. If the organisation has no other use, set the organisation limit to US$10 as well.
3. Create two API keys in that workspace: `calor-sufi-iphone` and `calor-wife-iphone`.
4. Turn on billing email alerts if the Console offers them.

Once the limit is reached, the API rejects requests until the next month. The app must show "Monthly AI budget reached — add meals manually until <1st of next month>" and not keep retrying.

### 9.3 In-app budget guard (P0)

The two phones don't sync, so each phone enforces its own share: **US$5.00/month per phone** (2 × US$5 = US$10). The Console limit still backs this up.

- **After every call**, compute the real cost from the `usage` field and the price table for the selected model:\
  `cost = input_tokens × inputPrice + output_tokens × outputPrice`\
  Add it to `monthlySpendUSD` and add 1 to `monthlyAnalysisCount` and `dailyAnalysisCount`. Failed calls with no response cost nothing and are not counted.
- **Before every call**, block the request if spent this month + the worst case for this call > this phone's limit. The worst case is a generous 3,000 input tokens for a photo (1,500 for text) plus `max_tokens` (1,024) of output, twice over if a Sonnet fallback might run: ~US$0.008 a photo on Haiku, ~US$0.016 on Sonnet (~US$0.033 with the fallback).
- If the connection drops after a request may have reached Claude (e.g. a timeout), the worst case is counted, so the limit can't be passed by accident.
- Costs are kept in millionths of a dollar, rounded up.
- **Daily limit:** at most **25 analyses per phone per day**. Normal use is 3–6. This catches runaway loops early.
- **Warning at 80%** of the monthly limit: a banner on the Today screen ("US$4.02 of this month's US$5.00 Claude budget used"). When the next photo wouldn't fit, the banner says photos can't be analysed until the 1st.
- **At 100%:** analysing shows "This month's Claude budget on this phone is used up. It resets on the 1st" with **Add manually**. Favourites, Recent, Same as yesterday and everything else keep working.
- Counters start again at the start of each calendar month (local time).
- Prices live in one constant table in the code next to the model strings, so a price change is a one-line edit.

## 10. Non-functional requirements

- **Speed:** photo analysis result shown within ~10 seconds on a normal mobile connection.
- **Privacy:** photos, notes and descriptions are sent only to the Claude API, and only when the user taps Analyse or Estimate. Only a small thumbnail is stored. The profile, weights and Apple Health data stay on the phone and are never sent to Claude. No analytics or third-party tracking.
- **Offline:** everything except photo and text analysis works offline.
- **Reliability:** reinstalling the app weekly (free signing) must not delete saved data. Do not delete the app from the phone, only re-run it from Xcode.
- **Accessibility:** support Dynamic Type and Dark Mode (comes mostly free with SwiftUI).

## 11. Milestones

| Phase | Scope | Done when |
|---|---|---|
| 1. Setup | Xcode, Personal Team signing, blank app on both phones, Console workspace with US$10/month limit and one key per phone | "Hello world" opens on both iPhones; spend limit is set |
| 2. Manual logging | Data model, Today screen, manual entry, edit/delete, daily goal | Can log a meal by hand and see today's total |
| 3. Photo + Claude | Camera/photo picker, 768 px resize, API call with structured outputs, review screen, Keychain key, errors, budget guard and usage tracking | Can snap a meal and save Claude's estimate; Settings shows the real cost of each photo |
| 4. Polish | History, Log again, 7-day chart, model choice, text hint | Comfortable to use daily for a week |
| 5. Rollout | Install on wife's iPhone, wireless install set up | Both of us using it daily |
| 6. v0.7 | Weigh-ins, goal card, smart goal check, describe in words, Add Meal screen (favourites, recent, yesterday), health score, water, streaks and badges, tailored tips, CSV export, Apple Health, widget | All 17 features from the v0.7 list working on both phones |

## 12. Success criteria

- Both users log at least 2 meals a day for 2 consecutive weeks.
- Most photo estimates need only small edits (judged by feel; no formal accuracy target for v1).
- Monthly API cost is around US$1 in normal use and never goes above US$10.
- Average input under ~1,100 tokens and output under ~300 tokens per photo (checked from the usage counter in the first week).

## 13. Open questions

1. ~~What daily calorie goal should each of us start with?~~ Worked out in setup; the smart goal check fine-tunes it.
2. ~~Macros or just calories?~~ Both: calories, protein, carbs, fat and a health score.
3. ~~Several items: separate entries or one?~~ Separate entries, grouped by meal.
4. ~~English or also Bahasa Melayu?~~ English for now (6.7).
5. Is syncing between the two phones wanted later? Needs a paid developer account (6.7).
6. Should Sonnet 5.5 be the default model? Haiku 4.5 stays the default until real photos show whether Sonnet's accuracy is worth twice the cost.
