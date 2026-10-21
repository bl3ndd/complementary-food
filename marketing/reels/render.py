#!/usr/bin/env python3
"""Pudding «До / После» — вертикальные промо-ролики (1080x1920, 30 fps, H.264 + AAC).

  python3 render.py                 # все ролики из clips.json, английский
  python3 render.py 02              # только ролик №02 (или по slug)
  python3 render.py --lang ru       # русские строки

Конвейер: озвучка ElevenLabs по фразам (кэш) -> таймлайн из реальной длины фраз ->
скриншоты template.html покадрово через Playwright -> lo-fi из music.py -> ffmpeg.
Ключ — ELEVENLABS_API_KEY в окружении или в .env рядом (gitignored).
"""
import json, os, subprocess, sys, shutil, hashlib, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent.parent
ASSETS = REPO / "Resources" / "Media.xcassets"
OUT = ROOT / "out"
TMP = ROOT / "tmp"
CACHE = TMP / "tts_cache"
FPS = 30
W, H = 1080, 1920

ELEVEN_VOICE = "EXAVITQu4vr4xnSDxMaL"     # «Sarah» — спокойный тёплый голос, multilingual
ELEVEN_MODEL = "eleven_multilingual_v2"

STRINGS = {
    "en": {
        "beforeTag": "Before", "afterTag": "With Pudding",
        "pdfTitle": "PDF for your pediatrician", "pdfSub": "Every feeding, reaction and date",
        "countForms": {"one": "food", "other": "foods"},
        "outroName": "Pudding", "outroTag": "First foods diary",
        "outroCta": "Free on the App Store", "outroSub": "link in bio",
        "vo_outro": "Pudding. A first foods diary. Free on the App Store, link in bio.",
        "like": {"liked": "Loved it", "neutral": "OK", "disliked": "Meh"},
    },
    "ru": {
        "beforeTag": "До", "afterTag": "С Pudding",
        "pdfTitle": "PDF для педиатра", "pdfSub": "Все кормления, реакции и даты",
        "countForms": {"one": "продукт", "few": "продукта", "many": "продуктов"},
        "outroName": "Pudding", "outroTag": "Дневник прикорма",
        "outroCta": "Бесплатно в App Store", "outroSub": "ссылка в профиле",
        "vo_outro": "Пудинг. Дневник прикорма. Бесплатно в App Store, ссылка в профиле.",
        "like": {"liked": "Класс", "neutral": "Норм", "disliked": "Не оч"},
    },
}


def sh(*args, **kw):
    return subprocess.run(args, check=True, capture_output=True, text=True, **kw)


