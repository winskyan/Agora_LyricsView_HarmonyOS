# 🎯 歌词自动滚动修复指南

## 🚫 当前问题

歌词播放时跑出了视图底部，无法看到当前行，说明自动滚动功能没有正常工作。

## 🔧 修复方案

### 1. 确保 Scroll 组件正确绑定控制器

在 `build()` 方法中，确保 Scroll 组件使用了控制器：

```typescript
Scroll(this.scroller) {
  // ... 歌词内容
}
```

### 2. 修复 scrollToCurrentLine() 方法

将 `scrollToCurrentLine()` 方法替换为以下实现：

```typescript
private scrollToCurrentLine(): void {
  if (this.mIndexOfCurrentLine < 0) {
    return;
  }

  LogUtils.d(`LyricsView: Scrolling to line ${this.mIndexOfCurrentLine}`);

  // 动态计算每行的高度
  const currentLineHeight = this.currentLineTextSize + this.lineSpacing + 16;
  const normalLineHeight = this.textSize + this.lineSpacing + 12;
  
  // 使用 paddingTop 作为顶部空白高度
  const topBlankHeight = this.paddingTop;

  // 计算当前行的位置
  let currentLinePosition = topBlankHeight;
  for (let i = 0; i < this.mIndexOfCurrentLine; i++) {
    currentLinePosition += normalLineHeight;
  }
  currentLinePosition += currentLineHeight / 2;

  // 使用传入的视图高度计算中心位置
  const viewCenterOffset = this.viewHeight / 2;
  const scrollOffset = Math.max(0, currentLinePosition - viewCenterOffset);

  LogUtils.d(`LyricsView: Scroll calculation - line: ${this.mIndexOfCurrentLine}, scrollOffset: ${scrollOffset}`);

  // 使用 Scroller 进行平滑滚动
  this.scroller.scrollTo({
    xOffset: 0,
    yOffset: scrollOffset,
    animation: {
      duration: 600,
      curve: Curve.EaseInOut
    }
  });
}
```

### 3. 添加 viewHeight 属性

在属性声明部分添加：

```typescript
/** View height for calculating center position (optional, defaults to 400) */
@Prop viewHeight: number = 400;
```

### 4. 添加 scroller 控制器

在内部状态声明部分添加：

```typescript
// Scroll controller for auto-scrolling
private scroller: Scroller = new Scroller();
```

### 5. 确保滚动方向正确

在 Scroll 组件的属性中：

```typescript
.scrollable(ScrollDirection.Vertical)
.scrollBar(BarState.Off)
```

## 🎯 使用方法

在 `Index.ets` 中使用 LyricsView 时，可以传入实际的视图高度：

```typescript
LyricsView({
  // ... 其他属性
  viewHeight: 400  // 根据实际容器高度调整
})
.width('100%')
.height(400)  // 这个高度应该与 viewHeight 一致
```

## 🔍 调试方法

1. **查看日志**：确保能看到以下日志：
   ```
   LyricsView: Line changed from X to Y
   LyricsView: Scrolling to line Y
   LyricsView: Scroll calculation - line: Y, scrollOffset: Z
   ```

2. **检查滚动是否触发**：如果看不到滚动日志，说明 `scrollToCurrentLine()` 没有被调用

3. **检查滚动计算**：如果滚动计算不正确，调整 `lineHeight` 的计算方式

## 🚨 常见问题

### 问题1：滚动不生效
**原因**：Scroller 没有正确绑定到 Scroll 组件
**解决**：确保 `Scroll(this.scroller)` 语法正确

### 问题2：滚动位置不准确
**原因**：行高计算不准确
**解决**：根据实际的字体大小和间距调整计算公式

### 问题3：滚动过度或不足
**原因**：viewHeight 设置不正确
**解决**：确保 viewHeight 与实际容器高度一致

## 📋 验证步骤

1. 编译项目，确保没有语法错误
2. 运行应用，开始播放歌词
3. 观察当前行是否始终保持在视图中心
4. 检查日志输出，确认滚动计算正确

## 💡 优化建议

1. **动态测量**：未来可以考虑动态测量组件实际高度，而不是使用固定值
2. **平滑滚动**：可以调整动画时长和曲线，获得更好的视觉效果
3. **边界处理**：添加边界检查，防止滚动超出内容范围
