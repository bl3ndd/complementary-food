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

from md import load_articles, render_markdown

ROOT = pathlib.Path(__file__).resolve().parents[2]
I18N = pathlib.Path(__file__).resolve().parent / "i18n"
SITE = ROOT / "site"
CONTENT = ROOT / "content" / "blog"
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
    return hreflang_links({l: page_url(all_d[l]) for l in LANGS}, page_url(cur))


def hreflang_links(urls: dict, canonical: str) -> str:
    """canonical + alternate по словарю {lang: url}. x-default — на en, а если
    его в словаре нет (статья не переведена), на канонический."""
    out = [f'  <link rel="canonical" href="{canonical}">']
    for lang in LANGS:
        if lang in urls:
            out.append(f'  <link rel="alternate" hreflang="{lang}" href="{urls[lang]}">')
    out.append('  <link rel="alternate" hreflang="x-default" '
               f'href="{urls.get("en", canonical)}">')
    return "\n".join(out)


def blog_url(d: dict, slug: str = "") -> str:
    """`/blog` и `/blog/<slug>` для ru (корень), `/<lang>/blog/...` для остальных."""
    prefix = d["path"].rstrip("/")
    return f"{BASE}{prefix}/blog" + (f"/{slug}" if slug else "")


def lang_picker(all_d: dict, cur: dict, hrefs: dict | None = None) -> str:
    """Дропдаун на <details> — без JS, чтобы не расширять CSP.

    `hrefs` — куда ведут пункты; по умолчанию на лендинг локали. Со страницы
    статьи передаём ссылки на её же перевод, чтобы переключение языка не
    выкидывало читателя из текста на главную."""
    items = []
    for lang in LANGS:
        d = all_d[lang]
        active = ' class="active"' if lang == cur["lang"] else ""
        href = (hrefs or {}).get(lang, d["path"])
        items.append(f'<a{active} href="{href}" hreflang="{lang}" lang="{lang}">{esc(d["native"])}</a>')
    return (
        '<details class="langpick">\n'
        f'          <summary aria-label="{esc(cur["lang_label"])}"><span class="globe">🌐</span>{esc(cur["native_short"])}</summary>\n'
        f'          <div class="langmenu">{"".join(items)}</div>\n'
        "        </details>"
    )


def site_header(all_d: dict, d: dict, lang_hrefs: dict | None = None) -> str:
    """Шапка. На лендинге якоря ведут на секции, поэтому ссылки абсолютные от
    корня локали — иначе с /blog/<slug> «Возможности» ведёт в никуда."""
    home = d["path"]
    return (
        '  <header class="site">\n'
        '    <div class="wrap nav">\n'
        f'      <a class="brand" href="{home}"><img src="/assets/pudding.svg" alt="Pudding">Pudding</a>\n'
        '      <div class="nav-right">\n'
        f'        <a href="{home}#features">{esc(d["nav"]["features"])}</a>\n'
        f'        <a href="{home}#screens">{esc(d["nav"]["screens"])}</a>\n'
        f'        <a href="{blog_path(d)}">{esc(d["nav"]["blog"])}</a>\n'
        f'        <a href="{home}#privacy">{esc(d["nav"]["privacy"])}</a>\n'
        f'        {lang_picker(all_d, d, lang_hrefs)}\n'
        "      </div>\n"
        "    </div>\n"
        "  </header>"
    )


def site_footer(d: dict) -> str:
    legal = "/en" if d.get("legal") == "en" else d["path"].rstrip("/")
    return (
        '  <footer class="site">\n'
        '    <div class="wrap">\n'
        '      <div class="links">\n'
        f'        <a href="{legal}/privacy">{esc(d["footer"]["privacy"])}</a>\n'
        f'        <a href="{legal}/terms">{esc(d["footer"]["terms"])}</a>\n'
        f'        <a href="{blog_path(d)}">{esc(d["nav"]["blog"])}</a>\n'
        f'        <a href="mailto:woodoo201818@gmail.com">{esc(d["footer"]["support"])}</a>\n'
        "      </div>\n"
        "      <p>© 2026 Pudding</p>\n"
        f'      <p class="disclaimer">{esc(d["footer"]["disclaimer"])}</p>\n'
        "    </div>\n"
        "  </footer>"
    )


