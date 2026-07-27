# План — локализация (RU + EN)

> **Статус: закрыт** (2026-07-27). Ушли дальше плана: не RU+EN, а **14 языков** (`Localizable.xcstrings`, 523 ключа) + внутриапповый выбор языка (`AppLanguage`/`LanguageManager`) и витрина ASC на 15 локалей.

## Overview

Добавить английскую локализацию к приложению (сейчас весь UI — хардкод русских
строк). Русский остаётся языком-исходником, добавляем English через **String
Catalog** (`Localizable.xcstrings`). После — приложение следует языку устройства;
«Союз педиатров РФ» уже скрыт вне `ru` (сделано: `FeedingProfile.visiblePresets`).

Переводы готовы: **`docs/localization/strings-ru-en.json`** (UI-строки, 72 названия
продуктов, дни недели, отдельно интерполяция и склонения).

**Главная сложность — не перевод, а проводка под SwiftUI:**
- `Text("литерал")` локализуется автоматически; `Text(переменная)` — НЕТ.
- Кастомные компоненты принимают `String` и рисуют `Text(строка)` → не локализуются
  без правок.

**Вне скоупа:** другие языки кроме EN; локализация лендинга `site/` (там уже есть
EN-версия отдельно); App Store метаданные.

## Context

- **Уже сделано (в main):** `FeedingProfile.visiblePresets(language:)` скрывает РФ вне
  `ru`; метка «(Европа)» у ВОЗ/ESPGHAN; форс `.environment(\.locale, .ru)` и `.locale(.ru)`
  в датах — **временный, его снять при локализации** (RootView + 5 мест с `.formatted`).
- **Файлы под правку:**
  - Create: `Resources/Localizable.xcstrings` — String Catalog (sourceLanguage `ru`, en-переводы)
  - Modify: `project.yml` — `options.developmentLanguage: ru` (+ regen)
  - Modify: `Sources/App/RootView.swift` — УБРАТЬ `.environment(\.locale, .ru)` (даты пойдут по локали)
  - Modify: даты — убрать `.locale(.ru)` в `DayDetailView`(×2), `CalendarView`, `FoodDetailView`, `UIHelpers.shortDate`
  - Modify: `Sources/Features/Common/Components.swift` — `BigButton`/`PillButton`/`GhostButton`/`Chip`/`StatusBadge` параметры `String` → `LocalizedStringKey`
  - Modify: `Sources/Features/Common/MethodologyCard.swift` — `paramChip` подписи; источник/оговорка
  - Modify: `Sources/Models/Enums.swift` — все `.title`/`.shortTitle` → `String(localized:)`
  - Modify: `Sources/Models/FeedingProfile.swift` — `name`/`source`/`caveat` пресетов → `String(localized:)`
  - Modify: `Sources/Models/Food.swift` — добавить `localizedName` (`String(localized: .init(name))`)
  - Modify: вызовы `Text(food.name)`/`entry.foodName` → `food.localizedName` (CatalogView, FoodDetailView, LogFeedingSheet, DayDetailView)
  - Modify: `CalendarView` — дни недели через `String(localized:)` (массив `weekdays`)
  - Modify: `DashboardView`/`AllergensView` — склонения `Int.plural(...)` → локаль-зависимо
- **Related patterns:** тесты не трогают строки (проверяют логику) — должны остаться зелёными.
- **Dependencies:** только системные (String Catalog, Foundation). Resources — это группа в
  project.yml, `.xcstrings` скомпилируется автоматически.

## Development Approach

- Regular. Тестировать английский без смены языка устройства:
  `xcrun simctl launch <sim> com.prikorm.app -AppleLanguages "(en)" -AppleLocale en_US`.
- Собирать на симуляторе, скринить и RU, и EN.
- Коллизия: **«Поддержка»** = Maintenance (тип записи) И Support (контакт) — в каталоге
  один ключ перепутает. Развести явными ключами (`String(localized: "maintenance.type", defaultValue: "Поддержка")`
  и `"support.link"`). В `strings-ru-en.json` помечены как `Поддержка_тип`/`Поддержка_контакт`.

