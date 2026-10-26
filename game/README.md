# 《镇邪录》Godot 可玩原型

这是项目的第一阶段可运行原型，使用 Godot 4.x + GDScript。当前角色、怪物、地图与特效均为程序绘制的占位表现，后续可替换为正式原创素材。

## 运行方式

1. 安装 Godot 4.x 稳定版。
2. 在 Godot 项目管理器中导入本目录下的 `project.godot`。
3. 打开项目并运行主场景。

## 当前实现

- 1280×720 横屏基准视口、2D 摄像机跟随与简单义庄/荒坟占位地图。
- Windows 键盘移动（WASD 或方向键）。
- Android 触屏虚拟摇杆、镇尸诀按钮和治疗按钮。
- 基础符箓自动索敌攻击。
- 行尸、跳僵、铁甲尸三种占位敌人；敌人追踪、轻量分离、接触伤害与常驻血条。
- 玩家生命条、无伤害数字、受击无敌窗口。
- 灵气球、升级三选一与六种原型强化。
- 治疗库存（每局 2 次，每次恢复最大生命的 30%）。
- 约第 8 分钟生成占位尸王，用于验证血条和基础战斗流程。

## 测试

- 测试范围与当前状态见 [`TESTING.md`](TESTING.md)。
- 自动化测试脚本：`tests/test_smoke.gd`。
- CI 工作流：`../.github/workflows/godot-prototype-tests.yml`。
- 本地运行逻辑测试：`godot --headless --path game --script res://tests/test_smoke.gd`。
- 导入/解析检查：`godot --headless --editor --path game --quit`。
- 主场景启动检查：`godot --headless --path game --quit-after 5`。

自动化测试已通过：33 项通过、0 项失败；Headless 导入和主场景启动均通过。Windows 与 Android 实机测试仍未完成。

## 当前未完成

- 尸王冲锋、环形震地、延迟危险区域和二阶段完整状态机。
- 两个可选角色、正式角色动画、正式怪物与地图素材。
- 法坛事件、完整六个攻击技能、法器、主动道术正式成长、局外功德/境界。
- 本地多存档、NAS 同步、Android APK 导出与真机性能验证。

## 操作

| 操作 | 输入 |
| --- | --- |
| 移动 | WASD / 方向键 |
| 镇尸诀 | Space |
| 治疗 | E |
| 暂停/继续 | Esc |
| 升级选卡 | 点击卡片或按 1/2/3 |
| 结束后重新开始 | R |

## 重要说明

- 本目录是原型，不是完整 V0.1 交付版本。
- 数值仅用于验证战斗闭环，后续应移入可配置资源并通过试玩平衡。
- Godot 4.5.1 Headless CI 已通过：工程导入/解析通过、33 项游戏逻辑测试通过且 0 失败、主场景启动通过（[查看测试运行](https://github.com/richenren/RemakeOfClassicGames/actions/runs/40261370130)）。Windows 交互试玩和 Android 真机验证尚未完成。
