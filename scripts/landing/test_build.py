#!/usr/bin/env python3
"""Тесты генератора лендинга и блога.

Запуск из корня репозитория: `python3 -m unittest discover -s scripts/landing`.
Голый unittest без зависимостей — генератор тоже не должен их требовать.
"""
from __future__ import annotations

import json
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import build  # noqa: E402
from md import load_articles, render_markdown  # noqa: E402

ARTICLE = {
    "title": "Как вести дневник",
    "description": "Что записывать и зачем.",
    "keyword": "дневник прикорма",
    "date": "2026-08-14",
    "body": "Вступление.\n\n## Заголовок\n\n- пункт **важный**\n- второй\n",
}


class MarkdownTests(unittest.TestCase):
    def test_headings_paragraphs_lists(self):
        html = render_markdown("Абзац.\n\n## H2\n\n### H3\n\n- раз\n- два\n\n1. один\n2. два")
        self.assertIn("<p>Абзац.</p>", html)
        self.assertIn("<h2>H2</h2>", html)
        self.assertIn("<h3>H3</h3>", html)
        self.assertIn("<ul><li>раз</li><li>два</li></ul>", html)
        self.assertIn("<ol><li>один</li><li>два</li></ol>", html)

    def test_inline(self):
        html = render_markdown("**жирный** и *курсив*, [ссылка](/en) и `код`")
        self.assertIn("<strong>жирный</strong>", html)
        self.assertIn("<em>курсив</em>", html)
        self.assertIn('<a href="/en">ссылка</a>', html)
        self.assertIn("<code>код</code>", html)

    def test_html_is_escaped(self):
        """Тело статьи пишет модель — как HTML ему доверять нельзя."""
        html = render_markdown('<script>alert("x")</script>')
        self.assertNotIn("<script>", html)
        self.assertIn("&lt;script&gt;", html)

    def test_asterisks_inside_code_are_not_markup(self):
        self.assertIn("<code>a**b</code>", render_markdown("`a**b`"))

    def test_paragraph_break_ends_list(self):
        html = render_markdown("- раз\n\nАбзац после списка.")
        self.assertIn("</ul>", html)
        self.assertIn("<p>Абзац после списка.</p>", html)


class ArticleLoadingTests(unittest.TestCase):
    def test_loads_by_slug_and_lang(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "keeping-a-diary").mkdir()
            (root / "keeping-a-diary" / "en.json").write_text(
                json.dumps(ARTICLE), encoding="utf-8")
            got = load_articles(root)
        self.assertEqual(list(got), ["keeping-a-diary"])
        self.assertEqual(got["keeping-a-diary"]["en"]["slug"], "keeping-a-diary")
        self.assertEqual(got["keeping-a-diary"]["en"]["lang"], "en")

    def test_missing_dir_is_not_an_error(self):
        self.assertEqual(load_articles(pathlib.Path("/nope/does/not/exist")), {})


class UrlTests(unittest.TestCase):
    def setUp(self):
        self.all_d = {lang: build.load(lang) for lang in build.LANGS}

    def test_ru_lives_at_root(self):
        self.assertEqual(build.blog_url(self.all_d["ru"]), f"{build.BASE}/blog")
        self.assertEqual(build.blog_url(self.all_d["ru"], "x"), f"{build.BASE}/blog/x")

    def test_other_langs_are_prefixed(self):
        self.assertEqual(build.blog_url(self.all_d["en"], "x"), f"{build.BASE}/en/blog/x")
        self.assertEqual(build.blog_path(self.all_d["ja"]), "/ja/blog")

    def test_every_language_has_blog_strings(self):
        """Пропущенный ключ уронит сборку KeyError'ом уже после деплоя."""
        keys = {"title", "meta_desc", "h1", "lead", "back", "empty",
                "cta_h", "cta_p", "cta_btn"}
        for lang, d in self.all_d.items():
            self.assertTrue(keys <= set(d["blog"]), f"{lang}: не хватает ключей блога")
            self.assertIn("blog", d["nav"], f"{lang}: нет nav.blog")


class RenderTests(unittest.TestCase):
    def setUp(self):
        self.all_d = {lang: build.load(lang) for lang in build.LANGS}
        self.articles = {"keeping-a-diary": {"en": {**ARTICLE, "slug": "keeping-a-diary",
                                                    "lang": "en"}}}

    def test_post_page(self):
        html = build.render_post(self.all_d, "en", "keeping-a-diary",
                                 self.articles["keeping-a-diary"])
        self.assertIn("<h1>Как вести дневник</h1>", html)
        self.assertIn("<h2>Заголовок</h2>", html)
        self.assertIn('"@type": "BlogPosting"', html)
        self.assertIn(f'<link rel="canonical" href="{build.BASE}/en/blog/keeping-a-diary">', html)

    def test_untranslated_languages_get_no_alternate(self):
        """Иначе на /ja/blog/... уехал бы английский текст под японским hreflang."""
        html = build.render_post(self.all_d, "en", "keeping-a-diary",
                                 self.articles["keeping-a-diary"])
        self.assertNotIn('rel="alternate" hreflang="ja"', html)
        self.assertIn('rel="alternate" hreflang="en"', html)

    def test_language_picker_points_at_the_blog_not_the_landing(self):
        html = build.render_post(self.all_d, "en", "keeping-a-diary",
                                 self.articles["keeping-a-diary"])
        self.assertIn('href="/ja/blog" hreflang="ja"', html)

    def test_index_lists_only_translated_posts(self):
        en = build.render_blog_index(self.all_d, "en", self.articles)
        self.assertIn("/en/blog/keeping-a-diary", en)
        ja = build.render_blog_index(self.all_d, "ja", self.articles)
        self.assertNotIn("keeping-a-diary", ja)
        self.assertIn(self.all_d["ja"]["blog"]["empty"], ja)

    def test_landing_links_to_blog(self):
        html = build.render(self.all_d, "ru")
        self.assertIn('href="/blog"', html)

    def test_sitemap_includes_blog_and_posts(self):
        xml = build.sitemap(self.all_d, self.articles)
        self.assertIn(f"<loc>{build.BASE}/blog</loc>", xml)
        self.assertIn(f"<loc>{build.BASE}/en/blog/keeping-a-diary</loc>", xml)
        self.assertNotIn(f"<loc>{build.BASE}/ja/blog/keeping-a-diary</loc>", xml)
        self.assertIn("<lastmod>2026-08-14</lastmod>", xml)


if __name__ == "__main__":
    unittest.main()
