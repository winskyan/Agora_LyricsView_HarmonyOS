# 快速修复指南

## 当前问题
```
> hvigor ERROR: SDK component missing. Please verify the integrity of your SDK.
```

## 立即解决方案

### 方法1：在 DevEco Studio 中重新配置项目

#### 步骤1：重新导入项目
1. 关闭 DevEco Studio
2. 重新打开 DevEco Studio
3. 选择 "Open" 而不是最近项目
4. 导航到项目根目录并打开

#### 步骤2：等待项目同步
1. 让 DevEco Studio 自动同步项目
2. 如果提示安装缺失的组件，点击 "Install"
3. 等待所有依赖下载完成

#### 步骤3：检查 SDK 配置
1. File → Project Structure
2. 检查 Project SDK 是否正确设置
3. 确保 Compile SDK Version 和 Target SDK Version 一致

### 方法2：手动修复 SDK 配置

#### 创建/更新 local.properties
确保项目根目录有 `local.properties` 文件：
```properties
sdk.dir=/Users/yanzhennan/Library/Huawei/Sdk
```

#### 更新 build-profile.json5
在项目根目录的 `build-profile.json5` 中添加：
```json5
{
  "app": {
    "signingConfigs": [],
    "compileSdkVersion": 9,
    "compatibleSdkVersion": 9,
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

### 方法3：使用 DevEco Studio 内置测试运行器

#### 步骤1：在项目视图中找到测试
1. 展开 `entry` → `src` → `ohosTest` → `ets` → `test`
2. 找到 `LyricsInstrumentedTest.test.ets`

#### 步骤2：右键运行单个测试方法
1. 打开 `LyricsInstrumentedTest.test.ets` 文件
2. 找到一个简单的测试方法（如 `useAppContext`）
3. 在方法名旁边点击绿色箭头图标
4. 或者右键选择 "Run 'useAppContext'"

### 方法4：创建简单的测试配置

#### 创建 Run Configuration
1. Run → Edit Configurations
2. 点击 "+" → "HarmonyOS Test"
3. 配置：
   - Name: "Lyrics Tests"
   - Module: "entry.ohosTest"
   - Test kind: "All in directory"
   - Directory: "entry/src/ohosTest/ets/test"
4. 点击 "Apply" 和 "OK"

### 方法5：简化测试（临时解决）

#### 创建最小测试文件
如果其他方法都不行，创建一个最简单的测试：

```typescript
// entry/src/ohosTest/ets/test/SimpleTest.test.ets
import { describe, it, expect } from '@ohos/hypium';

export default function simpleTest() {
  describe('SimpleTest', () => {
    it('basic test', 0, () => {
      expect(1 + 1).assertEqual(2);
    });
  });
}
```

然后更新 `List.test.ets`：
```typescript
import abilityTest from './Ability.test';
import simpleTest from './SimpleTest.test';

export default function testsuite() {
  abilityTest();
  simpleTest();
}
```

## 推荐执行顺序

1. **首先尝试方法1**：重新导入项目
2. **如果不行，尝试方法3**：使用内置测试运行器
3. **最后尝试方法5**：创建简化测试

## 成功标志

当你看到以下任一情况时，表示问题已解决：
- DevEco Studio 显示绿色的测试运行图标
- 测试输出窗口显示测试结果
- 没有 "SDK component missing" 错误

## 如果仍然失败

1. 检查 DevEco Studio 版本是否为最新
2. 重新安装 HarmonyOS SDK
3. 创建一个新的 HarmonyOS 项目来验证环境是否正常
