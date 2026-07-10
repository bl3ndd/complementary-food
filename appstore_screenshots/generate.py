#!/usr/bin/env python3
"""
App Store marketing-screenshot generator — HTML/CSS + headless Chrome.

Copy this into the project (e.g. appstore_screenshots/generate.py) and ADAPT:
  1. the mesh-gradient RGBs in TEMPLATE  -> the app's brand colors
  2. the headline color (--head)         -> a dark brand tone
  3. the SCREENS list                    -> your screens + RU/EN copy
  4. sizes (1320x2868 = iPhone 6.9")     -> only change for other device sizes

Layout:
  raw/<lang>/NN_Screen.png    -> source (plain app screenshot, 1320x2868)
  final/<lang>/NN_Screen.png  -> output (background + headline + device frame)

Run:  python3 generate.py      Requires: Google Chrome, Python 3 (no pip deps).
"""
import base64, os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
FINAL = os.path.join(HERE, "final")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# (file, ru_head, ru_sub, en_head, en_sub). <br> controls line breaks.
# Benefit-driven copy, NO medical claims (App Review safe).
SCREENS = [
    ("01_Dashboard.png",
     "Дневник прикорма<br>без паники",  "Записи, коллекция и аллергены",
     "First foods,<br>zero panic",      "Diary, collection and allergens"),
    ("02_FoodCard.png",
     "Видно, когда<br>продукт введён",  "Окно наблюдения: день 2 из 3",
     "Every introduction<br>at a glance", "Observation window: day 2 of 3"),
    ("03_Calendar.png",
     "Вся история —<br>одной лентой",   "Фильтры, планы и поиск",
     "Your whole story,<br>one feed",   "Filters, plans and search"),
    ("04_Allergens.png",
     "Аллергены<br>под контролем",      "Pudding напомнит повторить вовремя",
     "Allergens,<br>on schedule",       "Gentle reminders to repeat in time"),
    ("05_Recap.png",
     "Делись успехами<br>малыша",       "Рекап месяца — одной карточкой",
     "Share the<br>little wins",        "A monthly recap in one card"),
]

# --- ADAPT the gradient stops + head color to the app's brand palette ---
TEMPLATE = """<!doctype html><html><head><meta charset="utf-8"><style>
* { margin:0; padding:0; box-sizing:border-box; }
html,body { width:1320px; height:2868px; overflow:hidden; }
body {
  font-family:'SF Pro Rounded','SF Pro Display',-apple-system,sans-serif;
  background-color:#FFF6EE;
  background-image:
    radial-gradient(at 14% 14%, rgba(255,199,71,0.42) 0px, transparent 46%),
    radial-gradient(at 88% 12%, rgba(253,125,79,0.34) 0px, transparent 46%),
    radial-gradient(at 84% 88%, rgba(168,140,237,0.30) 0px, transparent 50%),
    radial-gradient(at 10% 84%, rgba(92,204,153,0.34) 0px, transparent 48%);
  display:flex; flex-direction:column; align-items:center;
}
.head { margin-top:160px; text-align:center; padding:0 80px; }
.head h1 { font-size:104px; font-weight:700; line-height:1.06; letter-spacing:-2px; color:#57331F; }
.head p  { font-size:46px; font-weight:500; margin-top:34px; color:rgba(44,44,46,0.55); letter-spacing:-0.5px; }
.phone {
  margin-top:90px; width:1000px; border-radius:96px; background:#111113; padding:15px;
  box-shadow: 0 60px 110px rgba(87,51,31,0.30), 0 18px 40px rgba(87,51,31,0.16);
}
.phone img { width:100%; display:block; border-radius:82px; }
</style></head><body>
  <div class="head"><h1>__HEAD__</h1><p>__SUB__</p></div>
  <div class="phone"><img src="__IMG__"></div>
</body></html>"""


def b64(path):
    with open(path, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode()


def render(lang, fname, head, sub):
    src = os.path.join(RAW, lang, fname)
    if not os.path.exists(src):
        print("  SKIP (no raw):", src); return
    outdir = os.path.join(FINAL, lang); os.makedirs(outdir, exist_ok=True)
    html = (TEMPLATE.replace("__IMG__", b64(src))
                    .replace("__HEAD__", head).replace("__SUB__", sub))
    hp = os.path.join(outdir, fname.replace(".png", ".html"))
    with open(hp, "w") as f:
        f.write(html)
    out = os.path.join(outdir, fname)
    subprocess.run([CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
                    "--force-device-scale-factor=1", "--virtual-time-budget=4000",
                    f"--screenshot={out}", "--window-size=1320,2868", f"file://{hp}"],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.remove(hp)
    print("  ok", lang, "->", os.path.relpath(out, HERE))


def main():
    for fname, ruh, rus, enh, ens in SCREENS:
        render("ru", fname, ruh, rus)
        render("en-US", fname, enh, ens)
    print("done. finals in", os.path.relpath(FINAL, HERE))


if __name__ == "__main__":
    main()
