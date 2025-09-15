# HarmonyOS 歌词解析测试指南

## 概述

本文档描述了如何在 HarmonyOS 项目中运行歌词解析测试用例，这些测试用例对应 Android 项目中的 `LyricsInstrumentedTest.java`。

## 测试结构

### 测试文件位置
- **测试用例**: `entry/src/ohosTest/ets/test/LyricsInstrumentedTest.ets`
- **测试工具**: `entry/src/ohosTest/ets/utils/TestUtils.ets`
- **测试资源**: `entry/src/main/resources/rawfile/`

### 测试资源文件
在 `entry/src/main/resources/rawfile/` 目录下包含以下测试文件：

#### XML 格式歌词文件
- `810507.xml` - 张学友《吻别》，用于测试基本XML解析
- `c18228e223144247810ee511916e2207.xml` - 邓丽君《路边的野花不要采》，用于测试元数据解析

#### KRC 格式歌词文件
- `4875936889260991133.krc` - 陈奕迅《十年》，用于测试KRC格式解析

#### LRC 格式歌词文件
- `6246262727282260.lrc` - 周杰伦《青花瓷》，用于测试LRC格式解析
- `6246262727282260.bin` - 对应的音高数据文件

#### 异常测试文件
- `237732-empty-content.xml` - 空内容XML文件
- `237732-empty-content-2.xml` - 空段落XML文件
- `237732-invalid-content.xml` - 无效内容XML文件
- `237732-invalid-content-2.xml` - 完全无效的XML文件

## 测试用例说明

### 已实现的测试用例

1. **useAppContext** - 测试应用上下文和KaraokeView初始化
2. **parseOneAndOnlyOneLineXmlFile** - 测试解析单行XML文件
3. **parseMetadataForThisLyrics** - 测试解析歌词元数据
4. **unexpectedContentCheckingForLyrics** - 测试异常内容处理
5. **parseLrcAndPitchFile** - 测试解析LRC和音高文件
6. **testParseKRCFile** - 测试解析KRC文件
7. **testParseLyricDataFormat** - 测试不同格式的歌词数据解析

### 占位测试用例（待实现）

以下测试用例已创建框架，但具体实现待后续完成：
- `lineSeparating` - 行分离测试
- `testForScoring` - 评分测试
- `testFirst5Lines` - 前5行测试
- `testPitchHit` - 音高命中测试
- `testDownload` - 下载测试
- `testMockScoring` - 模拟评分测试
- `testEnhancedLrcLyricFile` - 增强LRC歌词文件测试
- `testLyricFileParse` - 歌词文件解析测试
- `testLyricScoreWithPitch` - 歌词评分与音高测试

## 运行测试

### 前提条件
1. 确保 HarmonyOS SDK 已正确安装
2. 确保 lyrics_view 模块已正确编译
3. 确保测试资源文件已放置在正确位置

### 运行命令
```bash
# 在项目根目录下运行
cd Agora_LyricsView_HarmonyOS

# 运行所有测试
hvigorw test

# 或者只运行特定模块的测试
hvigorw :entry:test
```

### 在 DevEco Studio 中运行
1. 打开 DevEco Studio
2. 导入项目
3. 右键点击 `entry/src/ohosTest/ets/test/LyricsInstrumentedTest.ets`
4. 选择 "Run 'LyricsInstrumentedTest'"

## 测试工具类说明

### TestUtils 类
`TestUtils` 类提供了以下功能：

- `loadAsString()` - 从rawfile加载文件内容为字符串
- `loadAsBytes()` - 从rawfile加载文件内容为字节数组
- `fileExists()` - 检查rawfile文件是否存在
- `listRawFiles()` - 获取rawfile文件列表
- `copyRawFileToTemp()` - 创建临时文件用于测试
- `readFileToDoubleArray()` - 读取文件内容为double数组

## 与 Android 版本的对应关系

| Android 方法 | HarmonyOS 方法 | 说明 |
|-------------|---------------|------|
| `Utils.loadAsString()` | `TestUtils.loadAsString()` | 加载资源文件为字符串 |
| `Utils.copyAssetsToCreateNewFile()` | `TestUtils.copyRawFileToTemp()` | 创建临时测试文件 |
| `LyricPitchParser.parseFile()` | `LyricsParser.parseFile()` | 解析歌词文件 |
| `Context` | `common.UIAbilityContext` | 应用上下文 |
| `Log.d()` | `hilog.info()` | 日志输出 |

## 注意事项

1. **资源文件路径**: HarmonyOS 使用 rawfile 目录存放资源文件，而 Android 使用 assets 目录
2. **异步操作**: HarmonyOS 的文件读取操作多为异步，测试用例中使用了 async/await
3. **导入路径**: 确保正确导入 lyrics_view 模块的相关类
4. **错误处理**: 测试用例包含了完整的错误处理逻辑

## 扩展测试

如需添加更多测试用例：

1. 在 `rawfile` 目录下添加测试资源文件
2. 在 `LyricsInstrumentedTest.ets` 中添加对应的测试方法
3. 使用 `TestUtils` 类提供的工具方法读取资源文件
4. 调用 lyrics_view 模块的相关API进行测试

## 故障排除

### 常见问题

1. **模块导入错误**: 确保 lyrics_view 模块已正确编译并导出所需的类
2. **资源文件找不到**: 检查文件是否放置在正确的 rawfile 目录下
3. **测试运行失败**: 检查 HarmonyOS SDK 版本和项目配置是否匹配

### 调试建议

1. 使用 `hilog.info()` 输出调试信息
2. 检查测试日志中的错误信息
3. 确保测试环境和依赖项配置正确
