from __future__ import annotations

import json
import time
from pathlib import Path

from PySide6.QtCore import QObject, Property, QStandardPaths, Signal, Slot
from PySide6.QtWidgets import QFileDialog
from PySide6.QtWidgets import QApplication

from .scoring import current_error_index, score_live_text, score_text
from .storage import Storage
from .difficulty import DIFFICULTIES, GAME_CONFIG


class Backend(QObject):
    lessonsChanged = Signal()
    progressChanged = Signal()
    resultChanged = Signal()
    settingsChanged = Signal()
    difficultyChanged = Signal()

    def __init__(self, resource_dir: Path, data_dir: Path | None = None):
        super().__init__()
        self.resource_dir = resource_dir
        self._lessons = json.loads((resource_dir / "lessons.json").read_text(encoding="utf-8"))
        articles_path = resource_dir / "articles.json"
        if articles_path.exists():
            self._lessons.extend(json.loads(articles_path.read_text(encoding="utf-8")))
        base = data_dir or Path(QStandardPaths.writableLocation(QStandardPaths.AppDataLocation))
        self.storage = Storage(base / "dazi.db")
        self._started_at = time.monotonic()
        self._last_result: dict = {}

    @Property("QVariantList", notify=lessonsChanged)
    def lessons(self):
        progress = self.storage.progress()
        output = []
        for lesson in self._lessons:
            item = dict(lesson)
            item.setdefault("difficulty", "normal")
            item.setdefault("age_band", "全年龄")
            item.setdefault("content_type", "course")
            item["stars"] = progress.get(f'{lesson["id"]}:{item["difficulty"]}', {}).get("stars", 0)
            item["char_count"] = len(item.get("text", ""))
            output.append(item)
        return output

    @Property("QVariantMap", notify=progressChanged)
    def summary(self):
        progress = self.storage.progress()
        results = self.storage.recent_results(10000)
        stars = sum(item["stars"] for item in progress.values())
        lesson_ids = {item["id"] for item in self._lessons}
        completed = len({item["lesson_id"] for item in progress.values() if item["lesson_id"] in lesson_ids})
        return {"completed": completed, "total": len(self._lessons), "stars": stars,
                "attempts": len(results)}

    @Property("QVariantMap", notify=resultChanged)
    def lastResult(self):
        return self._last_result

    @Property(bool, notify=settingsChanged)
    def soundEnabled(self):
        return bool(self.storage.get_setting("sound_enabled", True))

    @soundEnabled.setter
    def soundEnabled(self, value: bool):
        self.storage.set_setting("sound_enabled", value)
        self.settingsChanged.emit()

    @Property(bool, notify=settingsChanged)
    def reducedMotion(self):
        return bool(self.storage.get_setting("reduced_motion", False))

    @reducedMotion.setter
    def reducedMotion(self, value: bool):
        self.storage.set_setting("reduced_motion", value)
        self.settingsChanged.emit()

    @Slot()
    def startPractice(self):
        self._started_at = time.monotonic()

    @Slot(str, str, str, result="QVariantMap")
    def liveScore(self, target: str, typed: str, language: str):
        score = score_live_text(target, typed, time.monotonic() - self._started_at, language).to_dict()
        score["error_index"] = current_error_index(target, typed)
        score["complete"] = typed == target
        return score

    @Slot(str, str, str, str, str, result="QVariantMap")
    def finishPractice(self, lesson_id: str, target: str, typed: str, language: str, difficulty: str):
        score = score_text(target, typed, time.monotonic() - self._started_at, language).to_dict()
        stars = 3 if score["accuracy"] >= 98 else 2 if score["accuracy"] >= 90 else 1
        score["stars"] = stars
        self.storage.save_result(lesson_id, language, score, stars, difficulty)
        self._last_result = score
        self.resultChanged.emit()
        self.progressChanged.emit()
        self.lessonsChanged.emit()
        return score

    @Slot(str, int, float, str, int, float)
    def saveGameScore(self, game: str, score_value: int, elapsed: float, difficulty: str,
                      combo: int, accuracy: float):
        score = {"accuracy": accuracy, "speed": float(score_value), "speed_unit": "分",
                 "errors": 0, "elapsed_seconds": elapsed, "correct": score_value}
        self.storage.save_result("game-" + game, "game", score,
                                 min(3, max(1, score_value // 10)), difficulty, "game", combo)
        self.progressChanged.emit()

    @Property("QVariantMap", constant=True)
    def difficultyConfig(self):
        return DIFFICULTIES

    @Property("QVariantMap", constant=True)
    def gameConfig(self):
        return GAME_CONFIG

    @Slot(str, result=str)
    def moduleDifficulty(self, module: str) -> str:
        return self.storage.get_setting("difficulty_" + module, "normal")

    @Slot(str, str)
    def setModuleDifficulty(self, module: str, difficulty: str):
        if difficulty in DIFFICULTIES:
            self.storage.set_setting("difficulty_" + module, difficulty)
            self.difficultyChanged.emit()

    @Slot(str)
    def playFeedback(self, kind: str):
        if self.soundEnabled and kind in {"complete", "hit", "error"}:
            QApplication.beep()

    @Slot()
    def importText(self):
        path, _ = QFileDialog.getOpenFileName(None, "导入练习文本", "", "文本文件 (*.txt)")
        if not path:
            return
        text = Path(path).read_text(encoding="utf-8-sig").strip()
        if not text:
            return
        language = "zh" if any("\u4e00" <= c <= "\u9fff" for c in text) else "en"
        self._lessons.append({"id": "custom-" + str(int(time.time())), "title": Path(path).stem,
                              "subtitle": "自定义导入课程", "language": language,
                              "level": "自定义", "keys": "", "text": text[:3000],
                              "source": "用户导入"})
        self.lessonsChanged.emit()

    @Slot()
    def exportBackup(self):
        path, _ = QFileDialog.getSaveFileName(None, "导出学习备份", "dazi-backup.json", "JSON (*.json)")
        if path:
            self.storage.export_to(Path(path))

    @Slot()
    def importBackup(self):
        path, _ = QFileDialog.getOpenFileName(None, "恢复学习备份", "", "JSON (*.json)")
        if path:
            self.storage.import_from(Path(path))
            self.progressChanged.emit()
            self.lessonsChanged.emit()
            self.settingsChanged.emit()

    @Slot()
    def resetProgress(self):
        self.storage.reset()
        self.progressChanged.emit()
        self.lessonsChanged.emit()
