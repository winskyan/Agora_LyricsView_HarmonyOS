# LyricsView 重构总结

## 🎯 重构目标

删除 `mLyricsModel` 属性，改为使用 `mLyricMachine.getLyricsModel()` 方法获取歌词数据。

## ✅ 已完成的修改

### 1. 删除 mLyricsModel 属性
```typescript
// 删除前
@State private mLyricsModel: LyricModel | null = null;
@State private mLyricMachine: LyricMachine | null = null;

// 删除后
@State private mLyricMachine: LyricMachine | null = null;
```

### 2. 修改 uninitializedOrNoLyrics() 方法
```typescript
// 修改前
private uninitializedOrNoLyrics(): boolean {
  return !this.mLyricMachine || !this.mLyricsModel ||
    !this.mLyricsModel.lines || this.mLyricsModel.lines.length === 0;
}

// 修改后
private uninitializedOrNoLyrics(): boolean {
  const lyricsModel = this.mLyricMachine?.getLyricsModel();
  return !this.mLyricMachine || !lyricsModel ||
    !lyricsModel.lines || lyricsModel.lines.length === 0;
}
```

### 3. 修改 updateByProgress() 方法
```typescript
// 修改前
private updateByProgress(timestamp: number): void {
  this.mCurrentTime = timestamp;
  LogUtils.d(`... mLyricsModel=${!!this.mLyricsModel}`);
  
  if (line < 0 || !this.mLyricsModel || line >= this.mLyricsModel.lines.length) {
    // ...
  }
}

// 修改后
private updateByProgress(timestamp: number): void {
  this.mCurrentTime = timestamp;
  const lyricsModel = this.mLyricMachine?.getLyricsModel();
  LogUtils.d(`... lyricsModel=${!!lyricsModel}`);
  
  if (line < 0 || !lyricsModel || line >= lyricsModel.lines.length) {
    // ...
  }
}
```

### 4. 修改 quickSearchLineByTimestamp() 方法
```typescript
// 修改前
private quickSearchLineByTimestamp(time: number): number {
  if (this.uninitializedOrNoLyrics()) {
    return 0;
  }
  let right = this.mLyricsModel!.lines.length - 1;
  // ...
}

// 修改后
private quickSearchLineByTimestamp(time: number): number {
  const lyricsModel = this.mLyricMachine?.getLyricsModel();
  if (!lyricsModel) return 0;
  let right = lyricsModel.lines.length - 1;
  // ...
}
```

### 5. 修改其他相关方法
- `forceCheckLineWrap()`: 使用 `lyricsModel` 局部变量
- `getLineIndex()`: 使用 `lyricsModel` 局部变量
- `getPreludeCountDown()`: 使用 `lyricsModel` 局部变量
- `PreludeIndicatorBuilder()`: 使用 `lyricsModel` 局部变量
- `build()` 方法中的渲染逻辑: 使用 `lyricsModel` 局部变量
- 事件监听器中的滚动处理: 使用 `lyricsModel` 局部变量

### 6. 修改事件监听器
```typescript
// 修改前
this.eventBus.on(LyricsEvents.SET_LYRIC_DATA, (lyricModel: LyricModel) => {
  if (this.mLyricMachine) {
    this.mLyricMachine.prepare(lyricModel);
    this.mLyricsModel = lyricModel;  // 删除这行
    this.forceCheckLineWrap();
  }
});

// 修改后
this.eventBus.on(LyricsEvents.SET_LYRIC_DATA, (lyricModel: LyricModel) => {
  if (this.mLyricMachine) {
    this.mLyricMachine.prepare(lyricModel);
    // mLyricsModel removed - data now managed by mLyricMachine
    this.forceCheckLineWrap();
  }
});
```

### 7. 修改 resetInternal() 方法
```typescript
// 修改前
private resetInternal(): void {
  this.mLyricMachine = null;
  this.mLyricsModel = null;  // 删除这行
  // ...
}

// 修改后
private resetInternal(): void {
  this.mLyricMachine = null;
  // mLyricsModel removed - now using mLyricMachine.getLyricsModel()
  // ...
}
```

## 🎯 重构的好处

1. **数据一致性**: 歌词数据只存储在一个地方（`LyricMachine` 内部）
2. **减少状态管理**: 不需要手动同步 `mLyricsModel` 和 `mLyricMachine` 的状态
3. **简化代码**: 减少了一个 `@State` 属性，降低了组件的复杂度
4. **更好的封装**: 歌词数据的管理完全由 `LyricMachine` 负责

## 📋 使用模式

现在所有需要访问歌词数据的地方都使用以下模式：

```typescript
const lyricsModel = this.mLyricMachine?.getLyricsModel();
if (lyricsModel) {
  // 使用 lyricsModel.lines, lyricsModel.type 等
}
```

这种模式确保了：
- 空安全检查
- 数据的实时性（总是从 `LyricMachine` 获取最新数据）
- 代码的一致性
