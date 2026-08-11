# Чек-лист подачи в App Store

Сверено по живым гайдам Apple (June 2026). Корзины: ⚙️ App Store Connect ·
🛠️ в коде (сделано) · 🙋 нужно от тебя.

**Состояние на 2026-08-11** (сверено через ASC API, app id `6789296295`): версия **1.0
в `PREPARE_FOR_SUBMISSION`**, билды 1 и 2 залиты и `VALID`, метаданные + по 5 скриншотов
на всех 15 витринах, категории и рейтинг выставлены, Pricing = **Free** (price point
`0.0`), доступность **175/175 территорий** + новые территории автоматом, Review Notes
описывают актуальное поведение (дисклеймер-шаг, ввод по кормлениям, CloudKit).
Осталось — список в конце файла.

⚠️ **К версии прикреплён build 1 от 23.07**, а после него — 28 коммитов (CloudKit-синк,
тёмная тема, миграции, новое правило завершения ввода, бесплатная 1.0). Нужен свежий архив.

✅ **Номер версии сведён**: запись в ASC переименована в `1.0.0` (как в `project.yml`).

## 🛠️ В коде — сделано
- [x] Методики верифицированы, источники + оговорки в `FeedingProfile` и UI (1.4.1)
- [x] Единый медицинский дисклеймер `Disclaimer.medical` — шаг онбординга перед вводом данных ребёнка + Профиль → «О приложении» + описание магазина; зовёт к педиатру (1.4.1)
- [x] Секция «О приложении»: in-app ссылки на Privacy и Terms + поддержка + версия (5.1.1, 1.5)
- [x] Текст уведомления нейтральный — не называет аллерген на локскрине (4.5.4)
- [x] Приложение работает при отказе в уведомлениях (5.1.2(i))
- [x] Нет HealthKit, ATT-промта, usage-строк трекинга → позиция «Data Not Collected»
- [x] Метаданные «для родителей», нигде не подразумевается аудитория-дети (2.3.8 / 5.1.4)

## 🙋 От тебя — перед подачей
- [x] Задеплоить сайт: живёт на `pudding-for-children.vercel.app` (Vercel), `/`, `/privacy`,
      `/terms` отвечают 200; `AppLinks.swift` уже смотрит на боевые URL (свой домен — по желанию, позже)
- [ ] Подтвердить support-email `woodoo201818@gmail.com` (TODO висит в `AppLinks.swift`
      и в App Review Information)
- [x] Скриншоты реального UI «в деле» — по 5 штук на 15 витринах (`appstore_screenshots/`)
- [x] Аккаунт разработчика Apple (билды залиты)

## ⚙️ App Store Connect — при подаче
- [x] **Категория: Health & Fitness** (НЕ Medical) + вторичная Lifestyle
- [ ] **App Privacy → «Data Not Collected»**, типы данных не объявлять → **Save И Publish** до
      отправки билда (статус через API не читается — проверить глазами в вебе).
      ⚠️ С включённым CloudKit это трактовка: данные уезжают в **приватную базу
      самого пользователя**, доступа у нас нет, а Apple определяет «collect» через
      доступ разработчика. Перед сабмитом перечитать формулировку Apple.
- [x] **Privacy Policy URL** = `https://pudding-for-children.vercel.app/privacy` — проставлен
      во всех 15 локалях App Info
- [x] **Support URL** = `https://pudding-for-children.vercel.app` (проставлен во всех 15 локалях)
- [x] **Возрастной рейтинг 4+** (контент; в Kids Category НЕ вступаем)
- [x] Скриншоты показывают UI в использовании (2.3.3)
- [x] **Notes for Review** — залиты в ASC (текст — `docs/appstore/ASC-METADATA.md` §8):
      local-only, без аккаунта/аналитики/бэкенда, дисклеймер-гейт на месте

## 🚦 Что осталось до кнопки Submit
1. **CloudKit Console → Deploy Schema to Production** (иначе синк мёртв у реальных
   пользователей). Через ASC API не делается; либо консоль, либо `xcrun cktool` с
   management-токеном из той же консоли.
2. App Privacy → Save **и** Publish (только веб-UI: в ASC API таких эндпоинтов нет —
   проверены `appDataUsages`, `dataUsages`, `appPrivacyDetails`, все 404).
3. Подтвердить support-email (`woodoo201818@gmail.com` — TODO в `AppLinks.swift`,
   он же в App Review Information).
4. Решить по Content Rights: сейчас `DOES_NOT_USE_THIRD_PARTY_CONTENT`, при этом иконки —
   OpenMoji (CC BY-SA 4.0), то есть стороннее лицензированное творчество.
5. Submit for Review.

## 📦 Build 3 (11.08)
Собран и залит: архив Release → экспорт `app-store-connect` → `altool --validate-app`
(VERIFY SUCCEEDED) → `--upload-app`. Обработался в `VALID`, **прицеплен к версии 1.0.0**.
В бандле: `Apple Distribution`, `aps-environment = production`, iCloud-контейнер
`Production`, `PrivacyInfo.xcprivacy`, 14 `.lproj`, min iOS 17.0, шифрование — exempt.

⚠️ **Подпись distribution не поедет по ASC-ключу**: `-authenticationKey*` даёт
`Cloud signing permission error` (у ключа нет прав, в аккаунте только Development-
сертификат). Экспорт проходит через залогиненную учётку Xcode:
`xcodebuild -exportArchive -allowProvisioningUpdates` **без** ключей ASC —
подпись cloud-managed, в аккаунте новых сертификатов и профилей не появляется.

## ✅ Сделано через API 11.08
- Версия переименована `1.0` → `1.0.0` (под `MARKETING_VERSION`).
- Review Notes дополнены: фоновый режим `remote-notification` = только тихие пуши
  CloudKit; позиция по 5.1.3(ii) (приватная база пользователя, доступа у нас нет);
  «Data Not Collected» + PhotosPicker вместо доступа ко всей галерее.
- `ageRatingDeclaration.socialMedia = false` (оставалось незаполненным).
- Сверено и подтверждено: Pricing = Free, 175/175 территорий, Support/Privacy URL во всех
  15 локалях, 75/75 скриншотов `COMPLETE`, рейтинг 4+, категории Health & Fitness + Lifestyle.
- Политика с новым пунктом про срок хранения уже на проде (Vercel деплоит из GitHub).

## Будущее (вне текущей подачи)
- ~~CloudKit-синк~~ — включён (приватная база пользователя); политика и тексты витрины
  обновлены, App Privacy перепроверить перед сабмитом (см. выше)
- Pro/IAP (StoreKit) → 3.1.1 + 2.1(b)
