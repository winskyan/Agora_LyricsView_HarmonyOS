# LyricsView HarmonyOS

HarmonyOS版本的歌词显示组件，支持KRC格式的逐字高亮显示，对应Android项目中的LyricsView功能。

## 功能特性

- ✅ **KRC格式支持**: 完整支持KRC格式歌词解析，包括逐字高亮显示
- ✅ **实时同步**: 支持实时歌词同步和高亮显示
- ✅ **拖拽定位**: 支持手势拖拽快速定位到指定歌词位置
- ✅ **自动滚动**: 歌词自动滚动到当前播放位置
- ✅ **样式自定义**: 支持字体大小、颜色、间距等样式自定义
- ✅ **评分系统**: 集成卡拉OK评分功能
- 🔄 **LRC格式**: 计划支持LRC格式歌词（待实现）
- 🔄 **XML格式**: 计划支持XML格式歌词（待实现）

## 项目结构

```
Agora_LyricsView_HarmonyOS/
├── lyrics_view/                    # 歌词组件模块
│   ├── src/main/ets/
│   │   ├── KaraokeView.ets         # 卡拉OK主控制器（对外统一接口）
│   │   ├── components/
│   │   │   ├── LyricsView.ets      # 歌词显示组件
│   │   │   └── ScoringView.ets     # 评分显示组件（待实现）
│   │   ├── internal/
│   │   │   ├── LyricMachine.ets    # 歌词机器（待完善）
│   │   │   └── ScoringMachine.ets  # 评分机器（待完善）
│   │   ├── model/
│   │   │   └── LyricModel.ets      # 歌词数据模型
│   │   └── parser/
│   │       ├── KrcParser.ets       # KRC格式解析器
│   │       └── LyricsParser.ets    # 通用歌词解析器
│   └── src/test/
│       ├── KrcParserTest.test.ets  # KRC解析器单元测试
│       └── LyricsViewTest.test.ets # 歌词组件单元测试
└── entry/                          # 测试应用
    └── src/main/ets/pages/
        ├── LyricsTestPage.ets      # 歌词显示测试页面
        └── SimpleExample.ets       # 简单使用示例
```

## 快速开始

### 1. 基本使用

```typescript
import { LyricsView } from '../lyrics_view/src/main/ets/components/LyricsView';
import { KaraokeView } from '../lyrics_view/src/main/ets/KaraokeView';

@Entry
@Component
struct MainPage {
  @State lyricModel: LyricModel | null = null;
  @State currentTime: number = 0;

  aboutToAppear() {
    // 解析KRC歌词
    const krcContent = `[ti:歌曲名]
[ar:歌手名]
[8124,1957]<0,199,0>可<200,198,0>我<398,288,0>生<687,277,0>来<964,298,0>就<1263,293,0>倔<1556,401,0>强`;
    
    this.lyricModel = KaraokeView.parseLyricContent(krcContent);
  }

  build() {
    Column() {
      LyricsView({
        lyricModel: this.lyricModel,
        currentTime: this.currentTime,
        enableDragging: true,
        currentLineTextSize: 22,
        normalLineTextSize: 18,
        highlightColor: '#FF6B35'
      })
    }
  }
}
```

### 2. 使用KaraokeView控制器

```typescript
import { KaraokeView } from '../lyrics_view/src/main/ets/KaraokeView';
import { IKaraokeEvent } from '../lyrics_view/src/main/ets/IKaraokeEvent';

export class LyricsController implements IKaraokeEvent {
  private karaokeView: KaraokeView;

  constructor() {
    this.karaokeView = new KaraokeView();
    this.karaokeView.setKaraokeEvent(this);
  }

  // 设置歌词数据
  setLyrics(lyricModel: LyricModel) {
    this.karaokeView.setLyricData(lyricModel, true);
  }

  // 更新播放进度
  updateProgress(timeMs: number) {
    this.karaokeView.setProgress(timeMs);
  }

  // 设置音调数据（用于评分）
  setPitchData(pitch: number, score: number, progress: number) {
    this.karaokeView.setPitch(pitch, score, progress);
  }

  // 歌词行完成回调
  onLineFinished(karaokeView: any, line: LyricsLineModel, 
                score: number, cumulativeScore: number, 
                index: number, lineCount: number): void {
    console.info(`Line ${index + 1}/${lineCount} finished, score: ${score}`);
  }

  // 拖拽定位回调
  onDragTo(karaokeView: any, progress: number): void {
    console.info(`Seek to: ${progress}ms`);
    // 更新播放器进度
  }
}
```

