# Ответ на реджект 2.1 — Information Needed (1.0.0, build 4)

Реджект от Apple: «Guideline 2.1 — Information Needed». Это **не баг и не отказ по
существу** — ревьюер просит 7 пунктов информации в Resolution Center + в App Review
Information → Notes.

## Что было не так

К заявке видео **было** приложено (`PuddingReviewDemo.mp4`, COMPLETE в ASC), но оно
снято **на симуляторе** через `simctl io recordVideo`. Apple требует дословно:
«A screen recording captured on a **physical device**, running the latest operating
system». Плюс шаблонный запрос по пунктам 2–7, которых в Notes не было.

## План

1. Переснять демо на живом iPhone 17 (iOS 26.6) — встроенная запись экрана iOS.
2. Заменить вложение в App Review Information (старое удалить, новое залить).
3. Обновить Notes текстом ниже (через ASC API).
4. Ответить в Resolution Center полным текстом (руками — эндпоинта в API нет).

## Как переснять видео на устройстве

Запись экрана средствами самой iOS = «captured on a physical device», без вопросов.

1. На iPhone: Настройки → Пункт управления → добавить «Запись экрана».
2. Поставить билд 4 (или свежий Release) на устройство, **удалить старую копию**
   приложения — ревьюер должен видеть чистый первый запуск.
3. Включить «Не беспокоить», язык устройства — **English** (ревью в Купертино).
4. Начать запись экрана → выйти на домашний экран → **запустить приложение с иконки**
   (Apple прямо просит «begin with launching the app»).
5. Пройти сценарий из `UITests/ReviewDemoUITests.swift` руками, не спеша:
   welcome → медицинский дисклеймер → имя ребёнка → свой план → «что уже ввели» →
   **промт уведомлений** (обязательно показать: это единственный системный запрос) →
   главная → Каталог → поиск «banana» → карточка → «Start introducing» → «Log a
   feeding» (оценка, заметка, фото) → Save → кольцо «1 of 2 feedings» → Today →
   Allergens → Calendar → Profile → About (дисклеймер, Privacy, Terms, OpenMoji).
6. Остановить запись, AirDrop на Mac.

Целевая длина 2–3 минуты. Альтернатива ручному прогону — прогнать
`TEST_RUNNER_DEMO=1 … -only-testing:PrikormUITests/ReviewDemoUITests` **на устройстве**,
пока идёт запись экрана: сценарий тот же, паузы уже расставлены под чтение.

---

## Текст ответа в Resolution Center (копипаст)

