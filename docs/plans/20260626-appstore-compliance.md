# План — прохождение App Store Review

## Overview

Подготовить приложение к подаче в App Store так, чтобы пройти ревью с первого
раза. Старт — **local-only, бесплатно, категория Health & Fitness, аудитория —
родители** (не Kids Category). План закрывает требования, проверенные по живым
гайдам Apple (App Review Guidelines, App Privacy Details, User Privacy and Data
Use; июнь 2026).

Делим работу на три корзины: 🛠️ **CODE** (изменения в приложении/Info.plist),
⚙️ **ASC** (настройки App Store Connect при подаче), 🙋 **HOST/USER** (то, что
предоставляет пользователь: хостинг политики, support-email, аккаунт, скриншоты).

Главный риск ревью — **Guideline 1.4.1 (medical / physical harm)**: «if the level
of accuracy or methodology cannot be validated, we will reject your app». Наши
пресеты методик помечены `⚠️ UNVERIFIED` — это №1 на исправление.

**Вне скоупа (и почему):**
- **CloudKit-синк и его privacy-label** — на старте local-only; при добавлении
  синка данные становятся «collected» → отдельный пере-чек (5.1.3(ii), App Privacy).
- **StoreKit Pro / IAP (3.1.1, 2.1(b))** — фича ещё не построена; ревью IAP — позже.
- **Юридическая вычитка политики под GDPR/COPPA по рынкам** — нужен юрист; здесь
  готовим compliance-черновик под требования Apple Review, не юр-документ.
- **Сам хостинг privacy policy и support-страницы** — это 🙋 USER (даём готовый текст
  + константу-плейсхолдер под URL).

## Context

- **Files involved:**
  - Modify: `Sources/Models/FeedingProfile.swift` — пресеты `who/aap/russia`
    помечены UNVERIFIED; добавить поле источника (`source`, `sourceURL`) и
    верифицированные цифры
  - Modify: `SPEC.md` §13 — снять статус UNVERIFIED после сверки, проставить цитаты
  - Create: `docs/legal/methodology-sources.md` — точные источники методик (ВОЗ/ESPGHAN,
    AAP/NIAID, Нац. программа РФ) с цитатами/страницами
  - Create: `docs/legal/privacy-policy.md` — текст политики «Data Not Collected» (🙋 хостит USER)
  - Create: `Sources/App/AppLinks.swift` — константы `privacyPolicyURL`, `supportEmail`,
    `methodologyInfoURL` (плейсхолдеры, заполняет USER)
  - Modify: `Sources/Features/Profile/ProfileView.swift` — секция «О приложении»:
    ссылка на политику (обязательна in-app, 5.1.1(i)), support-контакт (1.5),
    источники методик, версия, дисклеймер; показать источник выбранной методики
  - Modify: `Sources/Features/Onboarding/OnboardingView.swift` — усилить формулировку
    дисклеймера («перед введением продуктов и медицинскими решениями — к педиатру»)
  - Modify: `Sources/Services/NotificationManager.swift` — (опц.) обобщить текст
    уведомления, чтобы на локскрине не светилось лишнее (4.5.4)
  - Audit (возможные правки): `Sources/Features/Catalog/FoodDetailView.swift`,
    `LogFeedingSheet.swift` — убрать прескриптивные формулировки («это аллергия»,
    «безопасно вводить») → рамка «дневник», не «диагноз» (1.4.1)
  - Create: `docs/SUBMISSION.md` — чек-лист подачи (⚙️ ASC + 🙋 USER)
- **Related patterns:** дисклеймеры уже есть в `OnboardingView.disclaimerStep` и в
  `ProfileView` (Section с «⚠️ Это не медицинский совет»); `Profile` — это Form-экран
  настроек, туда логично класть «О приложении». Ссылки — через SwiftUI `Link`/`openURL`.
  Усиление тестируемости — как в проекте (инъекция, чистые функции).
- **Dependencies:** только SwiftUI/UserNotifications (системные). Подтверждено:
  нет HealthKit-entitlement, нет `NSUserTrackingUsageDescription`, нет usage-строк,
  `GENERATE_INFOPLIST_FILE: YES` без приватных ключей — позиция «Data Not Collected»
  валидна. ATT-промт НЕ добавляем (нечего трекать).

## Development Approach

