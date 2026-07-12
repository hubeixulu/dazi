import json
from pathlib import Path

from dazi.difficulty import DIFFICULTIES, GAME_CONFIG


RESOURCE = Path(__file__).parents[1] / "src" / "dazi" / "resources"


def test_article_library_is_complete_and_auditable():
    articles = json.loads((RESOURCE / "articles.json").read_text(encoding="utf-8"))
    assert len(articles) == 66
    assert len({item["id"] for item in articles}) == 66
    required = {"difficulty", "age_band", "content_type", "author",
                "author_death_year", "source_edition", "public_domain_note", "text"}
    assert all(required <= item.keys() for item in articles)
    assert all(item["difficulty"] in DIFFICULTIES for item in articles)
    assert all(item["text"].strip() for item in articles)


def test_content_category_counts():
    articles = json.loads((RESOURCE / "articles.json").read_text(encoding="utf-8"))
    counts = {kind: sum(x["content_type"] == kind for x in articles)
              for kind in ("原创短文", "古诗", "古文", "现代公版")}
    assert counts == {"原创短文": 24, "古诗": 20, "古文": 8, "现代公版": 14}


def test_game_difficulties_are_materially_different():
    for game in GAME_CONFIG.values():
        assert set(game) == set(DIFFICULTIES)
        assert len({str(value) for value in game.values()}) == 3