```
Hello,

Thank you for the review. Below is the requested information. A condensed version has
also been added to App Review Information → Notes, and a new screen recording captured
on a physical device is attached to this submission.

1. SCREEN RECORDING
Attached: PuddingReviewDemo.mp4 — captured on a physical iPhone 17 running iOS 26.6
with the built-in iOS screen recorder. It begins with launching the app from the Home
screen and shows the complete typical flow: first-launch onboarding (medical
disclaimer → child's name → feeding plan → foods already introduced), the notification
permission prompt, the Today dashboard, the food catalog and search, opening a food
card and starting an introduction, logging a feeding (rating, note, optional photo)
and the resulting progress, the allergen list, the calendar diary, and Profile → About
with the privacy policy, terms and support links.
The app does NOT have: account registration, login or account deletion; paid content,
in-app purchases or subscriptions; user-generated content shared between users or any
social feed; an App Tracking Transparency prompt. The only system prompt is the
notification permission request, which is shown in the recording — the app remains
fully functional if the user declines it. Photos are attached through the system
PhotosPicker, so the app never requests access to the photo library.

2. DEVICES AND OPERATING SYSTEMS TESTED
- iPhone 17 (iPhone18,3) — iOS 26.6 — primary test device: full manual pass plus the
  automated unit and UI test suites
- iPhone 15 Pro Max (iPhone16,2) — iOS 26.6
- iPhone 13 (iPhone14,5) — iOS 26.4
Additionally the automated test suite runs on iPhone simulators from iOS 18.2 (the
app's minimum is iOS 17.0) through iOS 26.4, built with Xcode 26.4. The app is iPhone
only (TARGETED_DEVICE_FAMILY = 1).

3. WHAT THE APP DOES, AND FOR WHOM
Pudding is an offline diary for complementary feeding — the period when a baby starts
eating solid foods alongside milk. The target audience is parents and caregivers of
infants roughly 4 to 12 months old.
The problem: when solids are introduced, a new food is given every few days and the
parent has to remember which food was given, on which days, and how the child reacted.
This is normally tracked on paper or in a notes app, and when a reaction appears later
it is hard to reconstruct what the child actually ate. Pudding is that record, kept
properly: a bundled catalog of foods, a per-food "introducing" state the parent starts
manually, a feeding log with date, portion, how the child liked it, an optional note
and photo, a calendar view of the whole history, a list of introduced allergens with
reminders to repeat them, and a PDF export the parent can bring to their pediatrician.
The value is a complete, searchable history of what the child has eaten, in one place,
that survives phone changes through the user's own iCloud.
Important: the app is a diary, not an advisor. It gives no medical or feeding advice,
makes no diagnosis, and never tells a parent what or when to feed. Every parameter of
the plan (start age, observation window length, which foods count as allergens, how
often to repeat them) is configured by the user. A medical disclaimer recommending
consultation with a pediatrician is shown as an onboarding step BEFORE any child data
is entered, and is permanently available in Profile → About.

4. HOW TO SET UP AND ACCESS THE MAIN FEATURES
No account, no login credentials, no demo account and no sample files are required —
the app works offline immediately after installation. Every feature is reachable on a
fresh install:
- Launch the app. Onboarding: welcome → medical disclaimer ("Before you start" → "Got
  it") → the child's name and date of birth → the feeding plan (observation windows
  and the allergen list, all editable) → an optional list of foods already introduced
  → "Let's go". The notification permission is requested after onboarding.
- Today tab: today's journal, the foods currently being introduced, and the quick
  "log a feeding" action.
- Catalog tab: the bundled food catalog with search (search works in the interface
  language). Open any food → "Start introducing" begins an introduction → "Log a
  feeding" opens the feeding entry screen (portion, how the child liked it, reaction,
  note, photo). A food becomes "introduced" automatically after feedings on several
  DIFFERENT days (2 by default, 3 for allergens), so two feedings on the same day
  count as one.
- Allergens tab: introduced allergens and reminders to repeat them at the interval set
  in the plan.
- Calendar tab: the full diary as a feed or a month grid.
- Profile tab: child's profile, the feeding plan, the interface language picker, PDF
  export of the diary, the shareable recap card, and About with the medical
  disclaimer, privacy policy, terms of use, support contact and credits.

5. EXTERNAL SERVICES, TOOLS AND PLATFORMS
None. The app uses Apple frameworks only (SwiftUI, SwiftData, UserNotifications,
PhotosUI, PDFKit) and contains no third-party SDKs or packages. There is no backend we
operate, no authentication service, no payment processor, no analytics or advertising
service, no AI or machine-learning service, and no external data provider. The food
catalog is a static JSON file bundled inside the app. The only network activity is
Apple CloudKit, which syncs the user's records to their own private CloudKit database
inside their personal iCloud account; we have no access to it. Accordingly the app
declares "Data Not Collected".

6. REGIONAL DIFFERENCES
There are none — the app behaves identically in every region. Same features, same
bundled food catalog, same content everywhere; no region-gated features or content, no
regional pricing (the app is free everywhere with no in-app purchases), and no
server-side configuration that could vary by country. The interface is localized into
14 languages and follows the device language, with an optional in-app language picker;
the language affects wording only, never functionality.

7. REGULATED INDUSTRY AND THIRD-PARTY MATERIAL
The app is not a medical device and provides no medical, diagnostic or health services.
It records only what the parent types in, produces no assessment or recommendation, and
displays a disclaimer directing the user to their pediatrician. It does not use
HealthKit and stores no clinical records, so no licence or professional credential
applies.
The only third-party material in the app is the food and interface icon set OpenMoji
(https://openmoji.org), used under Creative Commons BY-SA 4.0 — a public licence that
permits use and modification with attribution. Attribution is shown inside the app in
Profile → About ("Icons: OpenMoji (CC BY-SA 4.0)"), which is why Content Rights is
declared as "uses third-party content". We can provide the full credits file on
request. All other assets — the app icon, illustrations, the mascot, the text of the
food catalog and every string in the app — were created by us.

Thank you,
Evgenii Varzin
```

## Notes для App Review Information

Сжатая версия тех же 7 пунктов **уже залита** через ASC API 14.08 (3994 символа —
жёсткий лимит поля 4000, API возвращает `ENTITY_ERROR.ATTRIBUTE.INVALID.TOO_LONG`).
Текст живёт в `docs/appstore/ASC-METADATA.md` §8.

## Осталось руками

- [ ] Переснять демо на iPhone (см. выше), заменить вложение
      `appStoreReviewAttachments` (старое `d714193a-…` удалить, новое залить).
- [ ] Вставить текст выше в **Resolution Center** — эндпоинта в ASC API нет,
      только веб: App Store Connect → приложение → App Review → сообщение от Apple → Reply.
- [ ] Подтвердить список устройств из пункта 2: iPhone 15 Pro Max и iPhone 13 стоят
      в списке спаренных, но проверь, что билд 4 реально гонялся на них — иначе убрать.
