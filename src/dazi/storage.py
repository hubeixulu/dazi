from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path


SCHEMA_VERSION = 2


class Storage:
    def __init__(self, path: Path):
        self.path = path
        path.parent.mkdir(parents=True, exist_ok=True)
        self.connection = sqlite3.connect(path)
        self.connection.row_factory = sqlite3.Row
        self._migrate()

    def _migrate(self) -> None:
        self.connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY, value TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                lesson_id TEXT NOT NULL, language TEXT NOT NULL,
                accuracy REAL NOT NULL, speed REAL NOT NULL,
                speed_unit TEXT NOT NULL, errors INTEGER NOT NULL,
                elapsed_seconds REAL NOT NULL, stars INTEGER NOT NULL,
                difficulty TEXT NOT NULL DEFAULT 'normal', mode TEXT NOT NULL DEFAULT 'practice',
                combo INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS progress (
                lesson_id TEXT NOT NULL, difficulty TEXT NOT NULL DEFAULT 'normal',
                best_accuracy REAL NOT NULL,
                best_speed REAL NOT NULL, stars INTEGER NOT NULL,
                attempts INTEGER NOT NULL, updated_at TEXT NOT NULL,
                PRIMARY KEY(lesson_id, difficulty)
            );
            """
        )
        result_columns = {row[1] for row in self.connection.execute("PRAGMA table_info(results)")}
        for name, definition in (("difficulty", "TEXT NOT NULL DEFAULT 'normal'"),
                                 ("mode", "TEXT NOT NULL DEFAULT 'practice'"),
                                 ("combo", "INTEGER NOT NULL DEFAULT 0")):
            if name not in result_columns:
                self.connection.execute(f"ALTER TABLE results ADD COLUMN {name} {definition}")
        progress_columns = {row[1] for row in self.connection.execute("PRAGMA table_info(progress)")}
        pk_columns = [row[1] for row in self.connection.execute("PRAGMA table_info(progress)") if row[5]]
        if "difficulty" not in progress_columns or pk_columns == ["lesson_id"]:
            self.connection.executescript(
                """CREATE TABLE progress_v2 (
                    lesson_id TEXT NOT NULL, difficulty TEXT NOT NULL DEFAULT 'normal',
                    best_accuracy REAL NOT NULL, best_speed REAL NOT NULL, stars INTEGER NOT NULL,
                    attempts INTEGER NOT NULL, updated_at TEXT NOT NULL,
                    PRIMARY KEY(lesson_id, difficulty));
                    INSERT OR REPLACE INTO progress_v2
                    SELECT lesson_id, 'normal', best_accuracy, best_speed, stars, attempts, updated_at FROM progress;
                    DROP TABLE progress;
                    ALTER TABLE progress_v2 RENAME TO progress;"""
            )
        self.set_setting("schema_version", SCHEMA_VERSION)

    def set_setting(self, key: str, value) -> None:
        payload = json.dumps(value, ensure_ascii=False)
        self.connection.execute(
            "INSERT INTO settings(key,value) VALUES(?,?) "
            "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (key, payload)
        )
        self.connection.commit()

    def get_setting(self, key: str, default=None):
        row = self.connection.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
        return json.loads(row[0]) if row else default

    def save_result(self, lesson_id: str, language: str, score: dict, stars: int,
                    difficulty: str = "normal", mode: str = "practice", combo: int = 0) -> None:
        now = datetime.now(timezone.utc).isoformat()
        self.connection.execute(
            "INSERT INTO results(lesson_id,language,accuracy,speed,speed_unit,errors,elapsed_seconds,stars,difficulty,mode,combo,created_at) "
            "VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",
            (lesson_id, language, score["accuracy"], score["speed"], score["speed_unit"],
             score["errors"], score["elapsed_seconds"], stars, difficulty, mode, combo, now),
        )
        self.connection.execute(
            """INSERT INTO progress(lesson_id,difficulty,best_accuracy,best_speed,stars,attempts,updated_at)
               VALUES(?,?,?,?,?,1,?) ON CONFLICT(lesson_id,difficulty) DO UPDATE SET
               best_accuracy=max(best_accuracy,excluded.best_accuracy),
               best_speed=max(best_speed,excluded.best_speed), stars=max(stars,excluded.stars),
               attempts=attempts+1, updated_at=excluded.updated_at""",
            (lesson_id, difficulty, score["accuracy"], score["speed"], stars, now),
        )
        self.connection.commit()

    def progress(self) -> dict[str, dict]:
        rows = self.connection.execute("SELECT * FROM progress").fetchall()
        return {f'{row["lesson_id"]}:{row["difficulty"]}': dict(row) for row in rows}

    def recent_results(self, limit: int = 8) -> list[dict]:
        rows = self.connection.execute(
            "SELECT * FROM results ORDER BY id DESC LIMIT ?", (limit,)
        ).fetchall()
        return [dict(row) for row in rows]

    def export_to(self, path: Path) -> None:
        data = {"version": SCHEMA_VERSION, "settings": {}, "results": self.recent_results(10000)}
        for row in self.connection.execute("SELECT key,value FROM settings"):
            data["settings"][row["key"]] = json.loads(row["value"])
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    def import_from(self, path: Path) -> None:
        data = json.loads(path.read_text(encoding="utf-8"))
        if data.get("version") not in (1, SCHEMA_VERSION) or not isinstance(data.get("results"), list):
            raise ValueError("不支持的备份文件")
        with self.connection:
            self.connection.execute("DELETE FROM results")
            self.connection.execute("DELETE FROM progress")
            for key, value in data.get("settings", {}).items():
                self.connection.execute(
                    "INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)",
                    (key, json.dumps(value, ensure_ascii=False)),
                )
            for item in reversed(data["results"]):
                score = {"accuracy": item["accuracy"], "speed": item["speed"],
                         "speed_unit": item["speed_unit"], "errors": item["errors"],
                         "elapsed_seconds": item["elapsed_seconds"]}
                self.save_result(item["lesson_id"], item["language"], score, item["stars"],
                                 item.get("difficulty", "normal"), item.get("mode", "practice"),
                                 item.get("combo", 0))

    def reset(self) -> None:
        with self.connection:
            self.connection.execute("DELETE FROM results")
            self.connection.execute("DELETE FROM progress")