## Implementation Steps

### Task 1: Инфраструктура String Catalog

Files: `project.yml`, `Resources/Localizable.xcstrings`, `RootView.swift`, даты

[x] `project.yml`: добавить `options.developmentLanguage: ru`; `xcodegen generate`
[x] Создать `Resources/Localizable.xcstrings` (sourceLanguage `ru`, version 1.0) — пока пустой/скелет
[x] Убрать `.environment(\.locale, .ru)` из RootView и `.locale(.ru)` из 5 мест с датами
[x] Собрать; убедиться, что Xcode компилирует каталог (в бандле появится `en.lproj`)
[x] run project test suite — must pass before Task 2

### Task 2: Локализуемые компоненты (String → LocalizedStringKey)

Files: `Components.swift`, `MethodologyCard.swift`

[x] `BigButton.title`, `PillButton.title`, `GhostButton.title`, `Chip.text`, `StatusBadge.text`
    → тип `LocalizedStringKey`; внутри `Text(title)` уже локализует литералы
[x] Проверить все вызовы — литералы локализуются; где передаётся переменная (enum.title,
    food.name) — см. Task 3/4
[x] Тесты зелёные (UI-логика не изменилась)
[x] run project test suite — must pass before Task 3

### Task 3: Динамические строки моделей (String(localized:))

Files: `Enums.swift`, `FeedingProfile.swift`, `Food.swift`

[x] `Enums.swift`: все `.title`/`.shortTitle` (FoodCategory, AllergenGroup, IntroState,
    ReactionType, Liking, AllergenStatus) → `String(localized:)`
[x] `FeedingProfile`: `name`/`source`/`caveat` пресетов → `String(localized:)` (длинные caveat — тоже)
[x] `Food.localizedName` = `String(localized: String.LocalizationValue(name))`; заменить
    `Text(food.name)`/`entry.foodName` на localizedName в CatalogView/FoodDetailView/LogFeedingSheet/DayDetailView
[x] `CalendarView` дни недели: `weekdays.map { String(localized: ...) }` или `Text(LocalizedStringKey(d))`
[x] run project test suite — must pass before Task 4

### Task 4: Наполнить каталог + интерполяция + склонения

Files: `Localizable.xcstrings`, `DashboardView.swift`, `AllergensView.swift`

[x] Сгенерировать `Localizable.xcstrings` из `strings-ru-en.json` (ui + foods + weekdays):
    ключ = RU-строка, `localizations.en.stringUnit.value` = EN
[x] Интерполяция: ключи с `%lld`/`%@` (как SwiftUI генерит из `Text("День \(x) из \(y)")`),
    EN с тем же порядком плейсхолдеров (см. `_interpolated` в JSON)
[x] Склонения: для `Int.plural` сделать локаль-зависимый вариант ИЛИ перевести строки
    «N продуктов введено», allergenWord на англ. формы (one/other). Самый чистый путь —
    plural-вариации в каталоге (`variations.plural`) + `String(localized:)`
[x] Развести коллизию «Поддержка» (Maintenance vs Support) явными ключами
[x] run project test suite — must pass before Task 5

### Task 5: Verify acceptance criteria

[x] Прогон тестов зелёный
[x] RU-симулятор: всё по-русски как раньше (регрессий нет), РФ-пресет виден
[x] EN-симулятор (`-AppleLanguages "(en)"`): весь UI на английском — вкладки, кнопки,
    каталог + названия продуктов, методики, реакции, даты, дни недели, алерты
[x] EN: «Союз педиатров РФ» скрыт; уже выбранный РФ (если был) резолвится без краша
[x] Нет «смешанных» экранов (русские хвосты на англ. языке)
[x] Склонения корректны на обоих языках

### Task 6: Update documentation

[x] `CLAUDE.md` — локализация через String Catalog, RU sourceLanguage, как тестировать EN
[x] `SPEC.md` §9/§10 — двуязычность RU/EN
[x] напомнить про `xcodegen generate` (изменён project.yml)
