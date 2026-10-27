# RemakeOfClassicGames

个人与家庭使用的 Windows 电脑 + Android 安卓手机双端 2D 游戏开发项目。

> 当前阶段：首款游戏《镇邪录》已进入 Godot 可玩原型开发。Godot 4.5.1 Headless CI 已通过，44 项逻辑与界面状态测试通过、0 项失败；Windows 基础战斗已试玩，本轮新增阶段目标 HUD、镇尸诀冷却/施放反馈与升级卡片视觉优化，仍待 Windows 目视复测。Android 真机测试不在本轮范围。

## 项目目标

- 第一款游戏类型：**2D 俯视角幸存者式 Roguelite（肉鸽）**，道士与僵尸题材，工作名《镇邪录》。
- 目标平台：**Windows 电脑与 Android 安卓手机**。当前版本只保证这两个平台可玩，不规划其他平台。
- 游戏模式：单人、离线可玩；Windows 使用键盘操作，Android 使用触屏虚拟摇杆。
- 持久化：每个存档独立；本地自动保存 + 后续家庭 NAS 同步；支持可恢复的单局快照。
- 开发：AI 辅助迭代，**免费开源工具优先**，不为简单需求引入重型框架。
- 发布：当前仅个人与家庭使用，未来是否公开发布另行决定。

## 已选择的技术方向

| 模块 | 选择 |
| --- | --- |
| 2D 引擎 | Godot 4 稳定版 |
| 脚本语言 | GDScript |
| 渲染 | Godot Compatibility，真机测试后按需调整 |
| 输入 | InputMap + Windows 键盘 / Android 触屏虚拟摇杆 |
| 本地存档 | user:// 下的版本化快照，安全替换与回退 |
| 同步 | HTTPS REST API，离线优先，失败重试 |
| 家庭服务器 | 现有群晖 NAS，优先容器化部署 |
| 服务端 | Python FastAPI |
| 数据库 | SQLite，保留升级空间 |
| 开发/版本管理 | Godot 编辑器、Cursor 或 Claude Code、Git/GitHub |
| 美术 | Krita、LibreSprite（像素画可选）、授权素材/AI 生图 |
| 音频 | Audacity、适当许可的免费音效 |

选型为项目基线，不代表所有依赖或工具均必须安装；版本号要在启动编码时固定并验证兼容性。

## 游戏原型

- [Godot 可玩原型与运行说明](game/README.md)
- [原型测试范围与结果记录](game/TESTING.md)
- [最新 Godot Headless 测试运行记录](https://github.com/richenren/RemakeOfClassicGames/actions/runs/40470964779)
- [打开 game/ 项目目录](game/)

## 文档

### 游戏设计
- [游戏内容决策索引](docs/05-游戏内容待确认.md)
- [核心玩法与局内循环](docs/06-镇邪录核心玩法与局内循环.md)
- [技能构筑与成长系统](docs/07-镇邪录技能构筑与成长系统.md)
- [敌人、地图与 Boss 设计](docs/08-镇邪录敌人地图与Boss设计.md)
- [界面、操作与反馈规范](docs/09-镇邪录界面操作与反馈规范.md)
- [角色设计与差异化](docs/10-镇邪录角色设计与差异化.md)

### 技术与实施
- [技术选型与架构](docs/01-技术选型与架构.md)
- [免费优先的工具与素材流程](docs/02-工具与素材工作流.md)
- [NAS 存档及跨端同步设计](docs/03-存档与NAS同步.md)
- [开发阶段与验收原则](docs/04-实施计划与开发规范.md)

## 约束

1. 游戏设计文档是 V0.1 规则基线；具体数值需要试玩验证，不代表已经实现或平衡。
2. 从首个可运行版本起持续验证 Windows 电脑与 Android 安卓手机。
3. 客户端不能因 NAS 不在线而无法运行；网络服务不是单局战斗的权威实时状态源。
4. 开发按“小功能 → 启动验证 → 测试 → 提交”迭代。
5. 不上传 API 密钥、证书、签名文件、生产存档或未经许可的原版游戏素材。

## 下一步

当前已在 `feat/godot-playable-prototype-v0.1` 分支建立 Godot 工程、基础战斗原型与自动化测试。Headless CI 已通过；下一步进行 Windows 图形界面与 Android 真机验证，再扩展法坛、完整尸王机制和本地多存档，NAS 同步留到 V0.2。
