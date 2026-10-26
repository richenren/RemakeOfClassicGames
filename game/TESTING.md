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

## 当前结果状态

- [x] 已编写自动化测试脚本与 CI 工作流。
- [ ] Godot Headless 导入 / 解析测试通过。
- [ ] 游戏逻辑烟雾测试通过。
- [ ] 主场景启动测试通过。
- [ ] Windows 交互试玩。
- [ ] Android 真机触控与性能测试。

注意：测试代码已提交，但只有 GitHub Actions 实际执行成功后，才可把前三项标记为通过。当前开发容器没有安装 Godot，无法声称已经在本地完成引擎级运行测试。
