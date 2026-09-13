import json
import sqlite3

from dazi.storage import Storage


def sample_score(accuracy=96.0, speed=22.0):
    return {"accuracy": accuracy, "speed": speed, "speed_unit": "WPM",
            "errors": 1, "elapsed_seconds": 30.0}


def test_progress_keeps_best_and_counts_attempts(tmp_path):
    store = Storage(tmp_path / "data.db")
    store.save_result("lesson", "en", sample_score(), 2)
    store.save_result("lesson", "en", sample_score(90, 30), 1)
    progress = store.progress()["lesson:normal"]
    assert progress["best_accuracy"] == 96
    assert progress["best_speed"] == 30
    assert progress["stars"] == 2
    assert progress["attempts"] == 2


def test_settings_round_trip(tmp_path):
    store = Storage(tmp_path / "data.db")
    store.set_setting("sound", False)
    assert store.get_setting("sound", True) is False


def test_backup_round_trip(tmp_path):
    source = Storage(tmp_path / "source.db")
    source.save_result("lesson", "en", sample_score(), 2)
    backup = tmp_path / "backup.json"
    source.export_to(backup)
    assert json.loads(backup.read_text())["version"] == 4

    restored = Storage(tmp_path / "restored.db")
    restored.import_from(backup)
    assert restored.progress()["lesson:normal"]["stars"] == 2


def test_reset_preserves_settings(tmp_path):
    store = Storage(tmp_path / "data.db")
    store.set_setting("sound", False)
    store.save_result("lesson", "en", sample_score(), 2)
    store.reset()
    assert store.progress() == {}
    assert store.get_setting("sound") is False


def test_v1_database_is_migrated_without_losing_progress(tmp_path):
    path = tmp_path / "legacy.db"
    db = sqlite3.connect(path)
    db.executescript("""
        CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE results(id INTEGER PRIMARY KEY AUTOINCREMENT, lesson_id TEXT NOT NULL,
            language TEXT NOT NULL, accuracy REAL NOT NULL, speed REAL NOT NULL,
            speed_unit TEXT NOT NULL, errors INTEGER NOT NULL, elapsed_seconds REAL NOT NULL,
            stars INTEGER NOT NULL, created_at TEXT NOT NULL);
        CREATE TABLE progress(lesson_id TEXT PRIMARY KEY, best_accuracy REAL NOT NULL,
            best_speed REAL NOT NULL, stars INTEGER NOT NULL, attempts INTEGER NOT NULL,
            updated_at TEXT NOT NULL);
        INSERT INTO progress VALUES('old-lesson',95,20,2,3,'2026-01-01');
    """)
    db.commit()
    db.close()
    migrated = Storage(path)
    assert migrated.get_setting("schema_version") == 4
    assert migrated.progress()["old-lesson:normal"]["attempts"] == 3


def test_custom_articles_are_persistent_unique_and_deletable(tmp_path):
    path = tmp_path / "data.db"
    store = Storage(path)
    article = {"id": "custom-1", "title": "春天", "author": "小作者", "text": "春天来了。",
               "language": "zh", "difficulty": "easy"}
    assert store.add_custom_article(article) is True
    assert store.add_custom_article({**article, "id": "custom-2"}) is False
    store.connection.close()
    reopened = Storage(path)
    assert reopened.custom_articles()[0]["difficulty"] == "easy"
    assert reopened.custom_articles()[0]["author"] == "小作者"
    assert reopened.delete_custom_article("custom-1") is True
    assert reopened.custom_articles() == []


def test_v3_custom_articles_gain_empty_author_column(tmp_path):
    path = tmp_path / "v3.db"
    db = sqlite3.connect(path)
    db.executescript("""
        CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE results(id INTEGER PRIMARY KEY AUTOINCREMENT, lesson_id TEXT NOT NULL,
            language TEXT NOT NULL, accuracy REAL NOT NULL, speed REAL NOT NULL,
            speed_unit TEXT NOT NULL, errors INTEGER NOT NULL, elapsed_seconds REAL NOT NULL,
            stars INTEGER NOT NULL, difficulty TEXT NOT NULL DEFAULT 'normal',
            mode TEXT NOT NULL DEFAULT 'practice', combo INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL);
        CREATE TABLE progress(lesson_id TEXT NOT NULL, difficulty TEXT NOT NULL DEFAULT 'normal',
            best_accuracy REAL NOT NULL, best_speed REAL NOT NULL, stars INTEGER NOT NULL,
            attempts INTEGER NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY(lesson_id,difficulty));
        CREATE TABLE custom_articles(id TEXT PRIMARY KEY, title TEXT NOT NULL, text TEXT NOT NULL,
            content_hash TEXT NOT NULL UNIQUE, language TEXT NOT NULL, difficulty TEXT NOT NULL,
            created_at TEXT NOT NULL);
        INSERT INTO custom_articles VALUES('custom-old','旧文章','正文','hash','zh','normal','2026-01-01');
    """)
    db.commit()
    db.close()
    migrated = Storage(path)
    assert migrated.custom_articles()[0]["author"] == ""


def test_delete_password_is_salted_and_verified(tmp_path):
    store = Storage(tmp_path / "data.db")
    assert store.has_delete_password() is False
    store.set_delete_password("parent-secret")
    assert store.has_delete_password() is True
    assert store.verify_delete_password("parent-secret") is True
    assert store.verify_delete_password("wrong") is False
    assert "parent-secret" not in json.dumps(store.get_setting("delete_password"))


def test_backup_restores_custom_articles(tmp_path):
    source = Storage(tmp_path / "source.db")
    source.add_custom_article({"id": "custom-1", "title": "My text", "author": "Alice",
                               "text": "hello world", "language": "en", "difficulty": "hard"})
    backup = tmp_path / "backup.json"
    source.export_to(backup)
    restored = Storage(tmp_path / "restored.db")
    restored.import_from(backup)
    assert restored.custom_articles()[0]["title"] == "My text"
    assert restored.custom_articles()[0]["author"] == "Alice"
    assert restored.custom_articles()[0]["difficulty"] == "hard"
