#!/usr/bin/env python3
"""Мини-рендер markdown → HTML для блога и загрузка статей.

Намеренно поддерживается только то подмножество, которое генератор статей
(`scripts/write_article.py`) обязан выдавать по промпту: ## / ### заголовки,
абзацы, списки, **жирный**, *курсив*, [ссылки](/путь) и `код`. Никаких
сторонних зависимостей — `build.py` должен запускаться голым `python3`.

Всё экранируется ДО разбора разметки: тело статьи пишет модель, доверять
ему как HTML нельзя.
"""
from __future__ import annotations

import json
import pathlib
import re

LANGS_ORDER_HINT = "см. build.LANGS"


def esc(s: str) -> str:
    return (s.replace("&", "&amp;").replace("<", "&lt;")
             .replace(">", "&gt;").replace('"', "&quot;"))


def _inline(s: str) -> str:
    """Экранированный текст → инлайн-разметка. Порядок важен: код первым,
    иначе `**` внутри бэктиков превратится в <strong>."""
    s = re.sub(r"`([^`]+)`", r"<code>\1</code>", s)
    s = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)", r'<a href="\2">\1</a>', s)
    s = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", s)
    s = re.sub(r"(?<!\*)\*([^*\n]+)\*(?!\*)", r"<em>\1</em>", s)
    return s


def render_markdown(text: str) -> str:
    """Markdown-подмножество → HTML. Вход не доверенный, экранируется целиком."""
    out: list[str] = []
    para: list[str] = []
    items: list[str] = []
    list_tag = ""

    def flush_para() -> None:
        if para:
            out.append(f"<p>{_inline(' '.join(para))}</p>")
            para.clear()

    def flush_list() -> None:
        nonlocal list_tag
        if items:
            lis = "".join(f"<li>{_inline(i)}</li>" for i in items)
            out.append(f"<{list_tag}>{lis}</{list_tag}>")
            items.clear()
            list_tag = ""

    for raw in esc(text).split("\n"):
        line = raw.rstrip()
        if not line.strip():
            flush_para()
            flush_list()
            continue
        if line.startswith("### "):
            flush_para(); flush_list()
            out.append(f"<h3>{_inline(line[4:].strip())}</h3>")
            continue
        if line.startswith("## "):
            flush_para(); flush_list()
            out.append(f"<h2>{_inline(line[3:].strip())}</h2>")
            continue
        m = re.match(r"^\s*[-*]\s+(.*)$", line)
        if m:
            flush_para()
            if list_tag and list_tag != "ul":
                flush_list()
            list_tag = "ul"
            items.append(m.group(1).strip())
            continue
        m = re.match(r"^\s*\d+[.)]\s+(.*)$", line)
        if m:
            flush_para()
            if list_tag and list_tag != "ol":
                flush_list()
            list_tag = "ol"
            items.append(m.group(1).strip())
            continue
        flush_list()
        para.append(line.strip())

    flush_para()
    flush_list()
    return "\n".join(out)


def load_articles(content_dir: pathlib.Path) -> dict[str, dict[str, dict]]:
    """`content/blog/<slug>/<lang>.json` → {slug: {lang: статья}}.

    Локали, которых нет на диске, просто отсутствуют — статья публикуется
    только на переведённых языках, чужой hreflang на английский текст не
    ставится.
    """
    articles: dict[str, dict[str, dict]] = {}
    if not content_dir.exists():
        return articles
    for slug_dir in sorted(p for p in content_dir.iterdir() if p.is_dir()):
        by_lang = {}
        for f in sorted(slug_dir.glob("*.json")):
            data = json.loads(f.read_text(encoding="utf-8"))
            data["slug"] = slug_dir.name
            data["lang"] = f.stem
            by_lang[f.stem] = data
        if by_lang:
            articles[slug_dir.name] = by_lang
    return articles
