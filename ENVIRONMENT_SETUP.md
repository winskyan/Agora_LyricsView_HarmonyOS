# HarmonyOS 开发环境配置指南

## 问题诊断

当前遇到的错误：
```
> hvigor ERROR: Unable to find 'DEVECO_SDK_HOME' in the system environment path.
> hvigor ERROR: BUILD FAILED in 21 ms
```

## 解决方案

### 方法1：在 DevEco Studio 中运行（推荐）

1. **打开 DevEco Studio**
2. **导入项目**：File → Open → 选择项目根目录
3. **等待项目同步完成**
4. **运行测试**：
   - 右键点击 `entry/src/ohosTest/ets/test/` 目录
   - 选择 "Run All Tests"
   - 或者右键单个测试文件选择 "Run"

### 方法2：配置命令行环境

#### 步骤1：找到 HarmonyOS SDK 路径
在 DevEco Studio 中：
1. File → Settings (macOS: DevEco Studio → Preferences)
2. Appearance & Behavior → System Settings → HarmonyOS SDK
3. 复制 SDK Location 路径

#### 步骤2：设置环境变量

**macOS/Linux:**
```bash
# 临时设置（当前终端会话有效）
export DEVECO_SDK_HOME=/path/to/your/harmonyos/sdk

# 永久设置（添加到 ~/.bashrc 或 ~/.zshrc）
echo 'export DEVECO_SDK_HOME=/path/to/your/harmonyos/sdk' >> ~/.zshrc
source ~/.zshrc
```

**Windows:**
```cmd
# 临时设置
set DEVECO_SDK_HOME=C:\path\to\your\harmonyos\sdk

# 永久设置：通过系统环境变量设置
```

#### 步骤3：验证环境
```bash
echo $DEVECO_SDK_HOME
ls $DEVECO_SDK_HOME
```

#### 步骤4：运行测试
```bash
cd /path/to/your/project
./hvigorw assembleHap --mode module -p module=entry@ohosTest -p isOhosTest=true -p buildMode=test
```

### 方法3：使用 DevEco Studio 内置终端

1. 在 DevEco Studio 中打开项目
2. 打开内置终端：View → Tool Windows → Terminal
3. 在内置终端中运行命令（环境变量已自动配置）

## 常见问题

### Q1: SDK 路径找不到
**A:** 确保已安装 HarmonyOS SDK，并在 DevEco Studio 中正确配置

### Q2: 权限问题
**A:** 确保对 SDK 目录有读取权限：
```bash
chmod -R 755 /path/to/harmonyos/sdk
```

### Q3: 路径包含空格
**A:** 使用引号包围路径：
```bash
export DEVECO_SDK_HOME="/path/with spaces/harmonyos/sdk"
```

### Q4: 多个 SDK 版本
**A:** 确保指向正确的 SDK 版本目录

## 测试运行状态

当前测试文件状态：
- ✅ `Ability.test.ets` - 基础能力测试
- ✅ `LyricsInstrumentedTest.test.ets` - 歌词解析测试
- ✅ `List.test.ets` - 测试套件入口

## 推荐工作流程

1. **优先使用 DevEco Studio**：最简单，环境自动配置
2. **如需命令行**：先在 DevEco Studio 中确认项目可以构建
3. **逐步验证**：先运行简单测试，再运行复杂测试

## 下一步

1. 按照上述方法配置环境
2. 在 DevEco Studio 中运行测试
3. 如果仍有问题，检查 HarmonyOS SDK 版本兼容性
