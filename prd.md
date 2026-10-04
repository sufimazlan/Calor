# Calor — Product Requirements Document

| | |
|---|---|
| **Product** | Calor — personal calorie tracker (iOS native) |
| **Owner** | Sufi |
| **Users** | Sufi and his wife (2 iPhones) |
| **Status** | Draft v0.4 |
| **Last updated** | 4 October 2026 |

---

## 1. Overview

Calor is a simple iPhone app for logging what we eat and tracking daily calories. The main feature is taking a photo of a meal: the app sends the photo to Claude, which identifies the foods and estimates calories and macros. The user reviews and edits the estimate before saving it.

The app is built for personal use only. It is not published to the App Store.

## 2. Goals

- Log a meal in under 30 seconds by taking a photo.
- See today's total calories against a daily goal at a glance.
- Recognise Malaysian dishes reasonably well (nasi lemak, roti canai, mee goreng, nasi campur, kuih, etc.).
- Keep running costs very low: typical spend around US$1/month for both users, with a **hard cap of US$10/month** that can never be exceeded (see section 9).
- Serve as a learning project for building a native iOS app from scratch.

## 3. Non-goals (v1)

- App Store release, sign-up or user accounts.
- Syncing data between the two phones (each phone keeps its own log).
- Barcode scanning, restaurant databases or a built-in food database.
- Exercise tracking, Apple Health integration or weight history. (The profile stores current weight only, to calculate targets.)
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

### 6.0 First-launch profile — P0

On first launch, about 30 seconds of questions work out personal targets instead of a flat 2,000 kcal:

1. Name (optional), sex, birth year, height, weight.
2. Activity level: mostly sitting / lightly active / active / very active.
3. Goal: lose, maintain or gain weight, with pace (lose 0.25 / 0.5 / 0.75 / 1 kg a week; gain 0.25 / 0.5).
4. Result screen: suggested daily goal (adjustable in 50 kcal steps) and protein target, with the breakdown, plus a live projection for the chosen goal: daily deficit or surplus, "lose 1 kg every N days", and kg per week, per month and in 3 months. A warning shows below the safe minimum or faster than 1 kg a week. The same projection appears under the goal in Settings.

**Calculations (on the phone):**

- BMR with Mifflin–St Jeor: 10 × kg + 6.25 × cm − 5 × age, +5 for men or −161 for women.
- Maintenance = BMR × activity multiplier (1.2 / 1.375 / 1.55 / 1.725).
- Goal = maintenance ∓ pace × 7,700 kcal ÷ 7 (0.5 kg a week ≈ 550 kcal a day), never below 1,500 kcal for men or 1,200 kcal for women. Rounded to 10 kcal.
- Protein target = 1.6 g per kg when losing or gaining, 1.2 g per kg when maintaining.

The profile is stored only on the phone and is never sent to Claude. It also holds an optional **name and profile photo** (resized to 300 px), shown as an avatar button at the top right of Today. Tapping the avatar opens the profile form, which can also replay the step-by-step questions; Settings has the same options. Saving recalculates both targets. The daily goal and protein target can also be fine-tuned by hand.

### 6.1 Today screen (home) — P0

The app is **photo-first**: snapping or uploading a photo is the main way to log a meal.

- Shows today's date, total calories eaten, daily goal and calories remaining (a progress ring), plus protein eaten against the protein target.
- **What's next** card: a short tip worked out on the phone from today's numbers and the time of day (e.g. "800 kcal left for dinner and anything after", "You're 200 kcal over, keep the rest of today light", or a nudge when protein is low). No API call, so it's free and works offline.
- Lists today's entries grouped by meal (Breakfast, Lunch, Dinner, Snack), showing name, calories and a thumbnail if there is a photo.
- Two main buttons: **Snap meal** (camera) and **Upload** (photo library). In the simulator, which has no camera, only Upload is shown.
- A small **Add manually instead** link, kept as a fallback for when a photo isn't possible (no internet, analysis failed, monthly budget reached).
- Swipe to delete an entry; tap an entry to edit it.

### 6.2 Manual entry — P0

- Fields: food name (required), calories (required), meal type (auto-selected by time of day, editable), date/time (default now), optional protein / carbs / fat in grams, optional notes.
- Validation: calories must be a positive number.

### 6.3 Photo entry with Claude — P0

**Flow**

