#!/usr/bin/env python3
"""
App Store marketing-screenshot generator — HTML/CSS + headless Chrome.

Data-driven по 14 языкам: сырые скрины лежат в raw/<uiLang>/NN_Screen.png,
заголовки — в headlines.json ({uiLang: [{head,sub}×5]}). Выход — final/<ascLocale>/*.png
(готово к заливке в ASC). ru/en_head/en_sub-источник в headlines.json тоже присутствует.

Run:  python3 generate.py      Requires: Google Chrome, Python 3 (no pip deps).
"""
import base64, json, os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
FINAL = os.path.join(HERE, "final")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

SCREEN_ORDER = ["01_Dashboard", "02_FoodCard", "03_Calendar", "04_Allergens", "05_Recap"]

# uiLang каталога скринов → ASC-локаль(и) витрины
UI_TO_ASC = {
    "ru": ["ru"], "en": ["en-US"], "de": ["de-DE"], "fr": ["fr-FR"],
    "es": ["es-ES", "es-MX"], "it": ["it"], "pt-BR": ["pt-BR"], "pl": ["pl"],
    "tr": ["tr"], "uk": ["uk"], "nl": ["nl-NL"], "ja": ["ja"], "ko": ["ko"],
    "zh-Hans": ["zh-Hans"],
}

TEMPLATE = """<!doctype html><html><head><meta charset="utf-8"><style>
* { margin:0; padding:0; box-sizing:border-box; }
html,body { width:1320px; height:2868px; overflow:hidden; }
body {
  font-family:'SF Pro Rounded','SF Pro Display','Hiragino Sans','Apple SD Gothic Neo','PingFang SC',-apple-system,sans-serif;
  background-color:#FFF6EE;
  background-image:
    radial-gradient(at 14% 14%, rgba(255,199,71,0.42) 0px, transparent 46%),
    radial-gradient(at 88% 12%, rgba(253,125,79,0.34) 0px, transparent 46%),
    radial-gradient(at 84% 88%, rgba(168,140,237,0.30) 0px, transparent 50%),
    radial-gradient(at 10% 84%, rgba(92,204,153,0.34) 0px, transparent 48%);
  display:flex; flex-direction:column; align-items:center;
}
.head { margin-top:160px; text-align:center; padding:0 80px; }
.head h1 { font-size:100px; font-weight:700; line-height:1.06; letter-spacing:-2px; color:#57331F; }
.head p  { font-size:44px; font-weight:500; margin-top:34px; color:rgba(44,44,46,0.55); letter-spacing:-0.5px; }
.phone {
  margin-top:88px; width:1000px; border-radius:96px; background:#111113; padding:15px;
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


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\n", "<br>")


def render(ui_lang, asc_locale, screen, head, sub):
    src = os.path.join(RAW, ui_lang, screen + ".png")
    if not os.path.exists(src):
        print("  SKIP (no raw):", src); return False
    outdir = os.path.join(FINAL, asc_locale); os.makedirs(outdir, exist_ok=True)
    html = (TEMPLATE.replace("__IMG__", b64(src))
                    .replace("__HEAD__", esc(head)).replace("__SUB__", esc(sub)))
    hp = os.path.join(outdir, screen + ".html")
    with open(hp, "w") as f:
        f.write(html)
    out = os.path.join(outdir, screen + ".png")
    subprocess.run([CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
                    "--force-device-scale-factor=1", "--virtual-time-budget=4000",
                    f"--screenshot={out}", "--window-size=1320,2868", f"file://{hp}"],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.remove(hp)
    return True


def main():
    heads = json.load(open(os.path.join(HERE, "headlines.json")))
    total = 0
    for ui_lang, screens in heads.items():
        for asc_locale in UI_TO_ASC.get(ui_lang, []):
            for i, screen in enumerate(SCREEN_ORDER):
                if i < len(screens) and render(ui_lang, asc_locale, screen,
                                               screens[i]["head"], screens[i]["sub"]):
                    total += 1
            print(f"  {ui_lang} -> {asc_locale}: готово")
    print(f"done. {total} финальных кадров в {os.path.relpath(FINAL, HERE)}")


if __name__ == "__main__":
    main()
