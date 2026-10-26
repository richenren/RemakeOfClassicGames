# 《镇邪录》原型测试记录

## 本轮测试范围

- 工程导入与 GDScript 解析。
- 主场景启动。
- 玩家移动、生命扣除、受击无敌窗口与治疗上限。
- 行尸/跳僵/铁甲尸/Boss 的基础属性、追踪行为与 Boss 减速抗性。
- 灵气球拾取。
- 自动符箓索敌、投射物命中伤害、镇尸诀伤害与冷却。
- 治疗次数消耗、经验升级三选一、升级效果。
- Esc 暂停/继续、约 8 分钟 Boss 出场。

## 自动化执行

GitHub Actions 工作流：`.github/workflows/godot-prototype-tests.yml`

固定测试引擎：Godot 4.5.1（CI）。工作流包含：
1. Headless Editor 导入与脚本解析检查。
2. `tests/test_smoke.gd` 游戏逻辑烟雾测试。
3. 主场景 headless 启动检查。

## 最新执行结果（2026-10-26）

[GitHub Actions #12：Godot Headless 测试通过](https://github.com/richenren/RemakeOfClassicGames/actions/runs/40261370130)

- [x] Godot 4.5.1 Headless 导入与脚本解析：通过。
- [x] 游戏逻辑烟雾测试：**33 项通过，0 项失败**。
- [x] 主场景 Headless 启动：通过。
- [ ] Windows 图形界面与键盘交互试玩。
- [ ] Android 真机触控、分辨率适配与性能测试。

首轮 CI 曾发现 `main.gd` 的 `spawn_position` 类型推断解析错误，已显式声明为 `Vector2` 并复测通过。当前结果证明脚本能在 Godot 4.5.1 中导入、核心逻辑测试通过且主场景可 Headless 启动；不代表 Windows/Android 图形交互或性能已经验收。
