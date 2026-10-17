from __future__ import annotations

import json
import time
import uuid
from pathlib import Path

from PySide6.QtCore import QObject, Property, QStandardPaths, Signal, Slot
from PySide6.QtWidgets import QFileDialog
from PySide6.QtWidgets import QApplication

from .scoring import current_error_index, score_live_text, score_text
from .storage import Storage
from .difficulty import DIFFICULTIES, GAME_CONFIG
from .pursuit import PursuitGame


class Backend(QObject):
    lessonsChanged = Signal()
    progressChanged = Signal()
    resultChanged = Signal()
    settingsChanged = Signal()
    difficultyChanged = Signal()
    pursuitChanged = Signal()

    def __init__(self, resource_dir: Path, data_dir: Path | None = None):
        super().__init__()
        self.resource_dir = resource_dir
        self._lessons = json.loads((resource_dir / "lessons.json").read_text(encoding="utf-8"))
        articles_path = resource_dir / "articles.json"
        if articles_path.exists():
            self._lessons.extend(json.loads(articles_path.read_text(encoding="utf-8")))
        self._builtin_lessons = list(self._lessons)
        base = data_dir or Path(QStandardPaths.writableLocation(QStandardPaths.AppDataLocation))
        self.storage = Storage(base / "dazi.db")
        self._lessons.extend(self._custom_lessons_from_storage())
        self._started_at = time.monotonic()
        self._last_result: dict = {}
        self._pursuit = PursuitGame()
        self._pursuit_result_saved = False

    def _custom_lessons_from_storage(self) -> list[dict]:
        return [self._custom_lesson(article) for article in self.storage.custom_articles()]

    @staticmethod
    def _custom_lesson(article: dict) -> dict:
        author = article.get("author", "")
        return {
            "id": article["id"], "title": article["title"], "author": author,
            "subtitle": ("作者：" + author + " · " if author else "") + "自定义导入文章",
            "language": article["language"],
            "difficulty": article["difficulty"], "level": "自定义", "keys": "",
            "text": article["text"], "source": "用户导入",
            "content_type": "自定义文章", "is_custom": True,
        }

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

    @Property("QVariantMap", notify=pursuitChanged)
    def pursuitState(self):
        return self._pursuit.state()

    @Slot(str, result="QVariantMap")
    def pursuitStart(self, difficulty: str):
        if difficulty not in DIFFICULTIES:
            return self._pursuit.state()
        self._pursuit_result_saved = False
        state = self._pursuit.start(difficulty)
        self.pursuitChanged.emit()
        return state

    def _pursuit_update(self, state: dict) -> dict:
        if state["phase"] in {"won", "lost"} and not self._pursuit_result_saved:
            self._pursuit_result_saved = True
            self.saveGameScore("police-chase", state["score"], state["elapsed"],
                               state["difficulty"], state["best_combo"], state["accuracy"])
            self.playFeedback("complete" if state["phase"] == "won" else "error")
        self.pursuitChanged.emit()
        return state

    @Slot(str, result="QVariantMap")
    def pursuitSubmit(self, typed: str):
        return self._pursuit_update(self._pursuit.submit(typed))

    @Slot(result="QVariantMap")
    def pursuitTick(self):
        return self._pursuit_update(self._pursuit.tick())

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

    @Property(bool, notify=settingsChanged)
    def hasDeletePassword(self):
        return self.storage.has_delete_password()

    def _import_text_path(self, path: Path, difficulty: str,
                          title: str = "", author: str = "") -> dict:
        if difficulty not in DIFFICULTIES:
            return {"ok": False, "message": "请选择文章难度。"}
        try:
            text = path.read_text(encoding="utf-8-sig").strip()
        except (OSError, UnicodeError):
            return {"ok": False, "message": "无法读取文件，请确认它是 UTF-8 文本文件。"}
        if not text:
            return {"ok": False, "message": "文章内容为空，未导入。"}
        text = text[:3000]
        content_hash = self.storage.article_hash(text)
        if any(self.storage.article_hash(item.get("text", "")) == content_hash for item in self._lessons):
            return {"ok": False, "duplicate": True, "message": "这篇文章已经存在，没有重复导入。"}
        article = {
            "id": "custom-" + uuid.uuid4().hex,
            "title": title.strip() or path.stem,
            "author": author.strip(),
            "text": text,
            "language": "zh" if any("\u4e00" <= c <= "\u9fff" for c in text) else "en",
            "difficulty": difficulty,
        }
        if not self.storage.add_custom_article(article):
            return {"ok": False, "duplicate": True, "message": "这篇文章已经存在，没有重复导入。"}
        self._lessons.append(self._custom_lesson(article))
        self.lessonsChanged.emit()
        label = DIFFICULTIES[difficulty]["label"]
        return {"ok": True, "difficulty": difficulty,
                "message": f"《{article['title']}》已成功导入到“{label}”。"}

    @Slot(result="QVariantMap")
    def chooseTextFile(self):
        path, _ = QFileDialog.getOpenFileName(None, "选择练习文本", "", "文本文件 (*.txt)")
        if not path:
            return {"ok": False, "cancelled": True}
        selected = Path(path)
        return {"ok": True, "path": str(selected), "title": selected.stem,
                "filename": selected.name}

    @Slot(str, str, str, str, result="QVariantMap")
    def importTextFile(self, path: str, difficulty: str, title: str, author: str):
        if not path:
            return {"ok": False, "message": "请先选择 TXT 文件。"}
        return self._import_text_path(Path(path), difficulty, title, author)

    @Slot(str, result="QVariantMap")
    def importText(self, difficulty: str):
        selection = self.chooseTextFile()
        if not selection.get("ok"):
            return {"ok": False, "cancelled": True, "message": ""}
        return self._import_text_path(Path(selection["path"]), difficulty, selection["title"])

    @Slot(str, str, str, result="QVariantMap")
    def deleteCustomArticle(self, article_id: str, password: str, confirmation: str):
        lesson = next((item for item in self._lessons
                       if item.get("id") == article_id and item.get("is_custom")), None)
        if lesson is None:
            return {"ok": False, "message": "没有找到这篇自定义文章。"}
        if not self.storage.has_delete_password():
            if len(password) < 4:
                return {"ok": False, "message": "新密码至少需要 4 个字符。"}
            if password != confirmation:
                return {"ok": False, "message": "两次输入的密码不一致。"}
            self.storage.set_delete_password(password)
            self.settingsChanged.emit()
        elif not self.storage.verify_delete_password(password):
            return {"ok": False, "message": "密码不正确，文章未删除。"}
        if not self.storage.delete_custom_article(article_id):
            return {"ok": False, "message": "删除失败，请稍后重试。"}
        self._lessons = [item for item in self._lessons if item.get("id") != article_id]
        self.lessonsChanged.emit()
        return {"ok": True, "message": f"《{lesson['title']}》已删除。"}

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
            self._lessons = list(self._builtin_lessons) + self._custom_lessons_from_storage()
            self.progressChanged.emit()
            self.lessonsChanged.emit()
            self.settingsChanged.emit()

    @Slot()
    def resetProgress(self):
        self.storage.reset()
        self.progressChanged.emit()
        self.lessonsChanged.emit()