1. User taps **Snap meal**, takes a photo with the camera or picks one from the photo library.
2. The user can optionally crop to just the plate (one-tap square crop, P1). Less background means fewer image tokens and a better estimate.
3. The app checks the budget guard (section 9.3). If the monthly or daily limit is reached, it does not call the API and offers **Add manually** or **Log again** instead.
4. The app resizes the image (longest side **768 px**, JPEG quality ~0.6) and shows a loading state.
5. The app sends the image to the Claude API with the analysis prompt (section 8). One photo = one API call.
6. Claude returns structured JSON (enforced by the API's structured outputs, so it always parses): a list of detected food items, each with name, estimated portion, calories and macros, plus a confidence level.
7. The app records the actual cost of the call from the response's `usage` field (section 9.3).
8. The app shows a **Review screen**:
   - Each item is editable (name, portion, calories, macros) and can be removed.
   - User can add a missing item manually.
   - Total updates live as the user edits. Edits are local and never call the API again.
9. User taps **Save**. Each item is saved as an entry (or one combined entry — see open question 3), with a small thumbnail of the photo.

**Requirements**

- Show a clear message if the photo doesn't look like food, or if confidence is low ("Please check these estimates").
- Handle errors: no internet, invalid API key, API overloaded or timeout, Console spend limit reached. Show a friendly message with a **Retry** option and an option to switch to manual entry. Never lose the photo on error.
- The user can add an optional text hint before sending (e.g. "half portion of rice", "no sugar"), which is included in the same request (no extra call). — P1

**Compute-saving rules** (P0 unless marked)

These keep each analysis to roughly 1,000 input and 250 output tokens.

| Rule | Why |
|---|---|
| Resize to 768 px on the longest side before sending. | Image tokens ≈ width × height ÷ 750. A 4:3 photo at 768 px costs ~590 tokens, about 45% fewer than at 1024 px (~1,050), and is enough to recognise a plate of food. Keep this a single constant so it can be tuned. |
| Never send the original camera image. | A 12 MP photo would be downscaled by the API anyway (to ~1,600 tokens on Haiku), but it is slow to upload. JPEG quality only affects upload size, not token count. |
| No automatic retries after a response has been received. | Every completed call is billed. Retry automatically at most once, and only for network failures or "overloaded" errors where no response came back. Everything else waits for the user to tap **Retry**. |
| Use structured outputs (`output_config.format` with a JSON schema). | The response always matches the schema, so there are no "couldn't parse, try again" calls. |
| Keep the output short: compact JSON, whole numbers, `notes` only when confidence is low, `max_tokens` 600. | Output tokens cost 5× input tokens, so they are the biggest part of the bill. |
| Keep the prompt short and with no examples. | The prompt is sent with every photo. Prompt caching doesn't help here: Haiku 4.5 only caches prompts of 4,096+ tokens and ours is ~300. |
| No extended thinking. Haiku runs without it by default; the Sonnet option turns it off and uses effort `low` (section 8). | Thinking tokens are billed as output. |
| Review-screen edits, re-opening an entry and deleting never call the API. | Only **Snap meal** and **Retry** spend money. |
| **Log again** for repeat meals (moved up from P2 to P1, see 6.5). | The usual breakfast is logged from history with no API call at all. |
| On-device "is this food?" check with Apple's Vision framework (`VNClassifyImageRequest`) before sending. If it's clearly not food, ask "This doesn't look like food. Send anyway?" — P2 | Free and offline, and it avoids paying for accidental photos. |

### 6.4 Daily goal — P0

- User sets a daily calorie goal in Settings (default 2,000 kcal).
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
- **Insights:** short sentences picked from the numbers, e.g. "You eat about 300 kcal more on weekends", "Dinner is your biggest meal, 45% of your calories", "At this pace you'd lose about 1.8 kg a month".

The Today screen also shows a **Macros** card: protein, carbs and fat eaten today against targets (protein from the profile, 30% of calories from fat, carbs for the rest).

### 6.5b History — P1

- **Log again:** on any past entry, tap **Log again** to copy it into today (name, portion, calories, macros) with no API call. — P1

- A list of past days showing the daily total vs goal.
- Tap a day to see its entries (same layout as the Today screen).
- A simple 7-day bar chart of daily calories (Swift Charts). — P1

### 6.5c Demo mode (until the API key is set up)

Until a Claude API key is added, photo analysis returns realistic sample results (clearly labelled "Demo result") so the whole snap → review → save flow can be built and tested in the simulator without any API cost. Real analysis replaces it in milestone 3.

### 6.6 Settings — P0

- **Claude API key:** paste field, stored in the iOS Keychain (never in code, never in plain storage). Show only the last 4 characters once saved. Includes a **Test key** button.
- **Model choice:** Haiku 4.5 (default, cheapest) or Sonnet 5.5 (more accurate, about 2× the cost per photo). — P1
- **Daily calorie goal.**
- **Budget and usage (P0):** "US$0.42 of US$5.00 used this month · 96 photos", based on the real token counts Claude returns. Editable monthly budget for this phone (default US$5.00, maximum US$5.00 so both phones together stay within US$10). Shows when the counter resets.

### 6.7 Later ideas — P2

- Favourites for repeat meals. (**Log again** from history moves to P1, because it saves API calls.)
- Shared log or sync between the two phones (CloudKit).
- Apple Health integration.
- Home screen widget showing calories remaining.
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
| source | enum | manual, photo |
| confidence | enum? | low, medium, high (photo entries only) |
| thumbnail | Data? | Small JPEG, stored with external storage enabled |
| notes | String? | |

**Settings** (stored with `@AppStorage` / UserDefaults, except the API key)

- profile: the 6.0 answers as JSON (missing until first-launch setup is finished)
- dailyGoalKcal: Int (from the profile; default 2000)
- proteinTargetG: Int (from the profile; 0 = off)
- selectedModel: String (default `claude-haiku-4-5-20251001`)
- monthlyBudgetUSD: Double (default 5.00, max 5.00)
- usageMonth: String, e.g. "2026-10". When the current month differs, reset the monthly counters.
- monthlySpendUSD: Double (sum of actual call costs this month)
- monthlyAnalysisCount: Int
- usageDay: String, e.g. "2026-10-04". When the current day differs, reset the daily counter.
- dailyAnalysisCount: Int

**API key:** stored in the Keychain.

## 8. Claude integration

**Endpoint:** `POST https://api.anthropic.com/v1/messages`

**Headers:** `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`

**Models**

| Option | Model string | Use |
|---|---|---|
| Default | `claude-haiku-4-5-20251001` | Fast and cheapest (US$1 / US$5 per million input / output tokens) |
| Accurate | `claude-sonnet-5-5` | Better on mixed plates (US$2 / US$10 per million tokens) |

**Request:** one user message containing the image (base64 JPEG, 768 px longest side) and a short text instruction.

- `max_tokens`: 600. A normal reply is ~250 tokens; this only stops a runaway reply.
- `output_config.format`: `{"type": "json_schema", "schema": …}` with the schema below. The API then always returns valid JSON matching it (supported on both Haiku 4.5 and Sonnet 5.5).
- Haiku 4.5: send no `thinking` parameter (thinking stays off).
- Sonnet 5.5: `output_config.effort: "low"` and `thinking: {"type": "between_tools"}`, which keeps thinking off when no tools are used. Without these Sonnet 5.5 thinks by default and bills that as output.
- No prompt caching. The prompt is far below Haiku 4.5's 4,096-token caching minimum, so `cache_control` would do nothing.
- Batch API (50% off) is not used: results can take minutes to hours, which doesn't work for "snap and log".

**Prompt (draft)**

> You are a nutrition assistant for users in Malaysia. Identify each food and drink item in this photo and estimate its portion size and nutrition. Be familiar with Malaysian dishes (Malay, Chinese, Indian and mamak food) and use local names where appropriate. If the photo does not show food, set `is_food` to false and return no items. Use whole numbers. Keep names short. Only fill `notes` when confidence is low.
> User note (optional): {hint}

The schema is passed through `output_config.format`, so it doesn't need to be repeated in the prompt text.

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
      "fat_g": 22
    },
    {
      "name": "Fried chicken (drumstick)",
      "portion": "1 piece",
      "calories": 250,
      "protein_g": 20,
      "carbs_g": 8,
      "fat_g": 15
    }
  ],
  "total_calories": 800,
  "confidence": "medium",
  "notes": ""
}
```

**Parsing:** decode the first text block with `Codable`. With structured outputs it is always valid JSON. Still handle decoding failure (e.g. a reply cut off at `max_tokens`) by showing **Retry** and **Add manually**, never by retrying automatically.

**Usage:** every response includes `usage.input_tokens` and `usage.output_tokens`. The app uses these to record the real cost of the call (section 9.3).

**Security note:** the API key lives on the phone. This is acceptable for a personal app used by two people, but the key should never be committed to a git repository or hardcoded. Use a separate key for each phone so one can be revoked without affecting the other. The US$10/month spend limit in the Claude Console (section 9.2) is required, not optional.

## 9. Cost and budget

### 9.1 Cost per photo

Image tokens ≈ width × height ÷ 750. A 4:3 photo resized to 768 × 576 is ~590 tokens. Add ~350 tokens for the prompt and schema, for **~950 input tokens**. A compact reply is **~250 output tokens**.

| Model | Input | Output | Per photo | Per month (2 users × 4 photos/day = 240) |
|---|---|---|---|---|
| Haiku 4.5 (US$1 / US$5 per M) | ~US$0.0010 | ~US$0.0013 | **~US$0.0022** | **~US$0.55** |
| Sonnet 5.5 (US$2 / US$10 per M) | ~US$0.0019 | ~US$0.0025 | ~US$0.0044 | ~US$1.05 |

For comparison, the v0.1 settings (1,024 px, ~400 output tokens) cost ~US$0.0034 per Haiku photo. The rules in 6.3 cut that by about a third.

At US$10/month the cap allows about 4,500 Haiku photos. Normal use will never get close. The cap is there to stop a bug (e.g. a retry loop) or a leaked key from running up a bill.

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
- **Before every call**, block the request if `monthlySpendUSD + worst case for this call > monthlyBudgetUSD`. The worst case is ~1,000 input tokens plus `max_tokens` (600) of output: ~US$0.004 on Haiku, ~US$0.008 on Sonnet.
- **Daily limit:** at most **25 analyses per phone per day**. Normal use is 3–6. This catches runaway loops early.
- **Warning at 80%** of the monthly budget: a banner on the Today screen ("US$4.02 of US$5.00 AI budget used").
- **At 100%:** **Snap meal** says "Monthly AI budget reached" and offers **Add manually** and **Log again**. Manual entry, history and everything else keep working.
- Counters reset automatically at the start of each calendar month (local time), using `usageMonth` / `usageDay`.
- Prices live in one constant table in the code next to the model strings, so a price change is a one-line edit.

## 10. Non-functional requirements

- **Speed:** photo analysis result shown within ~10 seconds on a normal mobile connection.
- **Privacy:** photos are sent only to the Claude API. Only a small thumbnail is stored. No analytics or third-party tracking.
- **Offline:** Today, history and manual entry work fully offline; only photo analysis needs internet.
- **Reliability:** reinstalling the app weekly (free signing) must not delete saved data. Do not delete the app from the phone, only re-run it from Xcode.
- **Accessibility:** support Dynamic Type and Dark Mode (comes mostly free with SwiftUI).

## 11. Milestones

| Phase | Scope | Done when |
|---|---|---|
| 1. Setup | Xcode, Personal Team signing, blank app on both phones, Console workspace with US$10/month limit and one key per phone | "Hello world" opens on both iPhones; spend limit is set |
| 2. Manual logging | Data model, Today screen, manual entry, edit/delete, daily goal | Can log a meal by hand and see today's total |
| 3. Photo + Claude | Camera/photo picker, 768 px resize, API call with structured outputs, review screen, Keychain key, errors, budget guard and usage tracking | Can snap a meal and save Claude's estimate; Settings shows the real cost of each photo |
| 4. Polish | History, Log again, 7-day chart, model choice, crop, text hint | Comfortable to use daily for a week |
| 5. Rollout | Install on wife's iPhone, wireless install set up | Both of us using it daily |

## 12. Success criteria

- Both users log at least 2 meals a day for 2 consecutive weeks.
- Most photo estimates need only small edits (judged by feel; no formal accuracy target for v1).
- Monthly API cost is around US$1 in normal use and never goes above US$10.
- Average input under ~1,100 tokens and output under ~300 tokens per photo (checked from the usage counter in the first week).

## 13. Open questions

1. What daily calorie goal should each of us start with?
2. Do we care about macros (protein / carbs / fat), or just calories?
3. When a photo has several items, save them as separate entries or as one combined meal entry?
4. Should the app use English only, or also Bahasa Melayu?
5. Is syncing between the two phones wanted later (e.g. to see each other's meals)?
