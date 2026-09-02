"""Тесты выбора темы для еженедельной статьи.

Запуск: `python3 -m unittest discover -s scripts` (голый unittest, как и тесты
генератора лендинга; `scripts/landing` — не пакет, поэтому discover туда не
заходит и гоняется отдельной командой).
"""
from __future__ import annotations

import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import write_article as wa  # noqa: E402 — путь дописывается выше


class SeedKeywordsTests(unittest.TestCase):
    """Затравочные ключи — единственный источник тем, пока GSC не подключён.
    Если в них просочится советующий запрос, статья будет писаться и тут же
    отбраковываться проверкой ADVICE_MARKERS: прогон за прогоном впустую."""

    def test_no_seed_trips_the_advice_guard(self):
        for key in wa.SEED_KEYWORDS:
            hit = next((m for m in wa.ADVICE_MARKERS if m in key.lower()), None)
            self.assertIsNone(hit, f"ключ {key!r} ловится маркером советов {hit!r}")

    def test_seeds_are_unique_and_non_empty(self):
        self.assertTrue(wa.SEED_KEYWORDS)
        self.assertEqual(len(wa.SEED_KEYWORDS), len(set(wa.SEED_KEYWORDS)))
        for key in wa.SEED_KEYWORDS:
            self.assertTrue(key.strip(), "пустой ключ в списке")

    def test_seeds_avoid_banned_topics(self):
        # Не подстрокой по BANNED (там формулировки для модели), а по смыслу:
        # возраст, схема и порция — это ровно то, за что нас не будут ранжировать.
        forbidden = ("month", "age", "schedule", "portion", "allerg", "safe")
        for key in wa.SEED_KEYWORDS:
            for word in forbidden:
                self.assertNotIn(word, key.lower(), f"ключ {key!r} уводит в медицину ({word})")


class DemandBlockTests(unittest.TestCase):

    def test_without_gsc_offers_the_seed_list(self):
        block = wa.demand_block(None)
        for key in wa.SEED_KEYWORDS:
            self.assertIn(key, block)
        # Раньше здесь было «придумай ключ» — модель гадала без данных.
        self.assertNotIn("Pick a fresh long-tail keyword", block)
        self.assertIn("do not invent", block)

    def test_with_gsc_uses_real_queries_and_drops_seeds(self):
        queries = [{"query": "baby food log app", "impressions": 120,
                    "clicks": 3, "position": 18.4}]
        block = wa.demand_block(queries)
        self.assertIn("baby food log app", block)
        self.assertIn("impr", block)
        for key in wa.SEED_KEYWORDS:
            self.assertNotIn(key, block)

    def test_gsc_block_caps_the_query_list(self):
        queries = [{"query": f"q{i}", "impressions": i, "clicks": 0, "position": 50.0}
                   for i in range(200)]
        block = wa.demand_block(queries)
        self.assertIn("q0", block)
        self.assertNotIn("q60 ", block)


if __name__ == "__main__":
    unittest.main()