### 3. 解析不同格式的歌词

```typescript
// 从字符串解析
const lyricModel = KaraokeView.parseLyricContent(krcContent);

// 从字节数组解析
const encoder = new TextEncoder();
const lyricBytes = encoder.encode(krcContent);
const lyricModel2 = KaraokeView.parseLyricData(lyricBytes);

// 使用KrcParser直接解析
import { KrcParser } from '../lyrics_view/src/main/ets/parser/KrcParser';
const lyricModel3 = KrcParser.parseKRC(krcContent, 0); // 0为时间偏移
```

## KRC格式说明

KRC格式是一种支持逐字高亮的歌词格式，格式如下：

```
[ti:歌曲标题]
[ar:歌手名称]
[al:专辑名称]
[offset:时间偏移]

[开始时间,持续时间]<字符偏移,字符持续时间,音调>字符<字符偏移,字符持续时间,音调>字符...
```

### 示例

```
[ti:热烈的少年]
[ar:Big Cole]
[8124,1957]<0,199,0>可<200,198,0>我<398,288,0>生<687,277,0>来<964,298,0>就<1263,293,0>倔<1556,401,0>强
```

- `[8124,1957]`: 该行从8124ms开始，持续1957ms
- `<0,199,0>可`: "可"字从行开始偏移0ms，持续199ms，音调为0
- `<200,198,0>我`: "我"字从行开始偏移200ms，持续198ms，音调为0

## API参考

### LyricsView组件属性

| 属性名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| lyricModel | LyricModel \| null | null | 歌词数据模型 |
| currentTime | number | 0 | 当前播放时间（毫秒） |
| enableDragging | boolean | false | 是否启用拖拽功能 |
| currentLineTextSize | number | 20 | 当前行字体大小 |
| normalLineTextSize | number | 16 | 普通行字体大小 |
| currentLineColor | string | '#333333' | 当前行文字颜色 |
| normalLineColor | string | '#999999' | 普通行文字颜色 |
| highlightColor | string | '#FF6B35' | 高亮文字颜色 |
| lineSpacing | number | 12 | 行间距 |
| animationDuration | number | 300 | 动画持续时间 |
| paddingTop | number | 50 | 顶部内边距 |
| noLyricsText | string | '暂无歌词' | 无歌词时显示文本 |

### KaraokeView主要方法

| 方法名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| parseLyricContent | content: string, offset?: number | LyricModel | 解析歌词内容 |
| parseLyricData | data: Uint8Array, pitchData?: Uint8Array | LyricModel | 解析歌词字节数据 |
| setLyricData | model: LyricModel, useInternalScoring: boolean | void | 设置歌词数据 |
| setProgress | progress: number | void | 设置播放进度 |
| setPitch | pitch: number, score: number, progress: number | void | 设置音调数据 |
| setScoringLevel | level: number | void | 设置评分难度 |
| reset | - | void | 重置状态 |

## 运行测试

### 单元测试

```bash
# 运行KRC解析器测试
hvigor test --target KrcParserTest

# 运行歌词组件测试  
hvigor test --target LyricsViewTest
```

### 集成测试

1. 打开DevEco Studio
2. 运行entry模块
3. 导航到"歌词显示测试"页面
4. 测试各种功能：
   - 播放/暂停控制
   - 进度拖拽
   - 播放速度调整
   - 歌词高亮效果

## 开发计划

- [ ] 支持LRC格式歌词解析
- [ ] 支持XML格式歌词解析
- [ ] 添加更多动画效果
- [ ] 支持歌词翻译显示
- [ ] 优化性能和内存使用
- [ ] 添加更多自定义样式选项

## 许可证

本项目基于Apache 2.0许可证开源。

## 贡献

欢迎提交Issue和Pull Request来改进这个项目。

## 联系方式

如有问题或建议，请通过以下方式联系：
- 提交GitHub Issue
- 发送邮件至开发团队
