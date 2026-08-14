#!/usr/bin/env python3
"""Пишет одну SEO-статью для блога Pudding и переводит её на 13 языков.

`content/blog/<slug>/en.json` — оригинал, остальные `<lang>.json` — переводы.
Запускается GitHub Action по расписанию (`.github/workflows/weekly-article.yml`)
и руками: `python3 scripts/write_article.py`.

Ниша жёсткая: **дневник и учёт прикорма**, а не советы по питанию. Приложение
принципиально ничего не советует (см. CLAUDE.md), и сайт не должен обещать то,
чего продукт не делает — плюс медицинские советы от анонимного сайта Google
всё равно не ранжирует. Запрет зашит в промпт и продублирован проверкой ниже.
"""
from __future__ import annotations

import datetime as dt
import json
import os
import pathlib
import sys
import time
import urllib.parse
import urllib.request

import anthropic

ROOT = pathlib.Path(__file__).resolve().parents[1]
DIR = ROOT / "content" / "blog"

GEN_MODEL = "claude-opus-5"      # оригинал: качество текста = ранжирование
TR_MODEL = "claude-haiku-4-5"    # перевод — узкая задача, хайку хватает и он дешевле

# Совпадает с LANGS в scripts/landing/build.py, минус en (это исходник).
LOCALES = ["ru", "de", "es", "fr", "it", "nl", "pl", "pt-BR", "tr", "uk", "ja", "ko", "zh-Hans"]
LANG_NAME = {
    "ru": "Russian", "de": "German", "es": "Spanish", "fr": "French", "it": "Italian",
    "nl": "Dutch", "pl": "Polish", "pt-BR": "Brazilian Portuguese", "tr": "Turkish",
    "uk": "Ukrainian", "ja": "Japanese", "ko": "Korean", "zh-Hans": "Simplified Chinese",
}

ARTICLE_SCHEMA = {
    "type": "json_schema",
    "schema": {
        "type": "object",
        "properties": {
            "slug": {"type": "string"},
            "title": {"type": "string"},
            "description": {"type": "string"},
            "keyword": {"type": "string"},
            "body": {"type": "string"},
        },
        "required": ["slug", "title", "description", "keyword", "body"],
        "additionalProperties": False,
    },
}
TRANSLATION_SCHEMA = {
    "type": "json_schema",
    "schema": {
        "type": "object",
        "properties": {
            "title": {"type": "string"},
            "description": {"type": "string"},
            "body": {"type": "string"},
        },
        "required": ["title", "description", "body"],
        "additionalProperties": False,
    },
}

# Слова-маркеры советующего текста. Не цензура, а сигнал, что модель уехала из
# ниши «как вести дневник» в «когда вводить яйцо» — такую статью не публикуем.
ADVICE_MARKERS = [
    "you should introduce", "should be introduced", "safe to introduce",
    "recommended age", "at what age", "when to introduce", "start solids at",
    "months old, introduce", "consult your pediatrician before", "allergy risk",
]

# Темы, которые НЕ пишем, — дублируют лендинг или уводят в медицину.
BANNED = "medical advice, feeding schedules, age recommendations, allergy guidance, nutrition claims"


