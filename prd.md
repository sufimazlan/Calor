# Calor — Product Requirements Document

| | |
|---|---|
| **Product** | Calor — personal calorie tracker (iOS native) |
| **Owner** | Sufi |
| **Users** | Sufi and his wife (2 iPhones) |
| **Status** | Draft v0.1 |
| **Last updated** | 4 October 2026 |

---

## 1. Overview

Calor is a simple iPhone app for logging what we eat and tracking daily calories. The main feature is taking a photo of a meal: the app sends the photo to Claude, which identifies the foods and estimates calories and macros. The user reviews and edits the estimate before saving it.

The app is built for personal use only. It is not published to the App Store.

## 2. Goals

- Log a meal in under 30 seconds by taking a photo.
- See today's total calories against a daily goal at a glance.
- Recognise Malaysian dishes reasonably well (nasi lemak, roti canai, mee goreng, nasi campur, kuih, etc.).
- Keep running costs very low (target: under US$3/month for both users).
- Serve as a learning project for building a native iOS app from scratch.

## 3. Non-goals (v1)

- App Store release, sign-up or user accounts.
- Syncing data between the two phones (each phone keeps its own log).
- Barcode scanning, restaurant databases or a built-in food database.
- Exercise tracking, Apple Health integration or weight tracking.
- Android or web versions.

These can be revisited after v1 (see section 12).

## 4. Constraints

| Constraint | Detail |
|---|---|
| **Platform** | iOS only, built with Swift + SwiftUI in Xcode on a Mac |
| **Distribution** | Free Apple ID (Personal Team) signing. The app expires after 7 days and is reinstalled weekly from Xcode (wireless install once paired). |
| **AI provider** | Claude API, using an API key from the Claude Console (pay-as-you-go). A Claude Pro subscription does not cover API usage from an app. |
| **Developer experience** | Beginner in iOS development. Keep the architecture simple and avoid third-party libraries unless needed. |
| **Storage** | All data stored locally on each phone. No backend server. |

## 5. Users and use cases

**Primary users:** two adults, each using the app on their own iPhone with their own log and goal.

**Key use cases**

1. *Photo log:* "I'm about to eat lunch. I take a photo, the app tells me it's roughly 650 kcal, I adjust the rice portion and save."
2. *Manual log:* "I had a teh tarik earlier and didn't take a photo. I type it in with an estimated calorie number."
3. *Daily check:* "Before dinner, I check how many calories I have left for the day."
4. *History:* "I look back at what I ate this week and my daily totals."

## 6. Features and requirements

Priority: **P0** = must have for v1, **P1** = should have for v1, **P2** = later.

### 6.1 Today screen (home) — P0

- Shows today's date, total calories eaten, daily goal and calories remaining (a progress ring or bar).
- Lists today's entries grouped by meal (Breakfast, Lunch, Dinner, Snack), showing name, calories and a thumbnail if there is a photo.
- Prominent **"Snap meal"** button and a smaller **"Add manually"** button.
- Swipe to delete an entry; tap an entry to edit it.

### 6.2 Manual entry — P0

- Fields: food name (required), calories (required), meal type (auto-selected by time of day, editable), date/time (default now), optional protein / carbs / fat in grams, optional notes.
- Validation: calories must be a positive number.

### 6.3 Photo entry with Claude — P0

**Flow**

1. User taps **Snap meal**, takes a photo with the camera or picks one from the photo library.
2. The app resizes the image (longest side ~1024 px, JPEG quality ~0.7) and shows a loading state.
3. The app sends the image to the Claude API with the analysis prompt (section 8).
4. Claude returns structured JSON: a list of detected food items, each with name, estimated portion, calories and macros, plus a confidence level.
5. The app shows a **Review screen**:
   - Each item is editable (name, portion, calories, macros) and can be removed.
   - User can add a missing item manually.
   - Total updates live as the user edits.
6. User taps **Save**. Each item is saved as an entry (or one combined entry — see open question 3), with a small thumbnail of the photo.

**Requirements**

- Show a clear message if the photo doesn't look like food, or if confidence is low ("Please check these estimates").
- Handle errors: no internet, invalid API key, API overloaded or timeout. Show a friendly message with a **Retry** option and an option to switch to manual entry. Never lose the photo on error.
- The user can add an optional text hint before sending (e.g. "half portion of rice", "no sugar"), which is included in the prompt. — P1

### 6.4 Daily goal — P0

- User sets a daily calorie goal in Settings (default 2,000 kcal).
- Each phone stores its own goal.

### 6.5 History — P1

