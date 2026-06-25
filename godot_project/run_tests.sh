#!/bin/bash

# Weather Pet TDD Test Runner
# 使用方法: ./run_tests.sh

echo "=== Weather Pet TDD Test Suite ==="
echo ""

# 检查 Godot 是否安装
if ! command -v godot &> /dev/null; then
    echo "Error: Godot not found in PATH"
    echo "Please install Godot 4.4 or add it to PATH"
    exit 1
fi

# 运行测试场景
echo "Running tests..."
godot --headless --path . res://tests/test_runner.tscn

# 检查退出码
if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Tests completed successfully"
else
    echo ""
    echo "✗ Tests failed"
    exit 1
fi
