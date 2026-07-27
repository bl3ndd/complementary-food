# Чек-лист подачи в App Store

Сверено по живым гайдам Apple (June 2026). Корзины: ⚙️ App Store Connect ·
🛠️ в коде (сделано) · 🙋 нужно от тебя.

**Состояние на 2026-07-27** (сверено через ASC API, app id `6789296295`): версия **1.0
в `PREPARE_FOR_SUBMISSION`**, билды 1 и 2 залиты и `VALID`, метаданные + по 5 скриншотов
на всех 15 витринах, категории и рейтинг выставлены. Осталось — список в конце файла.

## 🛠️ В коде — сделано
- [x] Методики верифицированы, источники + оговорки в `FeedingProfile` и UI (1.4.1)
- [x] Единый медицинский дисклеймер `Disclaimer.medical` (онбординг + профиль), зовёт к педиатру (1.4.1)
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
      отправки билда (статус через API не читается — проверить глазами в вебе)
- [x] **Privacy Policy URL** = `https://pudding-for-children.vercel.app/privacy` — проставлен
      во всех 15 локалях App Info
- [x] **Support URL** = `https://pudding-for-children.vercel.app` (проставлен во всех 15 локалях)
- [x] **Возрастной рейтинг 4+** (контент; в Kids Category НЕ вступаем)
- [x] Скриншоты показывают UI в использовании (2.3.3)
- [x] **Notes for Review** — залиты в ASC (текст — `docs/appstore/ASC-METADATA.md` §8):
      local-only, без аккаунта/аналитики/бэкенда, дисклеймер-гейт на месте

## 🚦 Что осталось до кнопки Submit
1. ~~`MARKETING_VERSION` → `1.0.0`~~ — сделано в `project.yml`. Осталось **собрать архив
   и залить свежий билд** (к версии прикреплён build 1 от 23.07, после него — правки ядра,
   тёмная тема, миграции).
2. ~~Review Notes~~ — залиты.
3. App Privacy → Save **и** Publish (только через веб-UI).
4. ~~Privacy Policy URL по локалям~~ — проставлен везде.
5. Проверить Pricing & Availability (free + территории).
6. Подтвердить support-email.
7. Submit for Review.

## Будущее (вне текущей подачи)
- CloudKit-синк → App Privacy станет «collected», обновить политику + пере-чек 5.1.3(ii)
- Pro/IAP (StoreKit) → 3.1.1 + 2.1(b)