- A list of past days showing the daily total vs goal.
- Tap a day to see its entries (same layout as the Today screen).
- A simple 7-day bar chart of daily calories (Swift Charts). — P1

### 6.6 Settings — P0

- **Claude API key:** paste field, stored in the iOS Keychain (never in code, never in plain storage). Show only the last 4 characters once saved. Includes a **Test key** button.
- **Model choice:** Haiku 4.5 (default, cheapest) or Sonnet 5 (more accurate). — P1
- **Daily calorie goal.**
- **Usage counter:** number of photo analyses this month and rough estimated cost. — P1

### 6.7 Later ideas — P2

- Favourites / "log again" for repeat meals (e.g. the usual breakfast).
- Shared log or sync between the two phones (CloudKit).
- Apple Health integration.
- Home screen widget showing calories remaining.
- Weekly summary written by Claude.

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

- dailyGoalKcal: Int (default 2000)
- selectedModel: String (default Haiku 4.5)
- monthlyAnalysisCount: Int (resets each month)

**API key:** stored in the Keychain.

## 8. Claude integration

**Endpoint:** `POST https://api.anthropic.com/v1/messages`

**Headers:** `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`

**Models**

| Option | Model string | Use |
|---|---|---|
| Default | `claude-haiku-4-5-20251001` | Fast and cheapest |
| Accurate | `claude-sonnet-5` | Better on mixed plates |

**Request:** one user message containing the image (base64 JPEG) and a text instruction. `max_tokens` around 1,000.

**Prompt (draft)**

> You are a nutrition assistant for users in Malaysia. Identify each food and drink item in this photo and estimate its portion size and nutrition. Be familiar with Malaysian dishes (Malay, Chinese, Indian and mamak food) and use local names where appropriate. If the photo does not show food, set `is_food` to false. Respond with JSON only, no other text, matching this schema: …
> User note (optional): {hint}

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
  "notes": "Sambal portion looks generous."
}
```

**Parsing:** strip any code fences, decode with `Codable`. If decoding fails, show an error with **Retry** and **Add manually**.

**Security note:** the API key lives on the phone. This is acceptable for a personal app used by two people, but the key should never be committed to a git repository or hardcoded. A spend limit must be set in the Claude Console.

## 9. Cost estimate

Based on Haiku 4.5 pricing (US$1 per million input tokens, US$5 per million output tokens) and roughly 1,600 input tokens (photo + prompt) plus 400 output tokens per analysis:

| Scenario | Per photo | Per month (2 users × 4 photos/day) |
|---|---|---|
| Haiku 4.5 | ~US$0.004 | ~US$1 |
| Sonnet 5 | ~US$0.011 | ~US$2.60 |

A Console spend limit of US$5/month is enough, with plenty of buffer.

## 10. Non-functional requirements

- **Speed:** photo analysis result shown within ~10 seconds on a normal mobile connection.
- **Privacy:** photos are sent only to the Claude API. Only a small thumbnail is stored. No analytics or third-party tracking.
- **Offline:** Today, history and manual entry work fully offline; only photo analysis needs internet.
- **Reliability:** reinstalling the app weekly (free signing) must not delete saved data. Do not delete the app from the phone, only re-run it from Xcode.
- **Accessibility:** support Dynamic Type and Dark Mode (comes mostly free with SwiftUI).

## 11. Milestones

| Phase | Scope | Done when |
|---|---|---|
| 1. Setup | Xcode, Personal Team signing, blank app on both phones, Console API key | "Hello world" opens on both iPhones |
| 2. Manual logging | Data model, Today screen, manual entry, edit/delete, daily goal | Can log a meal by hand and see today's total |
| 3. Photo + Claude | Camera/photo picker, image resize, API call, review screen, Keychain key, errors | Can snap a meal and save Claude's estimate |
| 4. Polish | History, 7-day chart, model choice, usage counter, text hint | Comfortable to use daily for a week |
| 5. Rollout | Install on wife's iPhone, wireless install set up | Both of us using it daily |

## 12. Success criteria

- Both users log at least 2 meals a day for 2 consecutive weeks.
- Most photo estimates need only small edits (judged by feel; no formal accuracy target for v1).
- Monthly API cost stays under US$3.

## 13. Open questions

1. What daily calorie goal should each of us start with?
2. Do we care about macros (protein / carbs / fat), or just calories?
3. When a photo has several items, save them as separate entries or as one combined meal entry?
4. Should the app use English only, or also Bahasa Melayu?
5. Is syncing between the two phones wanted later (e.g. to see each other's meals)?
