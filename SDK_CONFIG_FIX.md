# DevEco Studio SDK 配置修复指南

## 问题描述
即使在 DevEco Studio 中右键运行测试，仍然出现：
```
> hvigor ERROR: Unable to find 'DEVECO_SDK_HOME' in the system environment path.
```

## 解决方案

### 方法1：检查和修复 DevEco Studio SDK 配置

#### 步骤1：检查 SDK 配置
1. 打开 DevEco Studio
2. 进入设置：
   - **Windows/Linux**: File → Settings
   - **macOS**: DevEco Studio → Preferences
3. 导航到：Appearance & Behavior → System Settings → HarmonyOS SDK
4. 检查 SDK Location 是否正确设置

#### 步骤2：重新设置 SDK 路径
如果 SDK Location 为空或路径不正确：
1. 点击 "Edit" 或 "..." 按钮
2. 选择正确的 HarmonyOS SDK 安装路径
3. 通常路径类似于：
   - **macOS**: `/Users/[username]/Huawei/Sdk`
   - **Windows**: `C:\Users\[username]\AppData\Local\Huawei\Sdk`
4. 点击 "Apply" 和 "OK"

#### 步骤3：验证 SDK 组件
确保以下组件已安装：
- ✅ HarmonyOS SDK (API 版本对应你的项目)
- ✅ Native SDK
- ✅ Toolchains
- ✅ Preview

### 方法2：重新安装/更新 SDK

#### 如果 SDK 路径不存在：
1. 在 DevEco Studio 中：Settings → HarmonyOS SDK
2. 点击 "SDK Manager"
3. 下载并安装所需的 SDK 组件
4. 等待安装完成后重启 DevEco Studio

### 方法3：手动设置环境变量（临时解决）

#### macOS/Linux:
```bash
# 找到你的 SDK 路径，通常在：
ls ~/Huawei/Sdk
# 或
ls /Applications/DevEco-Studio.app/Contents/sdk

# 设置环境变量（替换为实际路径）
export DEVECO_SDK_HOME=~/Huawei/Sdk
# 或
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk

# 验证设置
echo $DEVECO_SDK_HOME
ls $DEVECO_SDK_HOME
```

#### Windows:
```cmd
# 在命令提示符中设置（替换为实际路径）
set DEVECO_SDK_HOME=C:\Users\%USERNAME%\AppData\Local\Huawei\Sdk

# 验证设置
echo %DEVECO_SDK_HOME%
dir %DEVECO_SDK_HOME%
```

### 方法4：项目级配置

#### 创建 local.properties 文件
在项目根目录创建 `local.properties` 文件：

```properties
# 替换为你的实际 SDK 路径
sdk.dir=/Users/[username]/Huawei/Sdk
# 或 Windows 路径
# sdk.dir=C:\\Users\\[username]\\AppData\\Local\\Huawei\\Sdk
```

### 方法5：重启和清理

#### 步骤1：清理项目
```bash
# 删除构建缓存
rm -rf .hvigor
rm -rf build
rm -rf entry/build
rm -rf lyrics_view/build
```

#### 步骤2：重启 DevEco Studio
1. 完全关闭 DevEco Studio
2. 重新打开项目
3. 等待项目同步完成

### 方法6：检查项目配置文件

#### 检查 hvigorfile.ts
确保项目根目录的 `hvigorfile.ts` 配置正确：

```typescript
export { hapTasks } from '@ohos/hvigor-ohos-plugin';
```

#### 检查 build-profile.json5
确保 `build-profile.json5` 中的配置正确：

```json5
{
  "app": {
    "signingConfigs": [],
    "products": [
      {
        "name": "default",
        "signingConfig": "default"
      }
    ]
  },
  "modules": [
    {
      "name": "entry",
      "srcPath": "./entry"
    },
    {
      "name": "lyrics_view",
      "srcPath": "./lyrics_view"
    }
  ]
}
```

## 常见问题排查

### Q1: SDK 路径找不到
**检查步骤：**
1. 确认 HarmonyOS SDK 已正确安装
2. 检查安装路径是否存在
3. 确认路径权限正确

### Q2: 多个 DevEco Studio 版本
**解决方案：**
1. 卸载旧版本的 DevEco Studio
2. 重新安装最新版本
3. 重新配置 SDK 路径

### Q3: 权限问题
**解决方案：**
```bash
# macOS/Linux - 修复权限
chmod -R 755 ~/Huawei/Sdk
```

### Q4: 网络问题导致 SDK 下载失败
**解决方案：**
1. 检查网络连接
2. 配置代理（如需要）
3. 手动下载 SDK 并解压到指定目录

## 验证修复

### 步骤1：检查环境
在 DevEco Studio 终端中运行：
```bash
echo $DEVECO_SDK_HOME
# 或 Windows
echo %DEVECO_SDK_HOME%
```

### 步骤2：测试构建
```bash
# 清理并重新构建
./hvigorw clean
./hvigorw assembleHap
```

### 步骤3：运行测试
在 DevEco Studio 中：
1. 右键点击 `entry/src/ohosTest/ets/test/` 目录
2. 选择 "Run All Tests"

## 如果问题仍然存在

1. **重新安装 DevEco Studio**：完全卸载后重新安装
2. **检查系统环境**：确保系统满足 HarmonyOS 开发要求
3. **联系技术支持**：提供详细的错误日志和系统信息

## 成功标志

当看到以下输出时，表示问题已解决：
```
> hvigor Finished :entry:ohosTest@PreBuild...
> hvigor Finished :lyrics_view:default@PreBuild...
```

而不是：
```
> hvigor ERROR: Unable to find 'DEVECO_SDK_HOME'
```