def blog_path(d: dict, slug: str = "") -> str:
    return blog_url(d, slug)[len(BASE):]


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
{site_header(all_d, d)}

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

{site_footer(d)}

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


def blog_head(d: dict, title: str, desc: str, url: str, urls: dict) -> str:
    """Общая голова для /blog и статей: та же типографика и OG, что у лендинга."""
    return f"""<!DOCTYPE html>
<html lang="{d['lang']}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{esc(title)}</title>
  <meta name="description" content="{esc(desc)}">
  <meta name="robots" content="index, follow">
{hreflang_links(urls, url)}
  <meta property="og:type" content="article">
  <meta property="og:site_name" content="Pudding">
  <meta property="og:locale" content="{d['og_locale']}">
  <meta property="og:url" content="{url}">
  <meta property="og:title" content="{esc(title)}">
  <meta property="og:description" content="{esc(desc)}">
  <meta property="og:image" content="{BASE}/assets/og.png">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="{esc(title)}">
  <meta name="twitter:description" content="{esc(desc)}">
  <meta name="twitter:image" content="{BASE}/assets/og.png">
  <link rel="icon" href="/assets/pudding.svg" type="image/svg+xml">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Nunito:wght@400;700;800;900&display=swap{d.get('font_subset','')}" rel="stylesheet">
  <link rel="stylesheet" href="/styles.css">
</head>
<body>
"""


def render_post(all_d: dict, lang: str, slug: str, by_lang: dict) -> str:
    d = all_d[lang]
    a = by_lang[lang]
    url = blog_url(d, slug)
    urls = {l: blog_url(all_d[l], slug) for l in LANGS if l in by_lang}
    ld = json.dumps({
        "@context": "https://schema.org",
        "@type": "BlogPosting",
        "headline": a["title"],
        "description": a["description"],
        "datePublished": a["date"],
        "inLanguage": d["lang"],
        "mainEntityOfPage": url,
        "author": {"@type": "Organization", "name": "Pudding", "url": f"{BASE}/"},
        "publisher": {"@type": "Organization", "name": "Pudding",
                      "logo": {"@type": "ImageObject", "url": f"{BASE}/assets/pudding.svg"}},
    }, ensure_ascii=False, indent=2)
    # На непереведённых языках пункт ведёт в блог этой локали, а не на статью.
    picker = {l: (blog_path(all_d[l], slug) if l in by_lang else blog_path(all_d[l]))
              for l in LANGS}
    return (blog_head(d, a["title"], a["description"], url, urls)
            + site_header(all_d, d, picker) + "\n"
            + f"""
  <main class="wrap post">
    <p class="post-back"><a href="{blog_path(d)}">← {esc(d['blog']['back'])}</a></p>
    <article>
      <h1>{esc(a['title'])}</h1>
      <p class="post-date">{esc(a['date'])}</p>
{render_markdown(a['body'])}
    </article>
    <aside class="post-cta">
      <img src="/assets/pudding.svg" alt="Pudding" width="72" height="72">
      <div>
        <h2>{esc(d['blog']['cta_h'])}</h2>
        <p>{esc(d['blog']['cta_p'])}</p>
        <a class="btn" href="{d['path']}">{esc(d['blog']['cta_btn'])}</a>
      </div>
    </aside>
    <p class="post-disclaimer">{esc(d['footer']['disclaimer'])}</p>
  </main>

"""
            + site_footer(d) + "\n"
            + f"""
  <script type="application/ld+json">
{ld}
  </script>
  <script defer src="/_vercel/insights/script.js"></script>
</body>
</html>
""")


