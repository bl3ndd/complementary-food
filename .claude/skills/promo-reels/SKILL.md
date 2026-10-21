---
name: promo-reels
description: Use when making short vertical promo videos for Pudding — TikTok / Reels / Shorts — "сделай тикток", "нужны рилсы", "make a reel", "промо видео", "до/после ролик". Fully generated, nothing recorded by hand — HTML/CSS animation rendered frame-by-frame with Playwright, ElevenLabs voice-over, a synthesized royalty-free lo-fi track, ffmpeg mux. Format is «До / После»: messy notes/chat/stickies → the clean Pudding diary.
---

# Pudding promo reels (TikTok / Reels / Shorts)

Everything is generated: no screen recording, no CapCut, no human voice. The user only taps Upload.
Pipeline: `marketing/reels/` (`render.py`, `template.html`, `music.py`, `clips.json`).
New clip = new entry in `clips.json`, then `python3 render.py NN --lang ru` from that folder.

## Format: «До / После» (chosen by the user — no quizzes)

One template, three "before" styles (`kind`):
- `notes` — an iOS-Notes-like card, lines with "??" and strike-throughs.
- `chat` — a two-parent chat where nobody remembers what the baby ate.
- `stickies` — sticky notes on the fridge, slightly rotated, jittering.

Scene order: hook (big question, 2 s) → **before** on a grey system background, items pop in one
by one, red "?" marks appear → **circular wipe** in the Pudding gradient → **after**: diary rows
(food icon tile · name · date · liking face, a «Сыпь» chip where there was a reaction), the
food counter ticks up, «PDF для педиатра» card with a check → outro (app icon, Pudding,
«Дневник прикорма», «Бесплатно в App Store», «ссылка в профиле»). ~20–25 s.

New clip ideas inside the same format: photo gallery chaos, "I'll remember" (empty note), a paper
notebook, a voice-memo list, grandma's call. Same template, new `lines`/`rows`.

## Content rules (hard)

- **Pure diary, no advice.** The app never tells parents what/when to feed, and neither do clips:
  no "when to introduce", no allergen guidance, no "how many days", no safety claims. Show what
  the parent *recorded* — foods, dates, liking, reactions as a fact.
- Don't promise features the app doesn't have (e.g. iCloud sync is per Apple ID, **not** sharing
  with a partner — don't say "both parents see it").
- Voice says «Пудинг» in Russian (ElevenLabs mispronounces "Pudding" in RU), on screen it's «Pudding».
- Food/liking icons are **OpenMoji (CC BY-SA 4.0)** — the outro keeps the small credit line.

## Strategy

- Same *idea*, different content each clip — never repost the same mp4 (fingerprinted/throttled).
- Post the same mp4 to TikTok, Reels and Shorts. App Store link in bio from day one.
- Render the first clip and send it to the user (SendUserFile) **before** batching the rest —
  voice/pace/music feedback comes first.

## Pipeline (`render.py`)

1. **Voice** → ElevenLabs (`eleven_multilingual_v2`, voice "Sarah" `EXAVITQu4vr4xnSDxMaL`,
   `ELEVEN_VOICE_ID` overrides). Key from `ELEVENLABS_API_KEY` env or gitignored
   `marketing/reels/.env`. Each line cached by sha1(voice|model|text) in `tmp/tts_cache/` —
   re-renders cost zero credits. No `say` fallback: the user rejected macOS voices.
2. **Timeline** from *measured* VO durations (`ffprobe`), so scenes never cut a sentence.
3. **Frames**: Playwright Chromium 1080×1920, `seek(t)` + `page.screenshot(jpeg)` at 30 fps.
   **No CSS animations** — every style is a pure function of `t` (`prog`, `easeOut`, `spring`),
   so any frame can be scrubbed. Screenshot occasionally throws → retry 3×.
4. **Music**: `music.py` synthesizes a lo-fi loop (numpy/scipy). Zero copyright risk.
5. **Mix**: per-line `adelay` → `amix` → music 0.32 with `sidechaincompress` ducking → `alimiter`
   (≈ -16 LUFS).
6. **Mux**: libx264 crf 18, yuv420p, AAC 192k, `+faststart`.

Outputs `out/<num>_<slug>_<lang>.mp4`. `tmp/`, `out/`, `.env` are gitignored.

## Template rules (`template.html`)

- Tokens = the app's «Пудинг» palette (`Palette.pudding` + `Theme`). Font **SF Pro Rounded**
  (installed on the Mac) for Pudding parts; plain system font for the "before" mess.
- **No shadows, no neon, no blurred blobs** — the app's "human, not AI" look: hairline borders,
  one accent, air.
- Icons are loaded straight from `Resources/Media.xcassets/*.imageset/icon.png` (food_*, like_*,
  AppIcon) — nothing duplicated.
- Safe zone: ~80–110 px side margins, nothing important in the bottom ~350 px or the right
  ~180 px between y≈1100–1700 (platform buttons).
- Russian plural for the counter is computed in JS from `countForms`.

## Verify before sending

- Quick look without spending credits: call `render.page_data` + `build_timeline` with fake VO
  durations and screenshot key moments (hook / before / wipe / after / outro), `hstack` them.
- After a real render: `ffprobe` → 1080×1920, h264, 30/1; `ebur128` → I ≈ -14…-18 LUFS.
