# 打字星球

一个无广告、完全离线的现代打字学习软件，面向 Windows 与 macOS。内置英文指法、拼音中文、60 篇分级中文内容，以及字母雨、打字竞速、单词太空战、警察抓小偷四个小游戏。

## 0.4.0 版特点

- 新增原创“警察抓小偷”英文打字追击游戏：准确输入路标推进警车，穿越多个街区；打错会消耗机会，路障会拉开距离，还有倒计时；胜负与连击计入本机成绩。
- 导入自定义文章时可选择 TXT 文件、修改默认标题、填写作者，并指定简单、普通或困难。
- 导入成功或重复时会明确提示。
- 支持按标题、作者和正文搜索文章；相同正文不会被重复导入。
- 自定义文章持久保存在本机，可使用首次删除时设置的家长密码安全删除。
- 课程和每款游戏都可独立选择简单、普通、困难，并记忆上次选择。
- 全尺寸八指分色键盘会同步高亮目标键、Shift 组合键和对应手指。
- 中文内容可按原创短文、古诗、古文、现代公版作品筛选。
- 游戏难度会改变目标类型、生命、生成速度、AI 对手和计分规则；追击关卡分别有 5/6/7 个街区以及不同逃脱倒计时。
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

## 打包与下载

```bash
pyinstaller packaging/dazi.spec --noconfirm
```

PyInstaller 不能跨系统构建：在 Windows 运行会产出 Windows 程序，在 macOS 运行会产出 `打字星球.app`。macOS 应将 `.app` 整包压缩为 ZIP，Windows 则将完整 `dist/打字星球/` 文件夹压缩为 ZIP（不仅仅是 `.exe`，还包含其依赖目录）。

GitHub Actions 的 **Build and publish desktop apps** 工作流支持：

- 推送 `v*` 标签时分别在 Windows x64 和 Apple 芯片 macOS 环境构建，并发布到对应 Release。
- 在 Actions 页面手动运行，输入已有版本标签（例如 `v0.4.0`），选择 `windows`、`macos` 或 `both`，即可为现有 Release 补充对应平台的下载包；构建源码固定为该标签，不移动旧标签。
- 发布前运行测试；Windows 可执行文件经过原生启动冒烟检查；ZIP 附带 SHA-256 校验文件。

### v0.4.0 下载

- [Windows x64 便携版](https://github.com/hubeixulu/dazi/releases/download/v0.4.0/dazi-v0.4.0-windows-x64.zip)（约 176 MiB）：完整解压 ZIP 后运行文件夹中的 `打字星球.exe`，不要只复制 EXE。该包已在 GitHub Windows 环境通过测试和启动冒烟检查。
- [Windows SHA-256 校验文件](https://github.com/hubeixulu/dazi/releases/download/v0.4.0/dazi-v0.4.0-windows-x64.zip.sha256)。
- [Mac Apple 芯片版](https://github.com/hubeixulu/dazi/releases/download/v0.4.0/dazi-v0.4.0-macos-arm64.zip)：解压后打开 `打字星球.app`。
- [全部 Releases](https://github.com/hubeixulu/dazi/releases)。

构建产物未经开发者签名/公证，首次启动可能出现系统安全提示。

## 内容说明

基础键位与适龄短文为原创内容。古典和近现代作品逐篇记录作者、来源版本及公版说明，不复制教材注释、插图或编排。新增内置文章前必须核验版权；用户自行导入的文本只持久保存在本机，不会上传。