def gsc_queries() -> list[dict] | None:
    """Небрендовые запросы из Search Console за 90 дней. Без секрета — None,
    и тогда тему модель придумывает сама, а прогон не падает."""
    raw = os.environ.get("GSC_SERVICE_ACCOUNT_JSON")
    if not raw:
        return None
    from google.oauth2 import service_account       # noqa: PLC0415 — нужен только здесь
    from google.auth.transport.requests import Request  # noqa: PLC0415

    creds = service_account.Credentials.from_service_account_info(
        json.loads(raw), scopes=["https://www.googleapis.com/auth/webmasters.readonly"])
    creds.refresh(Request())

    end = dt.date.today()
    start = end - dt.timedelta(days=90)
    sites = [os.environ["GSC_SITE_URL"]] if os.environ.get("GSC_SITE_URL") else [
        "sc-domain:pudding-for-children.vercel.app",
        "https://pudding-for-children.vercel.app/",
    ]
    problems = []
    for site in sites:
        url = ("https://www.googleapis.com/webmasters/v3/sites/"
               f"{urllib.parse.quote(site, safe='')}/searchAnalytics/query")
        body = json.dumps({"startDate": start.isoformat(), "endDate": end.isoformat(),
                           "dimensions": ["query"], "rowLimit": 200}).encode()
        req = urllib.request.Request(url, data=body, method="POST")
        req.add_header("Authorization", f"Bearer {creds.token}")
        req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req) as r:
                rows = json.loads(r.read()).get("rows", [])
            print(f"GSC: ресурс {site}")
            return [{"query": x["keys"][0], "impressions": x["impressions"],
                     "clicks": x["clicks"], "position": round(x["position"], 1)}
                    for x in rows if "pudding" not in x["keys"][0].lower()]
        except Exception as e:  # noqa: BLE001 — любая беда с GSC не должна ронять прогон
            problems.append(f"{site} → {e}")
    print("GSC недоступен (" + ", ".join(problems) + ") — тема будет придумана")
    return None


def published() -> list[dict]:
    """Уже вышедшие статьи — чтобы модель не написала то же самое второй раз."""
    out = []
    if not DIR.exists():
        return out
    for slug_dir in sorted(p for p in DIR.iterdir() if p.is_dir()):
        f = slug_dir / "en.json"
        if f.exists():
            a = json.loads(f.read_text(encoding="utf-8"))
            out.append({"slug": slug_dir.name, "title": a["title"], "keyword": a["keyword"]})
    return out


def demand_block(queries: list[dict] | None) -> str:
    if not queries:
        return ("Pick a fresh long-tail keyword a real parent would type into Google, "
                "about RECORDING and TRACKING complementary feeding — not about what to feed.")
    lines = "\n".join(
        f"- {q['query']} — {q['impressions']} impr, {q['clicks']} clicks, pos {q['position']}"
        for q in queries[:60])
    return (
        "Real search queries this site already appears for, over the last 90 days "
        "(query — impressions, clicks, average position). Pick the topic from THIS list: "
        "a query with real impressions that none of the published articles below answers, "
        "and that can be answered WITHOUT giving feeding or medical advice. Prefer queries "
        "with impressions but few clicks and a weak position.\n\n" + lines)


def generate(client: anthropic.Anthropic, queries: list[dict] | None) -> dict:
    done = published()
    done_list = "\n".join(f"- {a['title']} (keyword: {a['keyword']})" for a in done) or "(none yet)"
    prompt = f"""You write blog articles for Pudding (pudding-for-children.vercel.app) — a free,
offline iPhone diary for complementary feeding: a parent records which food the baby was given,
on which day, and how the child reacted. No account, no backend, no ads.

THE ONE HARD RULE: Pudding is a diary, not an advisor. The app never tells parents what or when
to feed, and neither do these articles. Never write about: {BANNED}. If a topic can only be
answered by giving feeding or medical advice, pick a different topic.

WRITE ABOUT INSTEAD — record-keeping and organisation:
- how to keep a feeding diary and what is actually worth writing down
- reconstructing what a child ate when a reaction shows up later
- paper vs notes app vs a dedicated diary; printable logs and their limits
- keeping the record consistent across two parents, grandparents, or daycare
- what a pediatrician can actually use from a parent's own notes
- organising photos, portions and notes so the history stays searchable
- what to bring to a pediatrician appointment from your own records

Already published — do NOT repeat these topics or write a near-duplicate:
{done_list}

{demand_block(queries)}

Write ONE brand-new article on that topic. 600-900 words. Make it concrete and genuinely useful:
a real how-to about keeping records. Write like a parent who has done this, not like marketing.
Mention Pudding naturally once or twice (free, works offline, no account) — do not make it an ad.
Never state or imply a recommended age, schedule, portion, or allergy guidance, not even as an
example. Where a reader might expect advice, point them to their own pediatrician instead.

Body format: markdown using ONLY these constructs — paragraphs, `## ` and `### ` headings,
`- ` bullet lists, `1. ` numbered lists, **bold**, *italic*, [links](/en) and `code`. No images,
no tables, no HTML, no code fences, no H1 (the title is the H1)."""

    with client.messages.stream(
        model=GEN_MODEL,
        max_tokens=16000,
        thinking={"type": "adaptive"},
        output_config={"effort": "high", "format": ARTICLE_SCHEMA},
        messages=[{"role": "user", "content": prompt}],
    ) as stream:
        msg = stream.get_final_message()
    if msg.stop_reason == "refusal":
        sys.exit("генерация отклонена классификатором — прогон пропущен")
    return json.loads(next(b.text for b in msg.content if b.type == "text"))


