# LyricMachine undefined 问题调试

## 🚫 问题现象

日志显示：`LyricsView: Lyric data set successfully, mLyricMachine ready: undefined`

这说明 `this.mLyricMachine?.isReady()` 返回了 `undefined`，而不是期望的 `true` 或 `false`。

## 🔍 可能的原因分析

### 1. 时序问题
- `initLyricMachine()` 创建了 `LyricMachine` 实例
- 但在调用 `prepare(lyricModel)` 之前，`isReady()` 应该返回 `false`
- 调用 `prepare(lyricModel)` 之后，`isReady()` 应该返回 `true`
- 如果返回 `undefined`，说明 `mLyricMachine` 可能是 `null`

### 2. 上下文问题 (this 绑定)
在事件监听器回调中，`this` 的上下文可能不正确，导致：
- `this.mLyricMachine` 访问的不是预期的实例
- 不同的组件实例之间的混淆

### 3. 异步执行问题
- 事件的发送和接收可能不在同一个执行上下文中
- `EventBus` 虽然是同步的，但组件的生命周期可能有异步特性

## 🔧 添加的调试信息

### 1. 增强的事件监听器日志
```typescript
const setLyricDataHandler = (lyricModel: LyricModel) => {
  LogUtils.d(`LyricsView: Received SET_LYRIC_DATA event, lyricModel lines: ${lyricModel?.lines?.length || 0}`);
  LogUtils.d(`LyricsView: this context check - mLyricMachine exists: ${!!this.mLyricMachine}`);
  if (this.mLyricMachine) {
    LogUtils.d(`LyricsView: mLyricMachine exists, ready before prepare: ${this.mLyricMachine.isReady()}`);
    this.mLyricMachine.prepare(lyricModel);
    LogUtils.d(`LyricsView: After prepare, mLyricMachine ready: ${this.mLyricMachine.isReady()}`);
    // ...
    LogUtils.d(`LyricsView: Lyric data set successfully, getLyricsModel: ${!!this.mLyricMachine.getLyricsModel()}`);
  } else {
    LogUtils.e('LyricsView: mLyricMachine is null when receiving SET_LYRIC_DATA event');
  }
};
```

### 2. LyricMachine 初始化日志
```typescript
private initLyricMachine(): void {
  if (!this.mLyricMachine) {
    LogUtils.d('LyricsView: Creating new LyricMachine');
    // ...
    this.mLyricMachine = new LyricMachine(listener);
    LogUtils.d(`LyricsView: LyricMachine created successfully, initial ready state: ${this.mLyricMachine.isReady()}`);
  } else {
    LogUtils.d('LyricsView: LyricMachine already exists');
  }
}
```

## 📋 预期的日志输出

正常情况下应该看到：

1. **组件初始化**：
   ```
   LyricsView: Setting up event listeners
   LyricsView: Creating new LyricMachine
   LyricsView: LyricMachine created successfully, initial ready state: false
   ```

2. **接收事件**：
   ```
   LyricsView: Received SET_LYRIC_DATA event, lyricModel lines: [数量]
   LyricsView: this context check - mLyricMachine exists: true
   LyricsView: mLyricMachine exists, ready before prepare: false
   LyricsView: After prepare, mLyricMachine ready: true
   LyricsView: Lyric data set successfully, getLyricsModel: true
   ```

## 🎯 异常情况分析

如果看到以下日志，说明有问题：

### 情况1：mLyricMachine 为 null
```
LyricsView: this context check - mLyricMachine exists: false
LyricsView: mLyricMachine is null when receiving SET_LYRIC_DATA event
```
**原因**：`initLyricMachine()` 没有正确执行，或者 `this` 上下文错误

### 情况2：isReady() 返回 undefined
```
LyricsView: mLyricMachine exists, ready before prepare: undefined
LyricsView: After prepare, mLyricMachine ready: undefined
```
**原因**：`LyricMachine.isReady()` 方法有问题，或者实例创建失败

### 情况3：prepare() 没有生效
```
LyricsView: mLyricMachine exists, ready before prepare: false
LyricsView: After prepare, mLyricMachine ready: false
```
**原因**：`prepare()` 方法没有正确设置内部状态

## 🔧 修复策略

1. **确保 this 上下文正确**：使用箭头函数或显式绑定
2. **验证 LyricMachine 构造**：确保构造函数正确执行
3. **检查 prepare() 方法**：确保它正确设置内部状态
4. **添加更多调试**：在关键点添加日志来跟踪执行流程

## 📝 下一步调试

运行应用后，查看完整的日志输出，根据实际的日志模式来确定具体的问题所在。
