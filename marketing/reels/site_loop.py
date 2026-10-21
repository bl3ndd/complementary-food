#!/usr/bin/env python3
"""Короткая немая петля «До / После» для лендинга (≈6 с, без хука, голоса и аутро).

  python3 site_loop.py            # en + ru -> site/assets/video/loop-<lang>.mp4 + постер

Та же template.html, что у рилсов, — только свой таймлайн: заметки сыплются,
круг гаммы, строки дневника и карточка PDF. Видео немое: на сайте оно играет
само (autoplay требует muted), смысл должен читаться без звука.
"""
import json, shutil, subprocess, sys
from pathlib import Path

import render

ROOT = Path(__file__).resolve().parent
SITE_VIDEO = render.REPO / "site" / "assets" / "video"
CLIP = 1          # заметки — самый узнаваемый «до»
W_OUT = 600       # в герое ~300 css px → хватает на ретину
# Низ кадра рилса пустой (там кнопки TikTok/Reels) — на сайте режем до 3:4.
CROP = "crop=1080:1440:0:0"

SCENES = {"hook": 0.0, "before": 0.0, "wipe": 2.5, "after": 3.1, "pdf": 5.0,
          "outro": 99.0, "end": 6.4}


def main(langs):
    clip = next(c for c in json.loads((ROOT / "clips.json").read_text()) if c["num"] == CLIP)
    SITE_VIDEO.mkdir(parents=True, exist_ok=True)
    for lang in langs:
        data = render.page_data(clip, lang)
        data["hook"] = ""                       # хук — для ленты соцсетей, на сайте лишний
        frames = render.TMP / f"site_{lang}" / "frames"
        if frames.parent.exists():
            shutil.rmtree(frames.parent)
        render.render_frames(data, SCENES, SCENES["end"], frames)
        out = SITE_VIDEO / f"loop-{lang}.mp4"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", str(render.FPS),
                        "-i", str(frames / "%05d.jpg"), "-vf", f"{CROP},scale={W_OUT}:-2:flags=lanczos",
                        "-c:v", "libx264", "-preset", "slow", "-crf", "27", "-pix_fmt", "yuv420p",
                        "-an", "-movflags", "+faststart", str(out)], check=True)
        # Постер — кадр «после»: его видно до загрузки и при «меньше движения».
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(frames / f"{int(5.9 * render.FPS):05d}.jpg"),
                        "-vf", f"{CROP},scale={W_OUT}:-2:flags=lanczos", "-q:v", "4",
                        str(SITE_VIDEO / f"loop-{lang}.jpg")], check=True)
        shutil.rmtree(frames.parent)
        print(f"  -> {out.relative_to(render.REPO)}  {out.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main(sys.argv[1:] or ["en", "ru"])
