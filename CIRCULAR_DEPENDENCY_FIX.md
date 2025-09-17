# 🔄 循环依赖问题修复

## 🚫 问题现象

日志显示：
```
LyricsView: mLyricMachine exists, ready before prepare: false
LyricsView: resetUi called
```

之后没有 `After prepare` 的日志，说明代码执行被中断。

## 🔍 根本原因分析

### 问题的执行流程：

1. **事件触发**：`KaraokeView` 发送 `SET_LYRIC_DATA` 事件
2. **LyricsView 接收**：事件监听器被调用
3. **调用 prepare()**：`this.mLyricMachine.prepare(lyricModel)`
4. **LyricMachine.prepare() 内部**：
   ```typescript
   prepare(model: LyricModel | null): void {
     this.reset();  // ← 这里调用了 reset()
     // ... 后续代码
   }
   ```
5. **LyricMachine.reset() 内部**：
   ```typescript
   reset(): void {
     this.resetProperties();
     this.resetStats();
     this.resetUi()  // ← 这里调用了 resetUi()
   }
   ```
6. **resetUi() 调用监听器**：
   ```typescript
   private resetUi(): void {
     if (this.mListener) {
       this.mListener.resetUi();  // ← 调用 LyricsView.reset()
     }
   }
   ```
7. **LyricsView.reset() 被调用**：
   ```typescript
   reset(): void {
     this.resetInternal();
   }
   ```
8. **关键问题**：`resetInternal()` 中有：
   ```typescript
   private resetInternal(): void {
     this.mLyricMachine = null;  // ← 这里将引用设为 null！
     // ...
   }
   ```

### 🚨 循环依赖问题

- `LyricMachine.prepare()` 正在执行
- 但在执行过程中，它调用了 `LyricsView.reset()`
- `LyricsView.reset()` 将 `this.mLyricMachine` 设为 `null`
- 当 `prepare()` 方法继续执行时，`LyricsView` 已经失去了对 `LyricMachine` 的引用
- 后续的日志代码 `this.mLyricMachine.isReady()` 无法执行

## 🔧 解决方案

### 1. 修改 `resetInternal()` 方法

**之前**：
```typescript
private resetInternal(): void {
  this.mLyricMachine = null;  // 会导致循环依赖问题
  this.mIndexOfCurrentLine = -1;
  // ...
}
```

**修复后**：
```typescript
private resetInternal(): void {
  // 注意：不要重置 mLyricMachine，因为它可能正在调用这个方法
  // this.mLyricMachine = null; // 移除这行，避免循环依赖
  this.mIndexOfCurrentLine = -1;
  // ...
}
```

### 2. 添加完全重置方法

为需要完全清理的场景添加新方法：

```typescript
/**
 * 完全重置，包括清理 LyricMachine 引用
 * 仅在组件销毁或需要完全清理时调用
 */
resetCompletely(): void {
  this.mLyricMachine = null;
  this.resetInternal();
}
```

### 3. 在组件销毁时使用完全重置

```typescript
.onDisAppear(() => {
  LogUtils.d('LyricsView: Component disappearing, cleaning up');
  this.removeEventListeners();
  this.resetCompletely(); // 完全清理
})
```

## 📋 修复效果

修复后，预期的日志输出应该是：

```
LyricsView: Received SET_LYRIC_DATA event, lyricModel lines: 44
LyricsView: this context check - mLyricMachine exists: true
LyricsView: mLyricMachine exists, ready before prepare: false
LyricsView: resetUi called
LyricsView: After prepare, mLyricMachine ready: true  ← 这行现在应该出现
LyricsView: Lyric data set successfully, getLyricsModel: true
```

## 🎯 关键要点

1. **避免在回调中破坏调用者的状态**：`resetUi()` 回调不应该清理调用它的对象的引用
2. **区分不同级别的重置**：
   - `reset()`：重置UI状态，但保持对象引用
   - `resetCompletely()`：完全清理，包括对象引用
3. **生命周期管理**：在适当的时机进行完全清理（如组件销毁时）

## 🔄 架构改进

这个修复也揭示了一个架构问题：`LyricMachine` 和 `LyricsView` 之间的耦合过于紧密。未来可以考虑：

1. 使用更松散的事件系统
2. 避免在初始化过程中调用可能影响调用者状态的回调
3. 明确区分"重置UI状态"和"重置对象引用"的概念
