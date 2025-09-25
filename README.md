# Agora LyricsView HarmonyOS

[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-API%209+-blue.svg)](https://developer.harmonyos.com/)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.0-orange.svg)](releases/)

一个功能强大的 HarmonyOS 歌词显示组件，支持卡拉OK模式、评分系统、粒子特效等丰富功能。

## 🌟 功能特性

- 🎵 **歌词显示**: 支持多种歌词格式，流畅的滚动效果
- 🎤 **卡拉OK模式**: 实时高亮显示，支持音调匹配
- 🎯 **评分系统**: 智能评分算法，实时反馈
- 🎨 **粒子特效**: 丰富的视觉效果，提升用户体验
- 📱 **触摸交互**: 支持手势操作，拖拽定位
- 🔄 **动画过渡**: 平滑的动画效果，同步性能优化
- 🎨 **自定义样式**: 丰富的样式配置选项
- 📦 **HAR 包支持**: 可编译为 HAR 包，便于集成

## 📋 目录

- [快速开始](#-快速开始)
- [安装配置](#-安装配置)
- [使用方法](#-使用方法)
- [API 文档](#-api-文档)
- [构建指南](#-构建指南)
- [版本管理](#-版本管理)
- [签名发布](#-签名发布)
- [故障排除](#-故障排除)
- [贡献指南](#-贡献指南)

## 🚀 快速开始

### 环境要求

- **HarmonyOS**: API 9 或更高版本
- **DevEco Studio**: 4.0 或更高版本
- **Node.js**: 16.0 或更高版本

### 快速体验

1. **克隆项目**
   ```bash
   git clone https://github.com/AgoraIO-Community/LyricsView-HarmonyOS.git
   cd LyricsView-HarmonyOS/Agora_LyricsView_HarmonyOS
   ```

2. **运行示例**
   ```bash
   # 使用源码模式运行
   ./build.sh switch source
   hvigorw assembleHap
   ```

3. **安装到设备**
   - 在 DevEco Studio 中打开项目
   - 连接 HarmonyOS 设备或模拟器
   - 点击运行按钮

## 📦 安装配置

### 方式一：使用 HAR 包（推荐）

1. **编译 HAR 包**
   ```bash
   ./build.sh har release
   ```

2. **在项目中添加依赖**
   ```json5
   // oh-package.json5
   {
     "dependencies": {
       "lyrics_view": "file:./path/to/Agora-LyricsView-HarmonyOS-1.0.0.har"
     }
   }
   ```

3. **导入组件**
   ```typescript
   import { LyricsView, ScoringView, LyricsViewVersion } from 'lyrics_view';
   ```

### 方式二：使用源码

1. **复制源码**
   ```bash
   cp -r lyrics_view /path/to/your/project/
   ```

2. **配置依赖**
   ```json5
   // oh-package.json5
   {
     "dependencies": {
       "lyrics_view": "file:./lyrics_view"
     }
   }
   ```

## 🎯 使用方法

### 基础歌词显示

```typescript
@ComponentV2
struct LyricsExample {
  build() {
    Column() {
      LyricsView({
        textSize: 16,
        currentLineTextSize: 20,
        currentLineTextColor: '#FFFFFF',
        currentLineHighlightedTextColor: '#FF6B35',
        previousLineTextColor: '#CCCCCC',
        upcomingLineTextColor: '#999999'
      })
    }
  }
}
```

### 卡拉OK模式

```typescript
@ComponentV2
struct KaraokeExample {
  build() {
    Column() {
      KaraokeView({
        textSize: 18,
        currentLineTextSize: 24,
        enableScoring: true,
        enableParticleEffect: true,
        onScoringUpdate: (score: number) => {
          console.log(`当前得分: ${score}`);
        }
      })
    }
  }
}
```

### 评分系统

```typescript
@ComponentV2
struct ScoringExample {
  build() {
    Column() {
      ScoringView({
        enableRealTimeScoring: true,
        scoringAlgorithm: new DefaultScoringAlgorithm(),
        onScoreChanged: (score: number, level: string) => {
          console.log(`得分: ${score}, 等级: ${level}`);
        }
      })
    }
  }
}
```

## 📚 API 文档

### LyricsView 组件

#### 属性配置

| 属性名 | 类型 | 默认值 | 描述 |
|--------|------|--------|------|
| `textSize` | `number` | `16` | 普通歌词字体大小 |
| `currentLineTextSize` | `number` | `20` | 当前行字体大小 |
| `currentLineTextColor` | `string` | `'#FFFFFF'` | 当前行文字颜色 |
| `currentLineHighlightedTextColor` | `string` | `'#FF6B35'` | 当前行高亮颜色 |
| `previousLineTextColor` | `string` | `'#CCCCCC'` | 上一行文字颜色 |
| `upcomingLineTextColor` | `string` | `'#999999'` | 下一行文字颜色 |
| `enableAnimation` | `boolean` | `true` | 是否启用动画效果 |
| `animationDuration` | `number` | `300` | 动画持续时间(ms) |

#### 回调方法

| 方法名 | 参数 | 描述 |
|--------|------|------|
| `onLineChanged` | `(currentLine: number, totalLines: number)` | 当前行变化回调 |
| `onProgressChanged` | `(progress: number)` | 播放进度变化回调 |
| `onLyricsLoaded` | `(lyrics: LyricModel[])` | 歌词加载完成回调 |

### KaraokeView 组件

#### 属性配置

| 属性名 | 类型 | 默认值 | 描述 |
|--------|------|--------|------|
| `enableScoring` | `boolean` | `false` | 是否启用评分 |
| `enableParticleEffect` | `boolean` | `false` | 是否启用粒子特效 |
| `pitchSensitivity` | `number` | `0.8` | 音调敏感度 |
| `scoringThreshold` | `number` | `0.7` | 评分阈值 |

#### 回调方法

| 方法名 | 参数 | 描述 |
|--------|------|------|
| `onScoringUpdate` | `(score: number, accuracy: number)` | 评分更新回调 |
| `onPitchMatched` | `(pitch: number, targetPitch: number)` | 音调匹配回调 |

### 版本信息 API

```typescript
import { LyricsViewVersion } from 'lyrics_view';

// 获取版本信息
const version = LyricsViewVersion.VERSION;              // "1.0.0"
const versionName = LyricsViewVersion.VERSION_NAME;     // "Agora-LyricsView-HarmonyOS-1.0.0"
const versionInfo = LyricsViewVersion.getVersionInfo(); // 详细版本信息

// 版本兼容性检查
const isCompatible = LyricsViewVersion.isCompatibleWith("1.0.0");
```

## 🏗️ 构建指南

### 统一构建脚本

项目提供了统一的构建脚本 `build.sh`，集成了所有构建功能：

```bash
# 显示帮助信息
./build.sh help

# 同步版本号
./build.sh sync

# 编译 HAR 包
./build.sh har debug          # Debug 版本
./build.sh har release        # Release 版本

# 切换模式
./build.sh switch source      # 源码模式
./build.sh switch sdk         # HAR 包模式

# 发布 HAR 包
./build.sh release            # 使用代码中的版本号
./build.sh release 1.1.0      # 指定版本号

# 清理构建文件
./build.sh clean
```

### 构建流程详解

#### 1. Debug vs Release 版本

| 特性 | Debug 版本 | Release 版本 |
|------|------------|--------------|
| **代码混淆** | ❌ 关闭 | ✅ 启用 |
| **调试符号** | ✅ 保留 | ❌ 移除 |
| **文件大小** | 较大 (~646KB) | 较小 (~545KB) |
| **用途** | 开发测试 | 正式发布 |
| **性能** | 调试友好 | 运行优化 |

#### 2. 文件命名规范

- **Debug 版本**: `Agora-LyricsView-HarmonyOS-1.0.0-debug.har`
- **Release 版本**: `Agora-LyricsView-HarmonyOS-1.0.0.har`

#### 3. 构建配置

**Debug 配置**:
```json5
{
  "name": "debug",
  "arkOptions": {
    "obfuscation": {
      "ruleOptions": {
        "enable": false  // 不混淆，便于调试
      }
    }
  },
  "nativeLib": {
    "debugSymbol": {
      "strip": false  // 保留调试符号
    }
  }
}
```

**Release 配置**:
```json5
{
  "name": "release",
  "arkOptions": {
    "obfuscation": {
      "ruleOptions": {
        "enable": true  // 启用混淆
      }
    }
  },
  "nativeLib": {
    "debugSymbol": {
      "strip": true  // 移除调试符号
    }
  }
}
```

## 📋 版本管理

### 版本号管理

版本号统一在 `lyrics_view/src/main/ets/constants/Version.ets` 中定义：

```typescript
export class LyricsViewVersion {
  /** 主版本号 */
  public static readonly MAJOR_VERSION: number = 1;
  
  /** 次版本号 */
  public static readonly MINOR_VERSION: number = 0;
  
  /** 修订版本号 */
  public static readonly PATCH_VERSION: number = 0;
  
  /** 预发布标识 */
  public static readonly PRE_RELEASE: string = "";
  
  /** 构建号 */
  public static readonly BUILD_NUMBER: string = "";
}
```

### 版本更新流程

1. **修改版本号**
   ```typescript
   // 升级到 1.1.0
   public static readonly MINOR_VERSION: number = 1;
   ```

2. **同步版本号**
   ```bash
   ./build.sh sync
   ```

3. **构建和发布**
   ```bash
   ./build.sh release
   ```

### 语义化版本控制

- **主版本号 (MAJOR)**: 不兼容的 API 修改
- **次版本号 (MINOR)**: 向下兼容的功能性新增
- **修订号 (PATCH)**: 向下兼容的问题修正

## 🔐 签名发布

### 签名配置

项目已配置 HarmonyOS 签名系统：

```json5
{
  "signingConfigs": [
    {
      "name": "default",
      "type": "HarmonyOS",
      "material": {
        "certpath": "build-profile.json5.p7b",
        "storePassword": "...",
        "keyAlias": "debugKey",
        "keyPassword": "...",
        "profile": "build-profile.json5.p7b",
        "signAlg": "SHA256withECDSA",
        "storeFile": "build-profile.json5.p12"
      }
    }
  ]
}
```

### 发布流程

1. **编译 Release 版本**
   ```bash
   ./build.sh har release
   ```

2. **正式发布**
   ```bash
   ./build.sh release
   ```

3. **验证发布包**
   ```bash
   # 检查文件完整性
   shasum -c releases/v1.0.0/Agora-LyricsView-HarmonyOS-1.0.0.har.sha256
   ```

### 发布目录结构

```
releases/
└── v1.0.0/
    ├── Agora-LyricsView-HarmonyOS-1.0.0.har          # HAR 包
    ├── Agora-LyricsView-HarmonyOS-1.0.0.har.sha256   # 校验文件
    └── RELEASE_NOTES.md                              # 发布说明
```

## 🛠️ 故障排除

### 常见问题

#### 1. 编译错误

**问题**: `hvigor ERROR: BUILD FAILED`
```bash
# 解决方案
./build.sh clean          # 清理构建文件
./build.sh har release    # 重新编译
```

**问题**: `ArkTS Compiler Error`
```bash
# 检查语法错误
# ArkTS 不支持解构赋值，需要使用传统方式
const [a, b, c] = array;  // ❌ 错误
const a = array[0];       // ✅ 正确
const b = array[1];
const c = array[2];
```

#### 2. 版本同步问题

**问题**: 版本号不一致
```bash
# 手动同步版本号
./build.sh sync
```

**问题**: 无法提取版本号
```bash
# 检查版本文件格式
grep "VERSION:" lyrics_view/src/main/ets/constants/Version.ets
```

#### 3. 模式切换问题

**问题**: HAR 包不存在
```bash
# 先编译 HAR 包
./build.sh har release
# 再切换模式
./build.sh switch sdk
```

**问题**: 依赖解析失败
```bash
# 清理缓存
./build.sh clean
hvigorw clean
```

#### 4. 签名问题

**问题**: 签名失败
- 检查证书路径和密码
- 确认证书有效期
- 验证签名配置格式

**问题**: 混淆问题
- 检查混淆规则文件
- 验证 keep 规则配置
- 测试混淆后的功能

### 调试技巧

1. **启用详细日志**
   ```bash
   # 在构建时添加详细输出
   ./build.sh har debug
   ```

2. **检查构建产物**
   ```bash
   # 查看生成的文件
   ls -la lyrics_view/build/default/outputs/default/
   ```

3. **验证 HAR 包内容**
   ```bash
   # 解压查看 HAR 包内容
   unzip -l Agora-LyricsView-HarmonyOS-1.0.0.har
   ```

## 🤝 贡献指南

### 开发环境设置

1. **Fork 项目**
   ```bash
   git clone https://github.com/your-username/LyricsView-HarmonyOS.git
   ```

2. **创建开发分支**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **安装依赖**
   ```bash
   ./build.sh sync
   ```

### 代码规范

1. **ArkTS 语法**: 遵循 HarmonyOS ArkTS 开发规范
2. **命名规范**: 使用驼峰命名法
3. **注释规范**: 使用 JSDoc 格式注释
4. **提交规范**: 使用 Conventional Commits 格式

### 测试要求

1. **单元测试**: 确保新功能有对应的单元测试
2. **集成测试**: 在真实设备上测试
3. **性能测试**: 确保不影响现有性能
4. **兼容性测试**: 测试不同 HarmonyOS 版本

### 提交流程

1. **代码检查**
   ```bash
   # 运行代码检查
   ./build.sh clean
   ./build.sh har debug
   ```

2. **提交代码**
   ```bash
   git add .
   git commit -m "feat: add new feature"
   git push origin feature/your-feature-name
   ```

3. **创建 Pull Request**
   - 详细描述修改内容
   - 添加测试截图或视频
   - 确保通过所有检查

## 📄 许可证

本项目采用 [Apache License 2.0](LICENSE) 许可证。

## 🙏 致谢

- [HarmonyOS 开发团队](https://developer.harmonyos.com/)
- [Agora 技术团队](https://www.agora.io/)
- 所有贡献者和用户

## 📞 技术支持

- **GitHub Issues**: [提交问题](https://github.com/AgoraIO-Community/LyricsView-HarmonyOS/issues)
- **官方文档**: [HarmonyOS 开发文档](https://developer.harmonyos.com/)
- **技术交流**: 加入 HarmonyOS 开发者社群

---

<div align="center">
  <p>Made with ❤️ by Agora</p>
  <p>
    <a href="https://www.agora.io/">官网</a> •
    <a href="https://github.com/AgoraIO-Community">GitHub</a> •
    <a href="https://developer.harmonyos.com/">HarmonyOS</a>
  </p>
</div>