- Подход: Regular. Большая часть — контент/метаданные/UI и документы, юнит-логики мало.
- **Тестируемое vs нет:** верификация цифр методик — это сверка с источниками, не
  юнит-тест (валидируется цитатами в `methodology-sources.md` + Review Notes). Покрываем
  тонкую логику: каждый `FeedingProfile`-пресет несёт непустой `source`/`sourceURL`;
  отказ в правах на уведомления не ломает планировщик (расширить `NotificationManagerTests`).
  Текст дисклеймеров — константы, проверяем на непустоту/наличие ключевой фразы.
- **Плейсхолдеры (заполняет USER):** `AppLinks.privacyPolicyURL`, `AppLinks.supportEmail`,
  `AppLinks.methodologyInfoURL`; публичный хостинг политики; support-страница.

## Implementation Steps

### Task 1: Верифицировать методики и зафиксировать источники

Files:

- Create: `docs/legal/methodology-sources.md`
- Modify: `Sources/Models/FeedingProfile.swift`
- Modify: `SPEC.md` (§13)

[ ] Сверить цифры пресетов (`startAgeMonths`, `observationDays`, `allergenFrequencyPerWeek`,
    `allergenGroups`) с первоисточниками: ESPGHAN 2017 (JPGN), NIAID 2017 addendum / AAP,
    Нац. программа оптимизации вскармливания РФ (посл. изд.) — через web-ресёрч или PDF (SPEC §13)
[ ] Записать в `methodology-sources.md` точные цитаты + ссылки/страницы по каждому параметру каждой методики
[ ] Добавить в `FeedingProfile` поля `source: String` (человекочитаемая ссылка-цитата) и
    `sourceURL: String?`; заполнить для `who/aap/russia`; скорректировать цифры, если расходятся с источником
[ ] Где цифра — клинический консенсус (напр. частота поддержки из LEAP/EAT), а не буква
    гайдлайна — пометить это в `source` честной оговоркой (как требует SPEC §13)
[ ] Снять `⚠️ UNVERIFIED` из шапки `FeedingProfile.swift` и из SPEC §13; проставить статус «verified, источники в docs/legal»
[ ] Написать тесты (каждый пресет: `source` непустой; `sourceURL` валидный/непустой; цифры в разумных границах)
[ ] run project test suite — must pass before Task 2

### Task 2: Усилить дисклеймеры и показать источник методики

Files:

- Modify: `Sources/Features/Onboarding/OnboardingView.swift`
- Modify: `Sources/Features/Profile/ProfileView.swift`

[ ] Онбординг (`disclaimerStep`): формулировка явно покрывает «**перед введением новых
    продуктов и любыми медицинскими решениями — консультируйся с педиатром**» (клауза 1.4.1
    «remind users to check with a doctor before making medical decisions»)
[ ] Вынести текст дисклеймера в одну константу (напр. `Disclaimer.medical`), переиспользовать в онбординге и профиле — единый верифицируемый текст
[ ] Профиль, секция «Методика»: показать `LabeledContent`/строку с источником выбранного
    пресета (`profile.source`) + ссылку `sourceURL` (через `Link`)
[ ] Тесты: `Disclaimer.medical` непустой и содержит ключевую фразу про педиатра
[ ] run project test suite — must pass before Task 3

### Task 3: Секция «О приложении» — политика, поддержка, версия (in-app требования)

Files:

- Create: `Sources/App/AppLinks.swift`
- Modify: `Sources/Features/Profile/ProfileView.swift`

[ ] Создать `enum AppLinks` с `privacyPolicyURL`, `termsURL`, `supportEmail`, `methodologyInfoURL`
    (плейсхолдеры; пометить TODO «заполнить перед релизом», заполняются после деплоя сайта)
[ ] В `ProfileView` добавить Section «О приложении»:
    - `Link("Политика конфиденциальности", destination: AppLinks.privacyPolicyURL)` —
      **обязательная in-app ссылка** (5.1.1(i): «within the app in an easily accessible manner»)
    - `Link("Условия использования", destination: AppLinks.termsURL)`
    - строка поддержки: `Link`/`mailto:` на `supportEmail` (1.5 «easy way to contact you»)
    - версия приложения (`CFBundleShortVersionString`/`Bundle`)
    - источники методик (ссылка на `methodologyInfoURL` или экран)
    - оставить кредит OpenMoji (уже есть)