def duration(path):
    return float(sh("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)).stdout)


def eleven_key():
    key = os.environ.get("ELEVENLABS_API_KEY")
    env = ROOT / ".env"
    if not key and env.exists():
        for line in env.read_text().splitlines():
            if line.startswith("ELEVENLABS_API_KEY="):
                key = line.split("=", 1)[1].strip().strip('"')
    if not key:
        sys.exit("Нет ELEVENLABS_API_KEY (окружение или marketing/reels/.env). `say` не используем — звучит плохо.")
    return key


def tts(text, path):
    """ElevenLabs, кэш по (голос, модель, текст): перерендер не тратит кредиты."""
    voice = os.environ.get("ELEVEN_VOICE_ID", ELEVEN_VOICE)
    CACHE.mkdir(parents=True, exist_ok=True)
    h = hashlib.sha1(f"{voice}|{ELEVEN_MODEL}|{text}".encode()).hexdigest()[:16]
    cached = CACHE / f"{h}.mp3"
    if not cached.exists():
        body = json.dumps({
            "text": text, "model_id": ELEVEN_MODEL,
            "voice_settings": {"stability": 0.45, "similarity_boost": 0.8, "style": 0.25, "use_speaker_boost": True},
        }).encode()
        req = urllib.request.Request(
            f"https://api.elevenlabs.io/v1/text-to-speech/{voice}?output_format=mp3_44100_128",
            data=body, headers={"xi-api-key": eleven_key(), "Content-Type": "application/json", "Accept": "audio/mpeg"})
        with urllib.request.urlopen(req, timeout=120) as r:
            cached.write_bytes(r.read())
    shutil.copy(cached, path)
    return duration(path)


def build_timeline(n_chaos, n_rows, vo):
    """Начала сцен (сек) и старты фраз — из реальной длины озвучки."""
    s = {"hook": 0.0}
    s["before"] = max(2.0, vo["hook"] + 0.5)
    s["wipe"] = s["before"] + max(1.4 + n_chaos * 0.75, vo["before"] + 1.0)
    s["after"] = s["wipe"] + 0.6
    s["pdf"] = s["after"] + max(0.6 + n_rows * 0.55 + 0.6, vo["after"] * 0.6)
    s["outro"] = max(s["pdf"] + 2.4, s["after"] + vo["after"] + 1.0)
    s["end"] = s["outro"] + max(3.6, vo["outro"] + 1.2)
    at = {"hook": 0.15, "before": s["before"] + 0.3, "after": s["after"] + 0.3, "outro": s["outro"] + 0.3}
    return s, at


def mix_audio(vo_files, at, total, out_wav, seed):
    music = TMP / "music.wav"
    sh(sys.executable, str(ROOT / "music.py"), f"{total:.2f}", str(music), str(seed))
    inputs, chains, labels = [], [], []
    for i, (name, path) in enumerate(vo_files.items()):
        inputs += ["-i", str(path)]
        ms = int(at[name] * 1000)
        chains.append(f"[{i}]aformat=sample_rates=44100:channel_layouts=mono,adelay={ms}|{ms},apad=whole_dur={total:.2f}[v{i}]")
        labels.append(f"[v{i}]")
    n = len(vo_files)
    inputs += ["-i", str(music)]
    chains.append("".join(labels) + f"amix=inputs={n}:normalize=0,volume=1.0[voice]")
    chains.append(f"[{n}]aformat=sample_rates=44100:channel_layouts=mono,volume=0.32[m]")
    chains.append("[voice]asplit[vo1][vo2]")
    chains.append("[m][vo1]sidechaincompress=threshold=0.03:ratio=5:attack=40:release=500:makeup=1[md]")
    chains.append(f"[md][vo2]amix=inputs=2:normalize=0,alimiter=limit=0.95,atrim=0:{total:.2f}[out]")
    sh("ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex", ";".join(chains), "-map", "[out]", "-ar", "44100", str(out_wav))


def render_frames(data, scenes, total, frames_dir):
    from playwright.sync_api import sync_playwright
    frames_dir.mkdir(parents=True, exist_ok=True)
    n = int(total * FPS)
    with sync_playwright() as p:
        b = p.chromium.launch()
        page = b.new_page(viewport={"width": W, "height": H}, device_scale_factor=1)
        page.goto((ROOT / "template.html").as_uri())
        page.wait_for_load_state("networkidle")
        page.evaluate("([d, s]) => window.setup(d, s)", [data, scenes])
        page.wait_for_timeout(300)   # иконки догружаются
        for i in range(n):
            page.evaluate("t => window.seek(t)", i / FPS)
            for attempt in range(3):   # headless Chromium изредка роняет захват — просто повторяем
                try:
                    page.screenshot(path=str(frames_dir / f"{i:05d}.jpg"), type="jpeg", quality=92)
                    break
                except Exception:
                    if attempt == 2:
                        raise
                    page.wait_for_timeout(200)
            if i % 150 == 0:
                print(f"  frame {i}/{n}", flush=True)
        b.close()
    return n


def asset(name):
    return (ASSETS / f"{name}.imageset" / "icon.png").as_uri()


def page_data(clip, lang):
    S, C = STRINGS[lang], clip[lang]
    rows = [{
        "icon": asset(f"food_{r['food']}"), "cat": r["cat"], "name": r[lang],
        "meta": f"{r[f'date_{lang}']} · {S['like'][r['like']]}", "chip": r.get(f"chip_{lang}"),
        "like": asset(f"like_{r['like']}"),
    } for r in clip["rows"]]
    return {
        "lang": lang, "kind": clip["kind"], "hook": C["hook"],
        "beforeTag": S["beforeTag"], "afterTag": S["afterTag"],
        "notesFolder": C.get("notesFolder", ""), "notesTitle": C.get("notesTitle", ""), "lines": C["lines"],
        "month": C["month"], "rows": rows,
        "countFrom": clip["countFrom"], "countTo": clip["countFrom"] + len(rows), "countForms": S["countForms"],
        "pdfTitle": S["pdfTitle"], "pdfSub": S["pdfSub"],
        "appIcon": (ASSETS / "AppIcon.appiconset" / "icon.png").as_uri(),
        "outroName": S["outroName"], "outroTag": S["outroTag"], "outroCta": S["outroCta"], "outroSub": S["outroSub"],
    }


def render_clip(clip, lang):
    S, C = STRINGS[lang], clip[lang]
    slug = f"{clip['num']:02d}_{clip['slug']}_{lang}"
    work = TMP / slug
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)
    print(f"== {slug}")

    lines = {"hook": C["vo_hook"], "before": C["vo_before"], "after": C["vo_after"], "outro": S["vo_outro"]}
    vo_files, vo = {}, {}
    for name, text in lines.items():
        path = work / f"vo_{name}.mp3"
        vo[name], vo_files[name] = tts(text, path), path

    scenes, at = build_timeline(len(C["lines"]), len(clip["rows"]), vo)
    total = scenes["end"]
    print(f"  {total:.1f}s  " + " ".join(f"{k}={v:.1f}" for k, v in scenes.items()))

    audio = work / "audio.wav"
    mix_audio(vo_files, at, total, audio, seed=clip["num"])

    frames = work / "frames"
    render_frames(page_data(clip, lang), scenes, total, frames)

    OUT.mkdir(exist_ok=True)
    out = OUT / f"{slug}.mp4"
    sh("ffmpeg", "-v", "error", "-y", "-framerate", str(FPS), "-i", str(frames / "%05d.jpg"), "-i", str(audio),
       "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-r", str(FPS),
       "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-shortest", str(out))
    shutil.rmtree(frames)
    print(f"  -> {out.relative_to(ROOT)}  ({duration(out):.1f}s)")
    return out


if __name__ == "__main__":
    args = sys.argv[1:]
    lang = "en"
    if "--lang" in args:
        i = args.index("--lang"); lang = args[i + 1]; del args[i:i + 2]
    clips = json.loads((ROOT / "clips.json").read_text())
    if args:
        clips = [c for c in clips if f"{c['num']:02d}" in args or c["slug"] in args]
    for c in clips:
        render_clip(c, lang)
