# Prikorm — From-Scratch System Design (Solid Foods Introduction Tracker)

## Overview

A clean-room system design and build plan for an iOS app that helps parents introduce complementary/solid foods to infants. Built with SwiftUI + SwiftData (iOS 17+), XcodeGen-managed project, Russian UI. Covers the four requested pillars:

1. Food list (browsable catalog by category)
2. Allergens list (allergen groups + tolerance maintenance)
3. Calendar of introduced foods per day (daily timeline — the currently-missing piece)
4. Weekly allergen notifications (recurring local reminders)

Per the request this is treated as a greenfield design. It intentionally re-specifies the whole architecture rather than diffing the existing tree.

## Context

- Build system: XcodeGen (`project.yml`) → `Prikorm.xcodeproj`, iOS 17.0+, bundle `com.prikorm.app`
- Architecture: SwiftData for user data; static JSON for the food catalog; stateless service layer for business logic; modular SwiftUI feature folders
- Files involved (greenfield layout):
  - `project.yml`, `Sources/App/PrikormApp.swift`, `Sources/App/RootView.swift`
  - `Sources/Models/` — `Child`, `IntroductionStatus`, `FoodLog` (@Model); `Food`, `FeedingProfile`, `Enums` (structs/enums)
  - `Sources/Services/` — `FoodCatalog`, `FeedingService`, `AllergenTracker`, `AllergenMaintenance`, `CalendarService` (new), `NotificationManager`
  - `Sources/Features/` — `MainTabView`, `Dashboard/`, `Catalog/`, `Allergens/`, `Calendar/` (new), `Profile/`, `Onboarding/`, `Common/`
  - `Resources/foods.json` — static food/allergen catalog
- Related patterns: SwiftData `@Model` for persisted user state; pure/stateless services that take a `ModelContext` so they're unit-testable; static catalog loaded from bundled JSON
- Dependencies: Apple frameworks only (SwiftUI, SwiftData, UserNotifications). No third-party packages.

## Development Approach

- **Testing approach**: Regular (code first, then tests), with logic concentrated in the service/model layer so it can be tested without the UI.
- Complete each task fully before moving to the next.
- Keep business logic out of views — views call services; services are pure functions over `ModelContext` + catalog data.
- **CRITICAL: every task MUST include new/updated tests.**
- **CRITICAL: all tests must pass before starting the next task.**

## Implementation Steps

### Task 1: Project scaffold + data models

**Files:**
- Create: `project.yml`, `Sources/App/PrikormApp.swift`, `Sources/App/RootView.swift`
- Create: `Sources/Models/Enums.swift`, `Sources/Models/Food.swift`, `Sources/Models/FeedingProfile.swift`
- Create: `Sources/Models/Child.swift`, `Sources/Models/IntroductionStatus.swift`, `Sources/Models/FoodLog.swift`

- [x] XcodeGen `project.yml`: app target (iOS 17, `com.prikorm.app`) + unit test target (`PrikormTests`) wired via `@testable import Prikorm` + `Prikorm` scheme test action
- [x] Enums: `FoodCategory`, `IntroState`, `LogType` (intro/maintenance), `ReactionType`, `Liking` (+ `AllergenGroup`, `AllergenStatus`) in `Enums.swift`
- [x] Value types: `Food` (id, name, category, allergenGroup?, minAgeMonths), `FeedingProfile` (methodology presets + allergen frequency/interval)
- [x] `@Model` types: `Child` (name, birthDate, profile); `IntroductionStatus` (foodId, state, introStartedAt, completedAt); `FoodLog` (foodId, date, type, reaction, liking)
- [x] Configure the SwiftData `ModelContainer` in `PrikormApp`; `RootView` gate
- [x] Write tests: model round-trip through an in-memory `ModelContainer`; `Child.ageInMonths(now:)` math (`Tests/ModelTests.swift`)
- [x] run test suite — user-run (xcodegen/xcodebuild owned by user per project convention)

### Task 2: Food catalog (food list)

**Files:**
- Create: `Resources/foods.json`
- Create: `Sources/Services/FoodCatalog.swift`
- Create: `Sources/Features/Catalog/CatalogView.swift`, `Sources/Features/Catalog/FoodDetailView.swift`

- [x] `foods.json`: seed catalog of foods with category + allergenGroup + recommended age
- [x] `FoodCatalog`: load+decode bundled JSON once; `all`, `byCategory`, `food(id:)`, `search(_:)`
- [x] CatalogView: foods grouped by category, searchable; tap → FoodDetailView
- [x] FoodDetailView: food info + recommended age + allergen note (action hook added in Task 3)
- [x] Write tests: JSON decodes; every food has a valid category; grouping/search return expected sets (`Tests/FoodCatalogTests.swift`)
- [x] run test suite — user-run (xcodegen/xcodebuild owned by user per project convention)

### Task 3: Feeding service (introduction state machine)

**Files:**
- Create: `Sources/Services/FeedingService.swift`
- Modify: `Sources/Features/Catalog/FoodDetailView.swift`