[ ] Гард: если URL-плейсхолдер пуст — строку прятать или вести на заглушку (не показывать битую ссылку)
[ ] Leaf-UI (ссылки/верстка) — без новой юнит-логики; прогнать набор на отсутствие регрессий
[ ] run project test suite — must pass before Task 4

### Task 4: Privacy Policy + Terms — как страницы сайта

> Privacy Policy и Terms делаем не markdown-черновиком, а реальными страницами в
> рамках **отдельного плана сайта**: [`20260626-website-landing.md`](20260626-website-landing.md)
> (Task 2–3 там). Сайт же даёт обязательный Privacy Policy URL (5.1.1) и Support URL (1.5).

[ ] Реализовать Privacy Policy и Terms на сайте (см. website-план, Task 2–3): контент под
    «Data Not Collected» (5.1.1(i)) + медицинский дисклеймер в Terms
[ ] После деплоя вписать боевые URL в `AppLinks` (`privacyPolicyURL`, `termsURL`) и в
    ASC → App Privacy → Privacy Policy URL (⚙️ ASC)
[ ] In-app ссылки на Privacy и Terms — в секции «О приложении» (Task 3 этого плана)

### Task 5: Уведомления и аудит формулировок (1.4.1 / 4.5.4)

Files:

- Modify: `Sources/Services/NotificationManager.swift`
- Audit/Modify: `Sources/Features/Catalog/FoodDetailView.swift`, `Sources/Features/Catalog/LogFeedingSheet.swift`

[ ] Подтвердить (и зафиксировать тестом), что при отказе в правах планировщик не падает и
    приложение полностью работает (5.1.2(i): уведомления не обязательны для функции)
[ ] (Опц.) Обобщить `content.body`, чтобы на локскрине не отображалось лишнего; заголовок-напоминание оставить нейтральным
[ ] Аудит UI-текстов на прескриптивность: заменить формулировки вида «это аллергия» / «безопасно
    вводить» на дневниковые/мягкие («отметить реакцию», «по согласованию с врачом») — рамка
    трекера, не диагноста (1.4.1)
[ ] Расширить `NotificationManagerTests`: отказ в правах → нет краша/пустой план; нейтральность текста при необходимости
[ ] run project test suite — must pass before Task 6

### Task 6: Verify acceptance criteria

[ ] прогнать полный тест-набор (схема `Prikorm`, прогон пользователем) — зелёный
[ ] 1.4.1: методики верифицированы и источники видны в приложении + готовы для Review Notes;
    дисклеймер явно про «консультацию с педиатром перед решениями»
[ ] 5.1.1(i): privacy policy доступна **и** в ASC-поле, **и** из приложения (Профиль → О приложении)
[ ] Privacy label = «Data Not Collected»; нет ATT-промта; нет HealthKit; нет usage-строк
[ ] 1.5: рабочий support-контакт в приложении и Support URL
[ ] Метаданные (2.3.8/5.1.4): нигде не подразумевается, что аудитория — дети; рейтинг 4+; категория Health & Fitness
[ ] Приложение полностью работает при отказе от уведомлений; текст уведомления нейтрален
[ ] новая логика (источники пресетов, отказ-путь уведомлений) покрыта юнит-тестами

### Task 7: Update documentation + чек-лист подачи

Files:

- Create: `docs/SUBMISSION.md`
- Modify: `SPEC.md`, `README.md`, `CLAUDE.md`

[ ] `docs/SUBMISSION.md` — чек-лист подачи по корзинам: ⚙️ ASC (категория Health & Fitness;
    App Privacy «Data Not Collected» → Save **и** Publish; Privacy Policy URL; рейтинг 4+;
    скриншоты «в деле», не сплеш; Notes for Review с пояснением local-only + источники методик),
    🙋 USER (хостинг политики, support-email/страница, аккаунт разработчика)
[ ] `SPEC.md` — отразить статус методик «verified», категорию, позицию по приватности
[ ] `README.md` / `CLAUDE.md` — упомянуть `AppLinks`, `Disclaimer.medical`, `docs/legal/*`,
    правило «не позиционировать как Kids»
[ ] напомнить про `xcodegen generate` (добавлены `AppLinks.swift` и тест-файлы)
