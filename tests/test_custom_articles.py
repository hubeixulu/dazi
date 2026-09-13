from pathlib import Path

from dazi.backend import Backend


RESOURCE = Path(__file__).parents[1] / "src" / "dazi" / "resources"


def test_import_uses_selected_difficulty_and_rejects_duplicate(tmp_path):
    article_path = tmp_path / "我的文章.txt"
    article_path.write_text("这是一篇自定义练习文章。", encoding="utf-8")
    backend = Backend(RESOURCE, tmp_path / "data")

    result = backend._import_text_path(article_path, "hard", "春日练习", "小明")
    assert result["ok"] is True
    custom = [item for item in backend.lessons if item.get("is_custom")]
    assert len(custom) == 1
    assert custom[0]["difficulty"] == "hard"
    assert custom[0]["title"] == "春日练习"
    assert custom[0]["author"] == "小明"
    assert "小明" in custom[0]["subtitle"]

    duplicate = backend._import_text_path(article_path, "easy")
    assert duplicate["ok"] is False
    assert duplicate["duplicate"] is True
    assert len([item for item in backend.lessons if item.get("is_custom")]) == 1


def test_custom_article_delete_requires_first_time_password(tmp_path):
    article_path = tmp_path / "article.txt"
    article_path.write_text("unique custom content", encoding="utf-8")
    backend = Backend(RESOURCE, tmp_path / "data")
    article_id = backend._import_text_path(article_path, "normal")["ok"] and next(
        item["id"] for item in backend.lessons if item.get("is_custom")
    )

    mismatch = backend.deleteCustomArticle(article_id, "abcd", "abce")
    assert mismatch["ok"] is False
    assert backend.hasDeletePassword is False

    deleted = backend.deleteCustomArticle(article_id, "abcd", "abcd")
    assert deleted["ok"] is True
    assert backend.hasDeletePassword is True
    assert not any(item.get("id") == article_id for item in backend.lessons)
