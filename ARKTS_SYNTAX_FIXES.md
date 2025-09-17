# ArkTS 语法错误修复

## 🚫 遇到的编译错误

```
1 ERROR: 10905209 ArkTS Compiler Error
Error Message: Only UI component syntax can be written here. At File: .../LyricsView.ets:422:5

2 ERROR: 10905204 ArkTS Compiler Error
Error Message: 'LogUtils.d('LyricsView: Rendering NoLyricsBuilder');' does not meet UI component syntax. At File: .../LyricsView.ets:466:9

3 ERROR: 10905209 ArkTS Compiler Error
Error Message: Only UI component syntax can be written here. At File: .../LyricsView.ets:469:9

4 ERROR: 10905204 ArkTS Compiler Error
Error Message: 'LogUtils.d(`LyricsView: Rendering lyrics, lines count: ${lyricsModel?.lines?.length ||
          0}, current line: ${this.mIndexOfCurrentLine}`);' does not meet UI component syntax. At File: .../LyricsView.ets:470:9
```

## 🔧 问题原因

在 ArkUI 的 `@Builder` 函数和 `build()` 方法中，只能使用 UI 组件语法，不能直接写 JavaScript 代码，包括：

1. **变量声明**：`const`, `let`, `var`
2. **函数调用**：`LogUtils.d()`, `console.log()` 等
3. **复杂的 JavaScript 表达式**

## ✅ 修复方案

### 1. 移除 @Builder 中的变量声明

**修复前**：
```typescript
@Builder
PreludeIndicatorBuilder() {
  const lyricsModel = this.mLyricMachine?.getLyricsModel();
  if (this.enablePreludeEndPositionIndicator && lyricsModel && this.getPreludeCountDown() > 0) {
    // ...
  }
}
```

**修复后**：
```typescript
@Builder
PreludeIndicatorBuilder() {
  if (this.enablePreludeEndPositionIndicator && this.mLyricMachine?.getLyricsModel() && this.getPreludeCountDown() > 0) {
    // ...
  }
}
```

### 2. 移除 build() 方法中的日志调用和变量声明

**修复前**：
```typescript
build() {
  Column() {
    if (this.uninitializedOrNoLyrics()) {
      LogUtils.d('LyricsView: Rendering NoLyricsBuilder');
      this.NoLyricsBuilder()
    } else {
      const lyricsModel = this.mLyricMachine?.getLyricsModel();
      LogUtils.d(`LyricsView: Rendering lyrics, lines count: ${lyricsModel?.lines?.length || 0}`);
      // ...
    }
  }
}
```

**修复后**：
```typescript
build() {
  Column() {
    if (this.uninitializedOrNoLyrics()) {
      this.NoLyricsBuilder()
    } else {
      Scroll() {
        // ...
      }
    }
  }
}
```

### 3. 修复 ForEach 中的数据引用

**修复前**：
```typescript
ForEach(lyricsModel.lines, (line: LyricsLineModel, index: number) => {
  this.EnhancedLyricsLineBuilder(line, index)
})
```

**修复后**：
```typescript
ForEach(this.mLyricMachine?.getLyricsModel()?.lines, (line: LyricsLineModel, index: number) => {
  this.EnhancedLyricsLineBuilder(line, index)
})
```

### 4. 修复事件回调中的变量声明

**修复前**：
```typescript
.onScrollStop(() => {
  if (this.enableDragging && this.mOnSeekActionListener) {
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (lyricsModel && this.targetIndex >= 0 && this.targetIndex < lyricsModel.lines.length) {
      const targetLine = lyricsModel.lines[this.targetIndex];
      // ...
    }
  }
})
```

**修复后**：
```typescript
.onScrollStop(() => {
  if (this.enableDragging && this.mOnSeekActionListener) {
    if (this.mLyricMachine?.getLyricsModel()?.lines && this.targetIndex >= 0 &&
        this.targetIndex < this.mLyricMachine.getLyricsModel()!.lines.length) {
      const targetLine = this.mLyricMachine.getLyricsModel()!.lines[this.targetIndex];
      // ...
    }
  }
})
```

## 📋 ArkTS 语法规则总结

### ✅ 在 @Builder 和 build() 中可以使用：
- UI 组件（`Text`, `Column`, `Row`, `Scroll` 等）
- 条件渲染（`if`, `else`）
- 循环渲染（`ForEach`）
- 组件属性设置（`.width()`, `.height()` 等）
- 事件回调（`.onClick()`, `.onAppear()` 等）
- 直接的属性访问（`this.property`）
- 方法调用（`this.method()`）

### ❌ 在 @Builder 和 build() 中不能使用：
- 变量声明（`const`, `let`, `var`）
- 复杂的 JavaScript 表达式
- 日志调用（`console.log()`, `LogUtils.d()` 等）
- 复杂的数据处理逻辑

### 💡 最佳实践：
1. **数据处理逻辑**应该在组件的方法中完成，而不是在 `build()` 中
2. **调试日志**应该在生命周期方法（如 `onAppear`）或事件处理方法中添加
3. **复杂的条件判断**可以提取为私有方法
4. **数据访问**尽量使用链式调用（`?.`）来保证安全性

## 🎯 修复结果

修复后的代码符合 ArkTS 语法规范，应该能够正常编译。主要改进：

1. 移除了所有在 UI 构建过程中的 JavaScript 代码
2. 使用链式调用直接访问数据
3. 保持了原有的功能逻辑
4. 提高了代码的可读性和维护性
