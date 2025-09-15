# HarmonyOS 歌词解析测试指南

## 测试结构

```
entry/src/ohosTest/ets/
├── test/
│   ├── Ability.test.ets                    # 基础能力测试
│   ├── LyricsInstrumentedTest.test.ets    # 歌词解析测试
│   └── List.test.ets                      # 测试套件入口
└── utils/
    └── TestUtils.ets                      # 测试工具类
```

## 测试用例说明

### 1. LyricsInstrumentedTest.test.ets
**特点：**
- 需要 Context 和资源文件
- 完整的功能测试
- 对应 Android 版本的测试

**依赖：**
- 需要在 `entry/src/main/resources/rawfile/` 目录下放置测试文件
- 需要有效的 UIAbilityContext

## 运行测试

### 方法1：在 DevEco Studio 中运行
1. 打开 DevEco Studio
2. 右键点击测试文件或测试目录
3. 选择 "Run Tests"

### 方法2：使用命令行（需要配置环境）
```bash
# 设置环境变量
export DEVECO_SDK_HOME=/path/to/your/harmonyos/sdk

# 运行测试
./hvigorw assembleHap --mode module -p module=entry@ohosTest
```

## 测试文件要求

如果要运行 `LyricsInstrumentedTest.test.ets`，需要在以下目录放置测试文件：

```
entry/src/main/resources/rawfile/
├── 810507.xml                    # XML格式歌词文件
├── c18228e223144247810ee511916e2207.xml
├── 4875936889260991133.krc       # KRC格式歌词文件
├── 6246262727282260.lrc          # LRC格式歌词文件
├── 6246262727282260.bin          # 音高数据文件
├── 237732-empty-content.xml      # 空内容测试文件
├── 237732-empty-content-2.xml
├── 237732-invalid-content.xml    # 无效内容测试文件
└── 237732-invalid-content-2.xml
```

## 故障排除

### 问题1：找不到模块 'lyrics_view'
**解决方案：**
1. 确保 `lyrics_view` 模块已正确编译
2. 检查 `lyrics_view/Index.ets` 中的导出声明
3. 重新构建项目

### 问题2：Context 相关错误
**解决方案：**
1. 运行 `BasicLyricsTest.test.ets` 而不是 `LyricsInstrumentedTest.test.ets`
2. 或者在测试环境中正确配置 Context

### 问题3：找不到测试资源文件
**解决方案：**
1. 将测试文件放置在正确的 `rawfile` 目录中
2. 确保文件名与测试代码中的文件名完全匹配

### 问题4：编译错误
**解决方案：**
1. 清理构建缓存：删除 `entry/build/` 目录
2. 重新构建项目
3. 检查 HarmonyOS SDK 版本兼容性

## 测试最佳实践

1. **优先运行基础测试**：先运行 `BasicLyricsTest.test.ets` 确保核心功能正常
2. **逐步增加复杂性**：基础测试通过后再运行完整的集成测试
3. **检查日志输出**：使用 `hilog` 查看详细的测试执行信息
4. **模块化测试**：将大型测试拆分为小的、独立的测试用例

## 当前状态

- ✅ `Ability.test.ets` - 基础能力测试，可以运行
- ⚠️ `LyricsInstrumentedTest.test.ets` - 需要完整环境和资源文件

## 环境配置问题

当前遇到的主要问题：
```
> hvigor ERROR: Unable to find 'DEVECO_SDK_HOME' in the system environment path.
```

**解决方案**：
1. 在 DevEco Studio 中直接运行测试（推荐）
2. 配置 `DEVECO_SDK_HOME` 环境变量
3. 参考 `ENVIRONMENT_SETUP.md` 文档

## 下一步计划

1. 解决 `DEVECO_SDK_HOME` 环境配置问题
2. 准备完整的测试资源文件
3. 配置正确的测试环境以支持 `LyricsInstrumentedTest.test.ets`
4. 添加更多边界情况和错误处理测试
