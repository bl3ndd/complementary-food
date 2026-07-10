# Скриншоты App Store

- `raw/<ru|en-US>/` — сырые скрины 1320×2868 (iPhone 6.9"), снимаются
  `ScreenshotUITests` на симуляторе iPhone 17 Pro Max:
  `TEST_RUNNER_SNAPSHOT=1 xcodebuild test-without-building -scheme Prikorm \
    -destination "platform=iOS Simulator,id=<SIM>" -only-testing:PrikormUITests/ScreenshotUITests …`
  (сид `-uitest-seed=showcase`, статус-бар чистится `simctl status_bar override`).
- `final/<ru|en-US>/` — маркетинговые рамки (фон-градиент бренда + заголовок +
  телефон в рамке), собираются `python3 generate.py` (нужен Chrome). Эти файлы
  и заливаются в ASC.
- Заливка — напрямую через ASC API (сет APP_IPHONE_67 принимает 1320×2868),
  скрипт в скретчпаде сессии; НЕ fastlane deliver (дублирует).
- Правка заголовков: список SCREENS в `generate.py` → перегенерить → перезалить.
