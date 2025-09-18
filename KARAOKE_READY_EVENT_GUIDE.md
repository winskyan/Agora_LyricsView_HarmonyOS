# KaraokeReady事件使用指南

## 概述

`onKaraokeReady`事件是一个智能的组件准备就绪通知机制，它会在所有集成的卡拉OK组件（`LyricsView`和/或`ScoringView`）完成初始化后自动触发。

## 特性

### 🎯 **智能组件检测**
- 自动检测哪些组件被集成到项目中
- 支持只集成`LyricsView`、只集成`ScoringView`或两者都集成
- 客户端无需手动跟踪组件状态

### 🚀 **统一就绪通知**
- 只发布一次`onKaraokeReady`事件
- 确保所有集成的组件都已完全准备就绪
- 客户端只需监听这一个事件

### 🔧 **自动重试机制**
- 如果组件检测失败，会自动重试
- 处理组件异步初始化的情况
- 确保事件的可靠性

## 使用方法

### 1. 实现IKaraokeEvent接口

```typescript
import { IKaraokeEvent, LyricsLineModel } from 'lyrics_view';

class MyKaraokeEventListener implements IKaraokeEvent {
  
  // 新增：所有组件准备就绪事件
  onKaraokeReady(): void {
    console.log('🎉 所有卡拉OK组件已准备就绪！');
    
    // 在这里执行需要等待所有组件ready的操作：
    // - 开始播放音乐
    // - 显示准备完成的UI状态
    // - 启用用户交互功能
    // - 加载歌词数据等
    
    this.startPlayback(); // 示例：开始播放
  }

  onDragTo(progress: number): void {
    console.log(`拖拽到: ${progress}ms`);
  }

  onLineFinished(line: LyricsLineModel, score: number, 
    cumulativeScore: number, index: number, lineCount: number): void {
    console.log(`第${index}行完成，得分: ${score}`);
  }
  
  private startPlayback() {
    // 开始播放逻辑
  }
}
```

### 2. 设置事件监听器

```typescript
// 创建KaraokeView实例
const karaokeView = new KaraokeView();

// 设置事件监听器
const eventListener = new MyKaraokeEventListener();
karaokeView.setKaraokeEvent(eventListener);

// 其他初始化代码...
```

## 工作原理

### 组件检测流程

1. **KaraokeView初始化时**：
   - 发送组件检测信号
   - 等待集成的组件响应

2. **组件响应检测**：
   - `LyricsView`和`ScoringView`在`onAppear`时响应检测
   - 向KaraokeView报告自己的存在

3. **状态跟踪**：
   - KaraokeView记录哪些组件被集成了
   - 跟踪每个组件的ready状态

4. **事件触发**：
   - 当所有集成的组件都ready时
   - 触发`onKaraokeReady`事件

### 时序图

```
KaraokeView          LyricsView          ScoringView
    |                    |                    |
    |-- 检测信号 -------->|                    |
    |-- 检测信号 -------------------------->|
    |                    |                    |
    |<-- 响应(LyricsView)|                    |
    |<-- 响应(ScoringView)-------------------|
    |                    |                    |
    |-- 等待ready ------>|                    |
    |-- 等待ready ------------------------->|
    |                    |                    |
    |<-- ready通知 ------|                    |
    |<-- ready通知 --------------------------|
    |                    |                    |
    |-- onKaraokeReady ->| (触发客户端事件)
```

## 支持的集成场景

### 场景1：只集成LyricsView
```typescript
// 只有LyricsView组件
LyricsView({ ... })

// onKaraokeReady会在LyricsView ready后触发
```

### 场景2：只集成ScoringView
```typescript
// 只有ScoringView组件
ScoringView({ ... })

// onKaraokeReady会在ScoringView ready后触发
```

### 场景3：同时集成两个组件
```typescript
// 同时有两个组件
LyricsView({ ... })
ScoringView({ ... })

// onKaraokeReady会在两个组件都ready后触发
```

## 最佳实践

### ✅ 推荐做法

1. **在onKaraokeReady中执行初始化**：
   ```typescript
   onKaraokeReady(): void {
     // 设置歌词数据
     this.karaokeView.setLyricData(lyricModel);
     
     // 开始播放
     this.startPlayback();
     
     // 更新UI状态
     this.showReadyState();
   }
   ```

2. **避免在组件构造时立即操作**：
   ```typescript
   // ❌ 不推荐
   const karaokeView = new KaraokeView();
   karaokeView.setLyricData(data); // 组件可能还没ready
   
   // ✅ 推荐
   const karaokeView = new KaraokeView();
   karaokeView.setKaraokeEvent({
     onKaraokeReady: () => {
       karaokeView.setLyricData(data); // 确保组件已ready
     }
   });
   ```

### ⚠️ 注意事项

1. **事件只触发一次**：`onKaraokeReady`在整个生命周期中只会触发一次
2. **异步特性**：事件触发是异步的，通常在组件`onAppear`后10-100ms内
3. **错误处理**：如果事件回调中出现错误，会被捕获并记录日志

## 调试和日志

启用详细日志来调试组件ready流程：

```typescript
// 在KaraokeView初始化时会输出以下日志：
// "KaraokeView: Starting component detection"
// "KaraokeView: Component detected: LyricsView"
// "KaraokeView: Component detected: ScoringView"
// "KaraokeView: LyricsView component ready"
// "KaraokeView: ScoringView component ready"
// "KaraokeView: All 2 components are ready, firing onKaraokeReady event"
```

## 迁移指南

如果你之前使用了自定义的组件ready检测，可以简化为：

```typescript
// 之前的代码
class MyApp {
  private lyricsReady = false;
  private scoringReady = false;
  
  onLyricsReady() {
    this.lyricsReady = true;
    this.checkAllReady();
  }
  
  onScoringReady() {
    this.scoringReady = true;
    this.checkAllReady();
  }
  
  checkAllReady() {
    if (this.lyricsReady && this.scoringReady) {
      this.startApp();
    }
  }
}

// 现在的代码
class MyApp implements IKaraokeEvent {
  onKaraokeReady(): void {
    this.startApp(); // 简化！
  }
}
```

这样就完成了从手动组件状态管理到自动化ready事件的迁移。
