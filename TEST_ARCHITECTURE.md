# 新架构测试说明

## 架构改进总结

我们已经成功重构了 HarmonyOS 卡拉OK 组件的架构，实现了以下改进：

### 1. 移除组件引用依赖
- **之前**: `Index.ets` 需要持有 `LyricsView` 和 `ScoringView` 的组件实例引用
- **现在**: `Index.ets` 只负责定义组件和传递配置参数，不持有任何组件引用

### 2. 事件驱动通信
- **新增**: `EventBus.ets` - 全局事件总线，管理组件间通信
- **事件类型**: 
  - `LyricsEvents.SET_LYRIC_DATA` - 设置歌词数据
  - `LyricsEvents.SET_PROGRESS` - 更新播放进度
  - `LyricsEvents.RESET` - 重置组件状态
  - `LyricsEvents.REQUEST_REFRESH` - 请求刷新UI

### 3. 组件内部封装
- **LyricsView**: 完全封装内部逻辑，通过事件监听器接收指令
- **KaraokeView**: 通过事件总线与UI组件通信，不直接持有组件引用

### 4. 简化的初始化流程
```typescript
// Index.ets 中的简化流程
private onComponentReady() {
  this.initKaraokeView(); // 只需要初始化KaraokeView
}

private initKaraokeView() {
  if (!this.karaokeView) {
    this.karaokeView = new KaraokeView(); // 使用默认构造函数
    // 设置数据会自动通过事件总线传递给组件
  }
}
```

### 5. 自动化的数据流
```typescript
// KaraokeView 中的数据流
setLyricData(model: LyricModel) {
  // 内部处理
  this.mLyricMachine?.prepare(model);
  
  // 自动通知所有相关组件
  this.eventBus.emit(LyricsEvents.SET_LYRIC_DATA, model);
}

setProgress(progress: number) {
  // 内部处理
  this.mLyricMachine?.setProgress(progress);
  
  // 自动通知所有相关组件
  this.eventBus.emit(LyricsEvents.SET_PROGRESS, progress);
}
```

## 优势

1. **解耦**: 组件之间不再有直接依赖
2. **可维护性**: 每个组件只关心自己的职责
3. **可扩展性**: 新增组件只需要监听相应事件
4. **类型安全**: 移除了 `any` 类型的使用
5. **符合HarmonyOS设计模式**: 组件内部封装，外部只传递配置

## 使用方式

现在用户只需要在 `Index.ets` 中这样使用：

```typescript
@Builder
LyricsViewBuilder() {
  if (this.enableLyrics && this.lyricModel) {
    LyricsView({
      textSize: 16,
      currentLineTextSize: 20,
      currentLineTextColor: '#FFFFFF',
      // ... 其他配置参数
    })
    .width('100%')
    .height('100%')
  }
}
```

所有的显示逻辑、状态管理、事件处理都由 `LyricsView` 组件内部处理，外部无需关心实现细节。
