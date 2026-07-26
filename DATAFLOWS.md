# Data flows

This document describes how data moves through Budgie Diet for the app's core interactions: what views are involved, what SwiftData models get created or changed, what validation/business logic runs, and how the result is persisted to SwiftData, HealthKit and CloudKit. It's a companion to `ARCHITECTURE.md` — read that first for the design principles these flows are built to respect.

File and line references below point at the current state of the codebase and will drift as it changes; treat them as a starting point for navigation, not a permanent index.

## Contents
1. [Logging food/calories](#1-logging-foodcalories)
2. [Logging hydration/water intake](#2-logging-hydrationwater-intake)
3. [Weight logging & goal weight](#3-weight-logging--goal-weight)
4. [Calorie budget calculation ("left to eat")](#4-calorie-budget-calculation-left-to-eat)
5. [HealthKit read/write sync](#5-healthkit-readwrite-sync)
6. [SwiftData model relationships & persistence](#6-swiftdata-model-relationships--persistence)
7. [Default meal times](#7-default-meal-times)

---

## 1. Logging food/calories

**Entry view:** `Budgie/Views/Food Logging/AddCalsSheet.swift` (iOS), with a parallel implementation at `Budgie Mac/MacAddFoodSheet.swift`. One form supports three logging modes: a quick manual calorie entry, scaling an existing saved `FoodItem` from the catalogue, or logging while also saving a new food for reuse later.

**Models involved:**
- `CalorieEntry` (`Budgie/Code/Data Model/CalorieModel.swift:65-116`) — `id`, `date`, `calories`, `narrative` (blank/nil normalises to `"Quick calories"`), `isInHK`, `healthKitUUID`, `realEntry`, `meal: UUID` (references `Meal.mealUUID`, not a SwiftData relationship), `syncNonce`, `foodItem: UUID?`, `manufacturer`, `servingUnit`, `servingAmount`, and macro fields `protein`/`fat`/`carbs`.
- `Meal` (same file, lines 30-49) — `id`, `mealUUID`, `name`, `order`, `budgetPercent`, `startMinute: Int?` (see [§7](#7-default-meal-times)).

**Validation:**
- `AddCalsSheet.canSave` (`AddCalsSheet.swift:66-71`) gates the Log button in the UI: a picked food needs a valid quantity (`effectiveServings > 0`); "also save" additionally requires calories > 0 and a non-empty trimmed name; a plain quick entry just needs calories > 0.
- The real source of truth is at the persistence layer: `HealthData.addCalories` (`HealthData.swift:403`) and `HealthData.addFoodEntry` (`HealthData.swift:413`) both guard `calories`/`servings > 0` before doing anything, independent of the UI check.
- Blank/nil narrative is normalised to `"Quick calories"` both on creation (`CalorieEntry.init`, `CalorieModel.swift:107`) and on edit (`CalorieActor.updateCalories`, `CalorieModel.swift:308`).

**Save path** (`AddCalsSheet.saveEntry()`, `AddCalsSheet.swift:439-475`):
1. Existing food picked → `HealthData.addFoodEntry(...)`.
2. "Also save as new food" → a new `FoodItem` (source `.userInput`) is inserted via `foodItemActor.insert(food)`, past matching quick entries are retroactively linked (`CalorieActor.linkQuickEntries`, `CalorieModel.swift:465-483`), then `addFoodEntry` runs as above.
3. Plain quick entry → `HealthData.addCalories(...)`.
4. Every path ends with `dataStore.updateLump(todayLump:)`, refreshing the shared `TodayLump` used everywhere the budget is displayed (see [§4](#4-calorie-budget-calculation-left-to-eat)).

**Persistence internals** (`HealthData.swift:403-433`):
- An `HKQuantitySample` is written to `.dietaryEnergyConsumed` (`saveHKSample`, lines 381-391), capturing its UUID.
- Paired protein/fat/carb HK samples are written and tagged with that UUID via a shared metadata key, `macroGroupKey` (`SearchPredicates.swift:51`), so they can be found and deleted together.
- A `CalorieEntry` is stamped with the HK UUID (nil if the write failed, or on Mac where there is no HealthKit) and inserted via `CalorieActor.insertNewCals` (`CalorieModel.swift:217-233`), which does the SwiftData insert + save. If the SwiftData save fails, the just-written HK sample and macro samples are deleted again (iOS) or the insert is rolled back (Mac) — SwiftData and HealthKit can't be committed atomically, so this is a manual compensating transaction.
- Editing an entry can't update an HK sample in place, so `CalorieActor.updateCalories`/`updateFoodEntry` (lines 303-334) delete the old eaten+macro samples and write fresh ones (`rewriteHKSample`, lines 279-290) before mutating the SwiftData row.
- Deleting an entry (`CalorieActor.deleteEntries`, lines 336-346) deletes the paired HK samples first, then the SwiftData row.

**Cross-device reconciliation:** `HealthData.reconcileCalories()` (`HealthData.swift:919-958`) is the safety net for entries logged on a device without HealthKit (i.e. Mac): it adds missing HK samples for Mac-logged entries once they arrive via CloudKit, fixes stale samples after a Mac edit, and deletes orphaned HK samples for deleted entries — with a 30-minute grace period (`deleteConfirmedOrphans`, lines 1005-1028) to avoid a race against CloudKit sync deleting samples that are still in flight. It runs from the CloudKit remote-change observer and from `BudgetView`'s scene-active handling (`BudgetView.swift:280`, `416`).

---

## 2. Logging hydration/water intake

**Entry view:** `Budgie/Views/Water Logging/AddWaterSheet.swift`, plus `Budgie Mac/MacAddWaterSheet.swift`. Offers a manual amount field and four quick-add preset buttons.

**Model:** `WaterEntry` (`Budgie/Code/Data Model/WaterModel.swift:22-37`) — `id`, `date`, `quantity: Int` (millilitres; display-unit conversion happens in the view), `healthKitUUID`, `syncNonce`. There is no dedicated validation model — the actor just persists what it's given.

**Validation:**
- `AddWaterSheet` shows an alert if the manual amount is ≤ 0 (`amountWasZero`, lines 84-89, 111).
- `HealthData.addWater` (`HealthData.swift:435-440`) guards `amount > 0` again independently of the UI.

**Save path:** `AddWaterSheet.logWater(_:)` → `dataStore.addWater(amount:datetime:)` → `HealthData.addWater`:
1. Writes an HK sample to `.dietaryWater` in millilitres.
2. Builds a `WaterEntry` stamped with the returned HK UUID and inserts it via `WaterActor.addWater(object:)` (`WaterModel.swift:60-75`). On a SwiftData save failure, the entry is removed from the context and the just-written HK sample is deleted — the same compensating-transaction pattern as calorie logging.

Deletion (`WaterActor.deleteEntries`, `WaterModel.swift:77-87`) deletes the paired HK sample first. `HealthData.reconcileWater()` (`HealthData.swift:960-992`) mirrors the calorie reconciliation logic for water entries logged on HK-less devices.

**Reads/totals:** `HealthData.getWaterOnDate` (`HealthData.swift:511-529`) sums Budgie's own `WaterEntry`s plus HK's `.dietaryWater` samples, excluding samples already mirrored from Budgie itself (`excludingMirroredPredicate`, `HealthData.swift:29-35`) to avoid double-counting. The water goal (`waterGoal(activeCalories:)`, `DataClasses.swift:363-366`) optionally tops up the base goal by 1ml per active calorie burned, when enabled in settings.

---

## 3. Weight logging & goal weight

**No SwiftData model exists for weight.** Weight is stored exclusively in HealthKit (`.bodyMass`, `SearchPredicates.swift:41`) — there is no `WeightEntry` model in the app.

**Logging view:** `Budgie/Views/Weight/LogWeightSheet.swift`. `save()` (lines 58-77) validates weight > 0 kg (else shows an alert), then writes directly to HealthKit via `dataStore.saveHKSample(...)` — no SwiftData write. On success, `dataStore.updateLump(todayLump:)` refreshes `TodayLump` from the new HK data.

**Reads:**
- `HealthData.getLatestWeight()` (`HealthData.swift:455-486`) — most recent samples within 90 days, feeding `TodayLump.weightToday`/`weightYesterday`.
- `HealthData.getAverageWeight(from:to:)` (`HealthData.swift:169-179`) — trailing 7-day averages.
- `HealthData.weightSeries(from:to:)` / `fetchWeightTrend` (`HealthData.swift:536-543`, `602-612`) — build the weight chart, blending all HK sources.
- `fetchBudgieWeightSamples`/`fetchOtherWeightSamples` (`HealthData.swift:489-509`) split Budgie-logged vs. other-app samples for display.

**Goal weight storage:** Plain iCloud-synced scalars on `CloudSettings` (`Budgie/Code/Data Model/UserSettings.swift`): `weightGoal`, `startWeight`, `surplusMode` (gain vs. lose direction). Set from `Budgie/Views/Weight/WeightGoalSheet.swift`, which also resets `startWeight` to the current weight if the previous goal had already been met.

**Progress against goal:** Computed on `TodayLump` (`Budgie/Code/Data Model/DataClasses.swift`) — the shared observable "today" model, not a persisted one. `weightToGo`, `weightGoalProgress`, `weightGoalMet`, `weightGoalRemaining` (lines 163-201) are pure computed properties over the settings above and `weightToday`. `weightTrend`, `expectedWeeklyChangeExact`, `performanceAgainstWeightTrend` and `trendStanding` (lines 203-241) compare actual weekly weight change against what the recorded average deficit would predict, classifying behind/on-target/ahead against a tolerance band.

**Safety-limit logic (underweight goal warning):** Implemented in the **view**, not the model layer — `Budgie/Views/Weight/WeightGoalSheet.swift:36-108`. `goalBMI` computes BMI from the entered goal weight and stored height; `goalIsUnderweight`/`goalIsExtremelyLowWithoutHeight` drive a warning label and an NHS "advice for underweight adults" link. This is a warning only: it does not block saving, and the user can still set an underweight goal. Per `ARCHITECTURE.md`'s stated convention that hard safety limits belong in the model layer, this is worth noting as a divergence — it's a soft dissuasion rather than a hard prevention, which matches the "attempt to dissuade... actively prevent" distinction the safety principles draw between extreme-but-plausible and wildly-unrealistic choices, but it means the limit is bypassable if the view is ever skipped.

---

## 4. Calorie budget calculation ("left to eat")

**Single shared function:** `computeBudget(averageBurn:)` (`Budgie/Code/Data Model/DataClasses.swift:391-402`):

```
uncapped = averageBurn - desiredDeficit
budget = max(uncapped, 1200)                     // hard safety floor
if capBudget && !surplusMode && budget > capBudgetCals {
    budget = max(capBudgetCals, 1200)
}
atMin = uncapped < 1200 || (atCap && capBudgetCals < 1200)
```

This is the one place the 1,200kcal safety floor and the optional user-configured cap are enforced, and it's a free function (not a method) specifically so it can be reused for both "today" and historical/chart days.

**"Today" caller:** `TodayLump.recalculateBudget()` (`DataClasses.swift:79-84`) calls `computeBudget(averageBurn: totalProjCalories)`, where `totalProjCalories` is today's recorded HK active+basal burn plus a projection of the rest of the day (line 113-115). This is invoked from `HealthData.updateLump(todayLump:)` (`HealthData.swift:805`) — the single "refresh everything" entry point called after every log/edit/delete action, and from HK observer callbacks, remote-change notifications, and scene-active transitions.

**Average burn over the prior week:** `HealthData.getAverageCalories(from:to:type:)` (`HealthData.swift:181-233`) sums HK active/basal energy per day over the trailing week, blending in manually-configured activity/BMR estimates for any day missing HK data. `getProjActiveCalories()`/`getProjBasalCalories()` project the remainder of today, weighting earlier-in-the-day exercise more heavily than later (`weightActiveProjection`, `Budgie/Code/DateFuncs.swift:123ff`).

**Deficit/surplus:** `desiredDeficit` (positive = deficit) is subtracted from `averageBurn`. `surplusMode` flips interpretation for gaining vs. losing, and disables the cap (capping a surplus target doesn't make sense).

**Display:** `Budgie/Views/Main page/BudgetView.swift` doesn't compute anything itself — it renders `GaugeView` and `MeterView`, which read pre-computed properties off `TodayLump`. The "left to eat now" figure (`TodayLump.canEatNow`, `DataClasses.swift:102-111`) additionally applies a time-of-day pacing curve (`canEatNow(budget:minsIntoDay:finalMealTime:)`, `Budgie/Code/DateFuncs.swift:83-97`) unless per-meal budget allocations are enabled, in which case it's simply the flat remaining daily budget.

**Confirmed single source of truth, reused across platforms:** `computeBudget` is the only implementation of the floor/cap logic — called from `TodayLump.recalculateBudget()` (today) and again from `macroGoalSeries` (historical chart days), both explicitly using "the exact formula `recalculateBudget()` uses." Mac (no HealthKit) never recomputes it: `TodayLump.applyBudgetSnapshot(...)` (`DataClasses.swift:305-309`) consumes a snapshot the iPhone previously published to `CloudSettings` (written in `HealthData.updateLump`, lines 811-834), and the same numbers are mirrored into the App Group `UserDefaults` for the widget (`publishWidgetSnapshot`, lines 861-874). So there is exactly one authoritative computation, done on the phone, mirrored — never recomputed — to Mac, widget and Watch.

---

## 5. HealthKit read/write sync

**Core manager:** `HealthData` (`Budgie/Code/Data Model/HealthData.swift`), a singleton (`HealthData.shared`, exposed as the global `dataStore` in `BudgieApp.swift:22`). It owns the `HKHealthStore`, the `ModelContainer`, and the three `@ModelActor`s (`calorieActor`, `waterActor`, `foodItemActor`).

**Authorisation:** Requested via SwiftUI's `.healthDataAccessRequest` modifier at three sites: `BudgetView.swift:306` (main flow, after first run), `Budgie/Views/Helpers/FirstRunWizard.swift:126-127` (onboarding), and `Budgie/Views/Settings/SettingsView.swift:361` (a narrower request for the Move-goal read, gated on that setting). Type sets are centralised in `Budgie/Code/SearchPredicates.swift`: `writeTypes` (eaten energy, water, body mass, protein, fat, carbs) and `readTypes` (all of the above plus active/basal energy and the activity-rings summary). Every write additionally re-checks `authorizationStatus(for:) == .sharingAuthorized` immediately before writing, so a permission revoked after the fact fails safe rather than throwing.

**Read pattern:** One-shot async queries (`HKStatisticsQueryDescriptor`, `HKSampleQueryDescriptor`, `HKStatisticsCollectionQuery`), wrapped in Swift concurrency directly or via `withCheckedContinuation` for older completion-handler APIs. A shared helper, `dailyStatisticsSeries` (`HealthData.swift:142-159`), wraps day-bucketed collection queries once and is reused by every chart series builder (weight, calories, macros, water, burn).

**Write pattern:** Plain one-off `HKQuantitySample` writes/deletes (`saveHKSample`/`deleteHKSample`, lines 381-401) — no workout builder or batch API. Every Budgie-authored sample's UUID is stamped onto the corresponding SwiftData row so it can be found, deleted or rewritten later; macro samples are grouped to their parent via a shared metadata key rather than a native HK correlation type.

**Background delivery/observers:** `setUpObserverQueries(todayLump:)` (`HealthData.swift:877-896`, called once from `BudgetView.task`) enables hourly background delivery and registers an `HKObserverQuery` for each relevant type; each callback triggers a full `updateLump` refresh. There are no anchored-object queries in this codebase — every read is either a point-in-time statistics query or an observer-triggered full refresh.

**CloudKit remote-change sync:** `setUpRemoteChangeObserver(todayLump:)` (`HealthData.swift:898-905`) listens for `NSPersistentStoreRemoteChange` — fired when SwiftData's CloudKit mirroring pulls in another device's changes — and on that notification runs `updateLump` and `reconcileHealthKit()`. This is how, for example, a food entry logged on the Mac (no local HealthKit) ends up mirrored into this device's own HealthKit store once CloudKit syncs it down.

**Reconciliation:** `reconcileHealthKit()` → `reconcileCalories()`/`reconcileWater()` (`HealthData.swift:911-992`) is the general "make HealthKit agree with SwiftData, our source of truth" routine (see [§1](#1-logging-foodcalories)/[§2](#2-logging-hydrationwater-intake)), with a 30-minute orphan-deletion grace period to tolerate Watch/Mac-then-CloudKit-sync races.

---

## 6. SwiftData model relationships & persistence

**Schema:** Four `@Model` classes, deliberately linked by plain UUID fields rather than SwiftData `@Relationship` macros — noted explicitly in `MealComponent`'s definition (`Budgie/Code/Data Model/FoodItems.swift:117-120`) as necessary to stay CloudKit-sync-safe.

- `Meal` (`CalorieModel.swift:30-49`)
- `CalorieEntry` (`CalorieModel.swift:65-116`) — links to `Meal` via `meal: UUID` and to `FoodItem` via `foodItem: UUID?`
- `WaterEntry` (`WaterModel.swift:22-37`) — standalone
- `FoodItem` (`FoodItems.swift:205-237`) — `quantities: [FoodQuantity]` and `components: [MealComponent]` are `Codable` struct arrays, not to-many relationships; `components` references other `FoodItem`s by `foodItemID: UUID` for custom-meal ingredients.

Every model carries a `syncNonce: Int` — a manual dirty-bit a caller can bump to force a field write and trigger CloudKit re-propagation when something otherwise wouldn't have changed.

**`ModelContainer`/`ModelContext` setup:** `HealthData.init()` (`HealthData.swift:39-65`), private and singleton-only:
- Two `ModelConfiguration`s: `calorieMealConfig` (schema `[CalorieEntry, Meal, FoodItem]`) and `waterConfig` (separate store, schema `[WaterEntry]`). Both share the app-group container (`group.JoeBaldwin.Budgie`, for widget/Watch access) and the same private CloudKit database.
- If container creation fails, the app falls back to an in-memory-only configuration rather than crashing, surfaced to the user as a "Storage problem" alert (`BudgetView.swift:258-262`).
- Three `@ModelActor`s (`calorieActor`, `waterActor`, `foodItemActor`) wrap the one container, each owning its own `ModelContext` for safe concurrent access from async call sites.

**App entry point:** `Budgie/BudgieApp.swift`. Top-level globals: `healthStore`, `settingsObj` (`CloudSettings`), `localSettings` (`UserSettings`), `dataStore = HealthData.shared`. `BudgieApp.init()` seeds the four default meals only for a genuinely new account (guarded against double-seeding on a second device before CloudKit sync arrives), runs the one-time legacy-entry migration, and deduplicates foods/meals that raced during CloudKit sync. `RootView` switches between `FirstRunWizard` and `BudgetView` based on `settingsObj.isFirstRun`.

**CloudKit monitoring:** `Budgie/Code/Data Model/CloudSyncMonitor.swift` listens for `NSPersistentCloudKitContainer.eventChangedNotification` purely to expose an `isImporting` flag, so the UI can show "Syncing from iCloud…" instead of a misleadingly empty list on a fresh install. It's read-only observability — it never triggers or forces sync.

**Backup/restore:** `Budgie/Code/Data Model/DataPortability.swift` defines `Codable` DTOs mirroring each model, used by the actors' `export`/`import`/`wipe` methods for the manual export/import feature (`Budgie/Views/Settings/DataManagementView.swift`).

---

## 7. Default meal times

Meals can optionally carry a `startMinute: Int?` (minutes since local midnight). `AddCalsSheet` (and the Mac equivalent) auto-selects the meal whose window covers the current time when the sheet opens, instead of always defaulting to "Snacks/Other."

**Model change:** `Meal.startMinute: Int?` (`CalorieModel.swift:39-41`); `nil` means the meal doesn't participate in auto-selection. Default seeding (`CalorieActor.setUpMeals`, lines 239-255) sets Breakfast → 00:00, Lunch → 12:00, Dinner → 17:00, leaving Snacks/Other with no start time so it remains the catch-all fallback.

**Resolution logic (model layer):** `CalorieActor.resolveMealForNow(reference:snacksFallback:)` (`CalorieModel.swift:368-377`) filters meals whose `startMinute` has passed and picks the most recently started one, falling back to the Snacks/Other UUID if the current time is before every meal's start. `setMealStartMinute(mealUUID:minute:)` (lines 380-385) persists or clears a single meal's start time.

**Food-logging integration:** `AddCalsSheet.swift:168-178` resolves, in order: an explicit `preSelectedMeal` if valid, then `resolveMealForNow`, then the first meal in the list. `Budgie Mac/MacAddFoodSheet.swift:344-349` applies the same resolution once per sheet load.

**Settings UI:** `Budgie/Views/Settings/ManageMeals.swift` has a per-row start-time control (`DatePicker`, hour/minute only) with a clear button; changes go through `calorieActor.setMealStartMinute`, keeping persistence in the actor rather than the view.

**Backup compatibility:** `MealDTO.startMinute: Int?` in `DataPortability.swift` is optional, so pre-feature backups still decode, correctly interpreting a missing key as "no start time."