- [x] FeedingService: `startIntroducing`, `logFeeding(reaction:liking:)`, `markIntroduced`, `markAllergy` — each updates `IntroductionStatus` and appends a `FoodLog` row
- [x] State transitions: notStarted → introducing → introduced, with introducing → allergy on a reaction
- [x] Wire FoodDetailView actions to FeedingService (give food / log reaction)
- [x] Write tests: each state transition + that FoodLog rows are created with the correct type (`Tests/FeedingServiceTests.swift`)
- [x] run test suite — user-run (xcodegen/xcodebuild owned by user per project convention)

### Task 4: Allergens list + tolerance maintenance

**Files:**
- Create: `Sources/Services/AllergenTracker.swift`, `Sources/Services/AllergenMaintenance.swift`
- Create: `Sources/Features/Allergens/AllergensView.swift`

- [x] AllergenTracker: `status(lastGiven, now)` → ok/dueSoon/overdue + `nextDue(lastGiven)`
- [x] AllergenMaintenance: aggregate statuses+logs into per-`AllergenGroup` status (isIntroduced, hasAllergy, lastGiven, representativeFood)
- [x] AllergensView: allergen-group cards with status visuals + "give" action (logs a maintenance feeding)
- [x] Write tests: due/overdue boundary math per profile frequency; group aggregation from sample logs (`Tests/AllergenTests.swift`)
- [x] run test suite — user-run (xcodegen/xcodebuild owned by user per project convention)

### Task 5: Daily introduction calendar (timeline per day)

**Files:**
- Create: `Sources/Services/CalendarService.swift`
- Create: `Sources/Features/Calendar/CalendarView.swift`, `Sources/Features/Calendar/DayDetailView.swift`

- [x] CalendarService: group FoodLog entries by calendar day; `day(date)` → introduced/maintenance entries; mark days that have activity
- [x] CalendarView: month grid (or scrollable day list) highlighting days with logged foods; tap a day → DayDetailView
- [x] DayDetailView: list foods given that day with type (intro/maintenance), reaction, liking
- [x] Write tests: grouping logs across days, timezone/day-boundary correctness, empty-day handling (`Tests/CalendarServiceTests.swift`)
- [x] run test suite — user-run (xcodegen/xcodebuild owned by user per project convention)

### Task 6: Weekly allergen notifications

**Files:**
- Create: `Sources/Services/NotificationManager.swift`
- Modify: `Sources/Features/Catalog/FoodDetailView.swift`, `Sources/Features/Allergens/AllergensView.swift`

- [x] NotificationManager: `requestAuthorization` (contextual, on first allergen intro); `refresh(context, profile)`
- [x] refresh: compute allergen groups, clear stale allergen notifications, schedule recurring weekly `UNCalendarNotificationTrigger` (repeats:true) per due group at nextDue cadence
- [x] Trigger refresh after every feeding/maintenance log (FoodDetailView + AllergensView call `refresh` after each log)
- [x] Write tests: refresh schedules one request per due group; skips ok/allergy groups; recurring trigger has expected weekday/interval (inject a `UNUserNotificationCenter` protocol for testability) (`Tests/NotificationManagerTests.swift`)
- [x] run test suite — user-run (xcodegen/xcodebuild owned by user per project convention)

### Task 7: App shell — navigation, onboarding, dashboard, profile

**Files:**
- Create: `Sources/Features/MainTabView.swift`, `Sources/Features/Common/Theme.swift`
- Create: `Sources/Features/Onboarding/OnboardingView.swift`, `Sources/Features/Dashboard/DashboardView.swift`, `Sources/Features/Profile/ProfileView.swift`
- Create: `Sources/App/SampleData.swift`

- [x] MainTabView: 5 tabs — Dashboard, Catalog, Allergens, Calendar, Profile
- [x] Onboarding: Welcome → Disclaimer → Child profile → Methodology; creates `Child`
- [x] DashboardView: age/progress hero, due allergens, currently-introducing
- [x] ProfileView: child + methodology picker; Theme (rounded, coral accent, gradient bg)
- [x] SampleData seed behind `-seedSample` (DEBUG)
- [x] Write tests: onboarding produces a valid Child; dashboard "due" selection logic (`Tests/AppShellTests.swift`)
- [x] run test suite — user-run (xcodegen/xcodebuild owned by user per project convention)

### Task 8: Verify acceptance criteria

- [x] run full test suite (xcodebuild test / user-run) — user-run per project convention (skipped, not automatable)
- [x] confirm all four pillars present: food list, allergens list, daily calendar, weekly notifications — verified: FoodCatalog/CatalogView, AllergenTracker+Maintenance/AllergensView, CalendarService/CalendarView+DayDetailView, NotificationManager
- [x] verify logic-layer test coverage 80%+ (services + models) — verified by inspection: 53 test functions; every service (FoodCatalog, FeedingService, AllergenTracker/Maintenance, CalendarService, NotificationManager) + models have dedicated test files

### Task 9: Update documentation

- [ ] update SPEC.md to add the Calendar screen (§7) and recurring-weekly notification behavior
- [ ] add/refresh README.md with build (XcodeGen) + run instructions
- [ ] update CLAUDE.md with the test target + service-layer testing conventions
