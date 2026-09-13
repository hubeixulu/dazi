# 打字星球

一个无广告、完全离线的现代打字学习软件，面向 Windows 与 macOS。内置英文指法、拼音中文、60 篇分级中文内容，以及字母雨、打字竞速、单词太空战三个小游戏。

## 0.3.1 版特点

- 导入自定义文章时可选择 TXT 文件、修改默认标题、填写作者，并指定简单、普通或困难。
- 导入成功或重复时会明确提示。
- 支持按标题、作者和正文搜索文章；相同正文不会被重复导入。
- 自定义文章持久保存在本机，可使用首次删除时设置的家长密码安全删除。
- 课程和每款游戏都可独立选择简单、普通、困难，并记忆上次选择。
- 全尺寸八指分色键盘会同步高亮目标键、Shift 组合键和对应手指。
- 中文内容可按原创短文、古诗、古文、现代公版作品筛选。
- 游戏难度会改变目标类型、生命、生成速度、AI 对手和计分规则。
- 旧版数据库自动迁移，旧成绩保留在“普通”难度下。

## 开发运行

需要 Python 3.11–3.13：

```bash
python3 -m venv .venv
source .venv/bin/activate            # Windows: .venv\Scripts\activate
python -m pip install -r requirements.txt
python -m dazi
```

依赖版本统一维护在 `pyproject.toml` 中；`requirements.txt` 会安装程序本体以及测试、打包所需工具。

运行不依赖网络，学习数据保存在系统应用数据目录。可在设置中导出或恢复 JSON 备份；课程页支持导入 UTF-8 TXT 文件。

## 测试

```bash
pytest
```

## 打包

```bash
pyinstaller packaging/dazi.spec --noconfirm
```

必须在目标系统上分别打包：Windows 产出 `打字星球.exe`，macOS 产出 `打字星球.app`。发布前建议配置 Windows Authenticode 与 Apple Developer ID 签名。

## 内容说明

基础键位与适龄短文为原创内容。古典和近现代作品逐篇记录作者、来源版本及公版说明，不复制教材注释、插图或编排。新增内置文章前必须核验版权；用户自行导入的文本只持久保存在本机，不会上传。