def render_blog_index(all_d: dict, lang: str, articles: dict) -> str:
    d = all_d[lang]
    url = blog_url(d)
    urls = {l: blog_url(all_d[l]) for l in LANGS}
    # Свежие сверху; при равной дате — по слагу, чтобы сборка была воспроизводимой.
    posts = sorted((a[lang] for a in articles.values() if lang in a),
                   key=lambda a: (a["date"], a["slug"]), reverse=True)
    cards = "\n".join(
        f'      <a class="postcard" href="{blog_path(d, p["slug"])}">'
        f'<h2>{esc(p["title"])}</h2><p>{esc(p["description"])}</p>'
        f'<span class="post-date">{esc(p["date"])}</span></a>'
        for p in posts) or f'      <p class="lead">{esc(d["blog"]["empty"])}</p>'
    return (blog_head(d, d["blog"]["title"], d["blog"]["meta_desc"], url, urls)
            + site_header(all_d, d, {l: blog_path(all_d[l]) for l in LANGS}) + "\n"
            + f"""
  <main class="wrap postlist">
    <h1>{esc(d['blog']['h1'])}</h1>
    <p class="lead">{esc(d['blog']['lead'])}</p>
    <div class="postcards">
{cards}
    </div>
  </main>

"""
            + site_footer(d) + "\n"
            + """
  <script defer src="/_vercel/insights/script.js"></script>
</body>
</html>
""")


def sitemap(all_d: dict, articles: dict | None = None) -> str:
    articles = articles or {}
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
    for lang in LANGS:
        alts = "\n".join(
            f'    <xhtml:link rel="alternate" hreflang="{l}" href="{blog_url(all_d[l])}"/>'
            for l in LANGS)
        rows.append(
            f"  <url>\n    <loc>{blog_url(all_d[lang])}</loc>\n{alts}\n"
            f'    <xhtml:link rel="alternate" hreflang="x-default" href="{blog_url(all_d["en"])}"/>\n'
            "    <priority>0.6</priority>\n  </url>")
    for slug, by_lang in sorted(articles.items()):
        alts = "\n".join(
            f'    <xhtml:link rel="alternate" hreflang="{l}" href="{blog_url(all_d[l], slug)}"/>'
            for l in LANGS if l in by_lang)
        xdefault = blog_url(all_d["en" if "en" in by_lang else next(iter(by_lang))], slug)
        for lang in LANGS:
            if lang not in by_lang:
                continue
            rows.append(
                f"  <url>\n    <loc>{blog_url(all_d[lang], slug)}</loc>\n"
                f"    <lastmod>{by_lang[lang]['date']}</lastmod>\n{alts}\n"
                f'    <xhtml:link rel="alternate" hreflang="x-default" href="{xdefault}"/>\n'
                "    <priority>0.7</priority>\n  </url>")
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"\n'
            '        xmlns:xhtml="http://www.w3.org/1999/xhtml">\n'
            + "\n".join(rows) + "\n</urlset>\n")


def write(path: pathlib.Path, html: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(html, encoding="utf-8")
    print("→", path.relative_to(ROOT))


def main() -> None:
    all_d = {lang: load(lang) for lang in LANGS}
    articles = load_articles(CONTENT)
    for lang in LANGS:
        d = all_d[lang]
        write(SITE / d["path"].strip("/") / "index.html", render(all_d, lang))
        write(SITE / blog_path(d).strip("/") / "index.html",
              render_blog_index(all_d, lang, articles))
    for slug, by_lang in sorted(articles.items()):
        for lang in LANGS:
            if lang in by_lang:
                write(SITE / blog_path(all_d[lang], slug).strip("/") / "index.html",
                      render_post(all_d, lang, slug, by_lang))
    (SITE / "sitemap.xml").write_text(sitemap(all_d, articles), encoding="utf-8")
    print("→ site/sitemap.xml")


if __name__ == "__main__":
    main()