def translate(client: anthropic.Anthropic, article: dict, loc: str, attempts: int = 3) -> dict:
    prompt = f"""Translate this blog article into {LANG_NAME[loc]}.

Rules:
- Translate the title, the description and the full markdown body into natural, fluent {LANG_NAME[loc]}.
- Preserve the markdown structure exactly: ## and ### headings, lists, **bold**, *italic*, links, `code`.
- For links like [text](/en), translate the visible TEXT but keep the URL path unchanged.
- Keep the brand name "Pudding" as-is.
- Do not add, drop or soften anything — in particular do not add feeding or medical advice.

TITLE: {article['title']}
DESCRIPTION: {article['description']}
BODY:
{article['body']}"""
    last = None
    for attempt in range(1, attempts + 1):
        try:
            with client.messages.stream(
                model=TR_MODEL,
                max_tokens=16000,
                output_config={"format": TRANSLATION_SCHEMA},
                messages=[{"role": "user", "content": prompt}],
            ) as stream:
                msg = stream.get_final_message()
            return json.loads(next(b.text for b in msg.content if b.type == "text"))
        except Exception as e:  # noqa: BLE001 — одиночный сетевой сбой не должен ронять прогон
            last = e
            print(f"перевод {loc} не удался (попытка {attempt}/{attempts}): {e}")
            if attempt < attempts:
                time.sleep(attempt * 2)
    raise RuntimeError(f"перевод {loc}: {last}")


def main() -> None:
    client = anthropic.Anthropic()
    queries = gsc_queries()
    print(f"GSC: {len(queries)} небрендовых запросов" if queries else "GSC: тема придумана моделью")

    a = generate(client, queries)
    slug = "".join(c for c in a["slug"].lower() if c.isalnum() or c == "-").strip("-")
    if not slug or (DIR / slug).exists():
        print(f"пустой или дублирующий slug — ничего не записано: {slug!r}")
        return

    body = a["body"].strip()
    lower = body.lower()
    hit = next((m for m in ADVICE_MARKERS if m in lower), None)
    if hit:
        sys.exit(f"статья скатилась в советы (маркер: {hit!r}) — не публикуем")

    date = os.environ.get("ARTICLE_DATE") or dt.date.today().isoformat()
    base = {"title": a["title"].strip(), "description": a["description"].strip(),
            "keyword": a["keyword"].strip(), "date": date}

    # Собираем все языки в памяти и пишем на диск одним заходом: статья, у
    # которой перевелась половина локалей, хуже, чем ненаписанная — на
    # непереведённых URL оказался бы английский текст под чужим hreflang.
    files = {"en": {**base, "body": body}}
    for loc in LOCALES:
        tr = translate(client, a, loc)
        files[loc] = {**base, "title": tr["title"].strip(),
                      "description": tr["description"].strip(), "body": tr["body"].strip()}
        print("переведено", loc)

    (DIR / slug).mkdir(parents=True, exist_ok=True)
    for loc, data in files.items():
        (DIR / slug / f"{loc}.json").write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"готово: content/blog/{slug}/ ({len(files)} языков)")


if __name__ == "__main__":
    main()
