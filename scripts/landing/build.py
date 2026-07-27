#!/usr/bin/env python3
"""Генератор лендинга Pudding на 14 языков.

Тексты живут в `scripts/landing/i18n/<lang>.json`, разметка — в этом файле.
Запуск: `python3 scripts/landing/build.py` (из корня репозитория).
Пишет `site/index.html` (ru) и `site/<lang>/index.html` для остальных.

Правило: **site/*.html не править руками** — только JSON + этот шаблон,
иначе следующая генерация затрёт правки.
"""
from __future__ import annotations

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
I18N = pathlib.Path(__file__).resolve().parent / "i18n"
SITE = ROOT / "site"
BASE = "https://pudding-for-children.vercel.app"

# Порядок = порядок в переключателе языков. Первый — источник (ru, лежит в корне).
LANGS = ["ru", "en", "de", "es", "fr", "it", "nl", "pl", "pt-BR", "tr", "uk", "ja", "ko", "zh-Hans"]


def esc(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


def load(lang: str) -> dict:
    return json.loads((I18N / f"{lang}.json").read_text(encoding="utf-8"))


def page_url(d: dict) -> str:
    return BASE + d["path"]


def hreflangs(all_d: dict, cur: dict) -> str:
    out = [f'  <link rel="canonical" href="{page_url(cur)}">']
    for lang in LANGS:
        out.append(f'  <link rel="alternate" hreflang="{lang}" href="{page_url(all_d[lang])}">')
    out.append(f'  <link rel="alternate" hreflang="x-default" href="{page_url(all_d["en"])}">')
    return "\n".join(out)


def lang_picker(all_d: dict, cur: dict) -> str:
    """Дропдаун на <details> — без JS, чтобы не расширять CSP."""
    items = []
    for lang in LANGS:
        d = all_d[lang]
        active = ' class="active"' if lang == cur["lang"] else ""
        items.append(f'<a{active} href="{d["path"]}" hreflang="{lang}" lang="{lang}">{esc(d["native"])}</a>')
    return (
        '<details class="langpick">\n'
        f'          <summary aria-label="{esc(cur["lang_label"])}"><span class="globe">🌐</span>{esc(cur["native_short"])}</summary>\n'
        f'          <div class="langmenu">{"".join(items)}</div>\n'
        "        </details>"
    )


def render(all_d: dict, lang: str) -> str:
    d = all_d[lang]
    url = page_url(d)
    shots = d["path"].strip("/") or "ru"  # каталог скринов: ru лежит в /assets/screens/ru
    shots = d.get("shots_dir", shots)
    alts = [f'{BASE}/assets/screens/{shots}/0{i}-{n}.jpg' for i, n in
            enumerate(["dashboard", "foodcard", "calendar", "allergens", "recap"], start=1)]
    og_alt = "\n".join(
        f'  <meta property="og:locale:alternate" content="{all_d[l]["og_locale"]}">'
        for l in LANGS if l != lang)

    steps = "\n".join(
        f'        <div class="step"><div class="num">{i}</div><h3>{esc(s["h"])}</h3><p>{esc(s["p"])}</p></div>'
        for i, s in enumerate(d["steps"], start=1))
    tiles = ["veg", "obs", "aller", "cal"]
    imgs = ["vegetable", "fruit", "allergen", "egg"]
    cards = "\n".join(
        f'        <div class="card"><div class="tile {tiles[i]}"><img src="/assets/food/{imgs[i]}.png" '
        f'alt="{esc(c["alt"])}"></div><h3>{esc(c["h"])}</h3><p>{esc(c["p"])}</p></div>'
        for i, c in enumerate(d["cards"]))
    gallery = "\n".join(
        f'        <figure><div class="phone"><img src="/assets/screens/{shots}/0{i+1}-'
        f'{["dashboard","foodcard","calendar","allergens","recap"][i]}.jpg" alt="{esc(s["alt"])}" '
        f'width="1080" height="2346" loading="lazy"></div><figcaption>{esc(s["cap"])}</figcaption></figure>'
        for i, s in enumerate(d["shots"]))
    badges = "\n".join(
        f'            <span class="badge"><span class="ico">{ico}</span> {esc(b)}</span>'
        for ico, b in zip(["📱", "🔒", "🧾"], d["badges"]))
    pills = "\n".join(f'          <span class="pill">{ico} {esc(p)}</span>'
                      for ico, p in zip(["🔒", "🚫", "📵", "📱"], d["pills"]))
    faq = "\n".join(
        f'        <details><summary>{esc(q["q"])}</summary><p>{esc(q["a"])}</p></details>'
        for q in d["faq"])
    faq_ld = ",\n          ".join(
        json.dumps({"@type": "Question", "name": q["q"],
                    "acceptedAnswer": {"@type": "Answer", "text": q["a"]}}, ensure_ascii=False)
        for q in d["faq"])
    legal = "/en" if d.get("legal") == "en" else d["path"].rstrip("/")

    return f"""<!DOCTYPE html>
<html lang="{d['lang']}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{esc(d['title'])}</title>
  <meta name="description" content="{esc(d['meta_desc'])}">
  <meta name="keywords" content="{esc(d['keywords'])}">
  <meta name="robots" content="index, follow">
{hreflangs(all_d, d)}
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="Pudding">
  <meta property="og:locale" content="{d['og_locale']}">
{og_alt}
  <meta property="og:url" content="{url}">
  <meta property="og:title" content="{esc(d['og_title'])}">
  <meta property="og:description" content="{esc(d['og_desc'])}">
  <meta property="og:image" content="{BASE}/assets/og.png">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="{esc(d['og_title'])}">
  <meta name="twitter:description" content="{esc(d['tw_desc'])}">
  <meta name="twitter:image" content="{BASE}/assets/og.png">
  <link rel="icon" href="/assets/pudding.svg" type="image/svg+xml">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Nunito:wght@400;700;800;900&display=swap{d.get('font_subset','')}" rel="stylesheet">
  <link rel="stylesheet" href="/styles.css">
</head>
<body>
  <header class="site">
    <div class="wrap nav">
      <a class="brand" href="{d['path']}"><img src="/assets/pudding.svg" alt="Pudding">Pudding</a>
      <div class="nav-right">
        <a href="#features">{esc(d['nav']['features'])}</a>
        <a href="#screens">{esc(d['nav']['screens'])}</a>
        <a href="#privacy">{esc(d['nav']['privacy'])}</a>
        {lang_picker(all_d, d)}
      </div>
    </div>
  </header>

  <main>
    <section class="hero wrap">
      <div class="hero-grid">
        <div class="hero-copy">
          <img class="mascot" src="/assets/pudding.svg" alt="{esc(d['alt_mascot'])}">
          <h1>{esc(d['h1'])}</h1>
          <p class="sub">{esc(d['hero_sub'])}</p>
          <div class="cta-row">
            <a class="btn" href="#">{esc(d['cta_store'])}</a>
            <a class="btn ghost" href="#how">{esc(d['cta_how'])}</a>
          </div>
          <div class="trust-band">
{badges}
          </div>
        </div>
        <div class="hero-shot">
          <div class="phone"><img src="/assets/screens/{shots}/01-dashboard.jpg" alt="{esc(d['shots'][0]['alt'])}" width="1080" height="2346" loading="eager"></div>
        </div>
      </div>
    </section>

    <section class="block wrap" id="problem">
      <h2>{esc(d['problem_h2'])}</h2>
      <p class="lead">{esc(d['problem_lead'])}</p>
    </section>

    <section class="block wrap" id="how">
      <h2>{esc(d['how_h2'])}</h2>
      <p class="lead">{esc(d['how_lead'])}</p>
      <div class="steps">
{steps}
      </div>
    </section>

    <section class="block wrap" id="features">
      <h2>{esc(d['features_h2'])}</h2>
      <div class="cards">
{cards}
      </div>
    </section>

    <section class="block wrap" id="screens">
      <h2>{esc(d['screens_h2'])}</h2>
      <p class="lead">{esc(d['screens_lead'])}</p>
      <div class="gallery">
{gallery}
      </div>
    </section>

    <section class="block wrap" id="privacy">
      <div class="privacy-feature">
        <h2>{esc(d['privacy_h2'])}</h2>
        <p class="lead">{esc(d['privacy_lead'])}</p>
        <div class="pills">
{pills}
        </div>
      </div>
    </section>

    <section class="block wrap" id="method">
      <h2>{esc(d['method_h2'])}</h2>
      <p class="lead">{esc(d['method_lead'])}</p>
    </section>

    <section class="block wrap" id="faq">
      <h2>{esc(d['faq_h2'])}</h2>
      <div class="faq">
{faq}
      </div>
    </section>
  </main>

  <div class="sticky-cta">
    <a class="btn" href="#">{esc(d['cta_store'])}</a>
  </div>

  <footer class="site">
    <div class="wrap">
      <div class="links">
        <a href="{legal}/privacy">{esc(d['footer']['privacy'])}</a>
        <a href="{legal}/terms">{esc(d['footer']['terms'])}</a>
        <a href="mailto:woodoo201818@gmail.com">{esc(d['footer']['support'])}</a>
      </div>
      <p>© 2026 Pudding</p>
      <p class="disclaimer">{esc(d['footer']['disclaimer'])}</p>
    </div>
  </footer>

  <script type="application/ld+json">
  {{
    "@context": "https://schema.org",
    "@graph": [
      {{
        "@type": "Organization",
        "@id": "{BASE}/#org",
        "name": "Pudding",
        "url": "{BASE}/",
        "logo": "{BASE}/assets/pudding.svg"
      }},
      {{
        "@type": "WebSite",
        "@id": "{url}#website",
        "url": "{url}",
        "name": "Pudding",
        "inLanguage": "{d['lang']}",
        "publisher": {{ "@id": "{BASE}/#org" }}
      }},
      {{
        "@type": "MobileApplication",
        "name": "Pudding",
        "operatingSystem": "iOS 17.0",
        "applicationCategory": "HealthApplication",
        "inLanguage": "{d['lang']}",
        "description": {json.dumps(d['jsonld_desc'], ensure_ascii=False)},
        "url": "{url}",
        "screenshot": "{alts[0]}",
        "offers": {{ "@type": "Offer", "price": "0", "priceCurrency": "{d['currency']}" }}
      }},
      {{
        "@type": "FAQPage",
        "mainEntity": [
          {faq_ld}
        ]
      }}
    ]
  }}
  </script>
  <script defer src="/_vercel/insights/script.js"></script>
</body>
</html>
"""


def sitemap(all_d: dict) -> str:
    rows = []
    for lang in LANGS:
        alts = "\n".join(
            f'    <xhtml:link rel="alternate" hreflang="{l}" href="{page_url(all_d[l])}"/>'
            for l in LANGS)
        rows.append(
            f"  <url>\n    <loc>{page_url(all_d[lang])}</loc>\n{alts}\n"
            f'    <xhtml:link rel="alternate" hreflang="x-default" href="{page_url(all_d["en"])}"/>\n'
            "    <priority>1.0</priority>\n  </url>")
    for page in ("privacy", "terms"):
        for prefix, lang in (("", "ru"), ("/en", "en")):
            rows.append(
                f"  <url>\n    <loc>{BASE}{prefix}/{page}</loc>\n"
                f'    <xhtml:link rel="alternate" hreflang="ru" href="{BASE}/{page}"/>\n'
                f'    <xhtml:link rel="alternate" hreflang="en" href="{BASE}/en/{page}"/>\n'
                f'    <xhtml:link rel="alternate" hreflang="x-default" href="{BASE}/en/{page}"/>\n'
                "    <priority>0.5</priority>\n  </url>")
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"\n'
            '        xmlns:xhtml="http://www.w3.org/1999/xhtml">\n'
            + "\n".join(rows) + "\n</urlset>\n")


def main() -> None:
    all_d = {lang: load(lang) for lang in LANGS}
    for lang in LANGS:
        d = all_d[lang]
        out = SITE / d["path"].strip("/") / "index.html"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(render(all_d, lang), encoding="utf-8")
        print("→", out.relative_to(ROOT))
    (SITE / "sitemap.xml").write_text(sitemap(all_d), encoding="utf-8")
    print("→ site/sitemap.xml")


if __name__ == "__main__":
    main()
