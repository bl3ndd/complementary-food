# Тест-кейсы Pudding

Карта проверок логики и compliance. Колонка «Тип»: **unit** — изолированная чистая
логика; **e2e** — сквозной сценарий через реальный in-memory `ModelContainer` +
настоящие сервисы и каталог (`ScenarioTests`). UI/визуал маскота и вёрстка —
валидируются self-launch (UI-тест-таргета в проекте нет).

## A. Введение продукта (стейт-машина, SPEC §4.4)

| ID | Сценарий | Ожидание | Тип | Где |
|----|----------|----------|-----|-----|
| A1 | Старт ввода нового продукта | state → `introducing`, есть `introStartedAt`, запись `.intro` | e2e | ScenarioTests |
| A2 | Завершить ввод | state → `introduced`, есть `completedAt` | e2e | ScenarioTests |
| A3 | Реакция при вводе | state → `paused` | e2e | ScenarioTests |
| A4 | Реакция на уже введённый | state → `allergy` | e2e | ScenarioTests |
| A5 | Реакция `.none` | state не меняется | unit | FeedingServiceTests |
| A6 | Реинтродукция после аллергии | state → `introducing`, `completedAt` сброшен | unit | FeedingServiceTests |

## B. Окно наблюдения

| ID | Сценарий | Ожидание | Тип | Где |
|----|----------|----------|-----|-----|
| B1 | День старта | `observationDay == 1` | unit | FeedingServiceTests |
| B2 | Внутри окна | `isObservationComplete == false` | unit | FeedingServiceTests |
| B3 | После окна | `isObservationComplete == true` | unit | FeedingServiceTests |
| B4 | e2e: ввёл → ждать окно → завершить | до окна завершать рано, после — `introduced` | e2e | ScenarioTests |

## C. Аллергены / поддержка толерантности (SPEC §4.3)

| ID | Сценарий | Ожидание | Тип | Где |
|----|----------|----------|-----|-----|
| C1 | Введённый давно не давали | группа в `dueForDashboard()` | e2e | ScenarioTests |
| C2 | Свежий приём | группа НЕ due | e2e | ScenarioTests |
| C3 | Не введён / аллергия — пропуск напоминаний | заявок нет | unit | NotificationManagerTests |
| C4 | Одна заявка на каждую due-группу | корректные идентификаторы | unit | NotificationManagerTests |

## D. Compliance (App Review)

| ID | Сценарий | Ожидание | Тип | Где |
|----|----------|----------|-----|-----|
| D1 | У каждого пресета есть источник + https URL + оговорка | непустые, валидный URL | unit | FeedingProfileTests |
| D2 | Дисклеймер зовёт к педиатру (1.4.1) | содержит «педиатр» | unit | DisclaimerTests |
| D3 | Тело уведомления не палит аллерген (4.5.4) | body не содержит названий групп | unit | NotificationManagerTests |
| D4 | Цифры пресетов в разумных границах | старт 4–7, окно 1–14, частота 1–7 | unit | FeedingProfileTests |

## E. Сквозные пользовательские сценарии (e2e)

| ID | Путь | Ожидание |
|----|------|----------|
| E1 | Новый овощ: старт → завершить после окна | проходит весь путь до `introduced` |
| E2 | Аллерген с реакцией при вводе | уходит в `paused`, не в `introduced` |
| E3 | Введённый аллерген без поддержки → напоминание | группа due, строится заявка уведомления |
| E4 | Аллергия на введённый → реинтродукция врачом | `allergy` → `introducing` |

> Не покрыто автотестами (по дизайну): отрисовка/анимация маскота, переходы экранов,
> разрешение на уведомления (системный промпт вне сема) — проверяется self-launch.
