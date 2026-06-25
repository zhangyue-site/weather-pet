# Weather Pet TDD 测试文档

## 测试框架

本项目使用自定义的 TDD 测试框架，基于 GDScript 实现。

### 测试结构

```
tests/
├── test_framework.gd    # 测试框架基类
├── test_pet_fsm.gd      # PetFSM 状态机测试
├── test_data_channel.gd # DataChannel 数据中枢测试
├── test_prop_system.gd  # PropSystem 道具系统测试
├── test_runner.gd       # 测试运行器
└── test_runner.tscn     # 测试场景
```

### 运行测试

#### 方法 1: 使用脚本
```bash
cd godot_project
./run_tests.sh
```

#### 方法 2: 使用 Godot 命令行
```bash
cd godot_project
godot --headless --path . --script res://tests/test_runner.gd
```

#### 方法 3: 在 Godot 编辑器中运行
1. 打开 Godot 编辑器
2. 打开 `tests/test_runner.tscn` 场景
3. 按 F5 运行

### 测试覆盖范围

#### PetFSM 状态机测试
- ✓ 初始状态验证
- ✓ 状态转换机制
- ✓ 优先级系统
- ✓ 临时状态自动重置
- ✓ 天气状态转换
- ✓ 时间状态转换
- ✓ 触摸交互响应
- ✓ 状态标签显示

#### DataChannel 数据中枢测试
- ✓ 初始值验证
- ✓ 天气数据更新
- ✓ 时间数据更新
- ✓ 节日数据更新
- ✓ 信号强度更新
- ✓ 电池状态更新
- ✓ 预设城市列表
- ✓ 城市切换功能
- ✓ 位置模式管理

#### PropSystem 道具系统测试
- ✓ 初始状态验证
- ✓ 道具显示/隐藏
- ✓ 天气道具逻辑
- ✓ 时间道具逻辑
- ✓ 节日道具逻辑
- ✓ 道具刷新逻辑

### 测试输出示例

```
=== Weather Pet TDD Test Suite ===

Loading: res://tests/test_pet_fsm.gd
Running: Initial state is IDLE
Running: State transition works
...
=== Test Results ===
Passed: 8
Failed: 0
Total: 8

Loading: res://tests/test_data_channel.gd
...
=== Final Results ===
Total Passed: 24
Total Failed: 0
Total Tests: 24
✓ All tests passed!
```

### 添加新测试

1. 在 `tests/` 目录创建新的测试文件
2. 继承 `TestFramework` 类
3. 实现 `_ready()` 函数，运行测试
4. 在 `test_runner.gd` 中添加新测试路径

示例:
```gdscript
extends TestFramework

func _ready():
    run_test("Test name", test_function)
    finish()

func test_function():
    assert_eq(actual, expected, "Error message")
```

### 测试断言

- `assert_eq(actual, expected, message)` - 相等断言
- `assert_true(condition, message)` - 真值断言
- `assert_false(condition, message)` - 假值断言
- `assert_not_null(value, message)` - 非空断言
- `assert_null(value, message)` - 空值断言

### CI/CD 集成

可以在 CI/CD 流程中添加测试步骤:

```yaml
# GitHub Actions 示例
- name: Run tests
  run: |
    cd godot_project
    ./run_tests.sh
```

### 故障排除

#### 问题: Godot 命令未找到
**解决方案**: 确保 Godot 4.4 已安装并添加到 PATH

#### 问题: 测试加载失败
**解决方案**: 检查测试文件路径是否正确

#### 问题: 测试超时
**解决方案**: 检查测试中是否有无限循环或阻塞操作

### 最佳实践

1. 每个测试应该独立运行
2. 测试应该快速完成
3. 测试应该有清晰的错误消息
4. 测试应该覆盖边界条件
5. 测试应该易于理解和维护
